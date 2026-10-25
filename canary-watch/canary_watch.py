"""Watch the Anthropic canary workspace for any token consumption at all.

A key planted as bait is never called by anything legitimate, so a single
non-zero token count is the signal -- there is no threshold to tune and no
baseline to learn.

This runs on Modal rather than on the laptop on purpose. One of the things
it is meant to detect is the laptop being stolen, and a watcher that dies
with the laptop detects nothing.

    modal secret create anthropic-canary \
        ANTHROPIC_ADMIN_KEY=sk-ant-admin01-... \
        ALERT_URL=https://ntfy.sh/<random-topic>
    modal deploy canary_watch.py

    modal run canary_watch.py::probe      # one-shot, prints what it sees
"""

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

import modal

API = "https://api.anthropic.com"

# Name of the workspace holding the planted keys. Filtering by workspace
# rather than by key id means a key added to it later is covered with no
# change here.
WORKSPACE = os.environ.get("CANARY_WORKSPACE", "canary")

# How far back each poll looks. Usage is documented as appearing within
# about five minutes, so this leaves a wide margin for a late bucket and
# for one or two missed runs.
LOOKBACK_MIN = 30

app = modal.App("canary-watch")
image = modal.Image.debian_slim(python_version="3.12")
secret = modal.Secret.from_name("anthropic-canary")

# Buckets already reported, so a sustained attack alerts once per minute of
# real usage instead of once per poll.
state = modal.Dict.from_name("canary-watch-state", create_if_missing=True)


def admin_get(path, params):
    url = f"{API}{path}?" + urllib.parse.urlencode(params, doseq=True)
    req = urllib.request.Request(
        url,
        headers={
            "x-api-key": os.environ["ANTHROPIC_ADMIN_KEY"],
            "anthropic-version": "2023-06-01",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:400]
        raise RuntimeError(f"GET {path} -> HTTP {exc.code}: {detail}") from None


def workspace_id(name):
    after = None
    while True:
        params = {"limit": 1000}
        if after:
            params["after_id"] = after
        page = admin_get("/v1/organizations/workspaces", params)
        for ws in page["data"]:
            if ws["name"] == name:
                return ws["id"]
        if not page.get("has_more"):
            raise RuntimeError(f"no workspace named {name!r}")
        after = page["last_id"]


def tokens(item):
    cache = item.get("cache_creation") or {}
    tools = item.get("server_tool_use") or {}
    return (
        item.get("uncached_input_tokens", 0)
        + item.get("cache_read_input_tokens", 0)
        + item.get("output_tokens", 0)
        + cache.get("ephemeral_5m_input_tokens", 0)
        + cache.get("ephemeral_1h_input_tokens", 0)
        + tools.get("web_search_requests", 0)
    )


def usage_since(wsid, start):
    params = {
        "starting_at": start.isoformat().replace("+00:00", "Z"),
        "bucket_width": "1m",
        "workspace_ids[]": [wsid],
        "group_by[]": ["api_key_id", "model"],
        "limit": LOOKBACK_MIN + 5,
    }
    hits = []
    while True:
        report = admin_get("/v1/organizations/usage_report/messages", params)
        for bucket in report["data"]:
            for item in bucket["results"]:
                count = tokens(item)
                if count:
                    hits.append(
                        {
                            "at": bucket["starting_at"],
                            "api_key_id": item.get("api_key_id"),
                            "model": item.get("model"),
                            "tokens": count,
                        }
                    )
        if not report.get("has_more") or not report.get("next_page"):
            return hits
        params["page"] = report["next_page"]


def notify(text, title, priority):
    url = os.environ.get("ALERT_URL")
    if not url:
        print(f"!! {title}: {text}\n!! ALERT_URL unset, nothing was delivered")
        return False
    if "hooks.slack.com" in url:
        body = json.dumps({"text": f"*{title}*\n{text}"}).encode()
        headers = {"Content-Type": "application/json"}
    else:  # ntfy and anything else that accepts a plain-text body
        body = text.encode()
        headers = {"Title": title, "Priority": priority, "Tags": "rotating_light"}
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=20) as resp:
        resp.read()
    return True


def scan():
    wsid = workspace_id(WORKSPACE)
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    start = now - timedelta(minutes=LOOKBACK_MIN)
    hits = usage_since(wsid, start)

    state["last_run"] = now.isoformat()
    state["last_ok"] = True
    return hits


@app.function(image=image, secrets=[secret], schedule=modal.Cron("*/5 * * * *"))
def check():
    try:
        hits = scan()
    except Exception as exc:
        # A watcher that fails quietly is worse than none. Surface the
        # failure itself, then re-raise so the run is marked failed.
        state["last_ok"] = False
        notify(f"canary watcher failed: {exc}", "Canary watcher error", "default")
        raise

    if not hits:
        print(f"clean: no usage in workspace {WORKSPACE!r} since {LOOKBACK_MIN}m ago")
        return

    alerted = set(state.get("alerted", []))
    fresh = [h for h in hits if h["at"] not in alerted]
    if not fresh:
        print(f"{len(hits)} hit(s), all already reported")
        return

    lines = [
        f"{h['at']}  key={h['api_key_id']}  model={h['model']}  tokens={h['tokens']}"
        for h in sorted(fresh, key=lambda h: h["at"])
    ]
    text = (
        f"A key in the '{WORKSPACE}' workspace was used. Nothing legitimate "
        f"calls these keys.\n\n" + "\n".join(lines) + "\n\nRevoke the key in the "
        "Console, then work out which plant was taken."
    )
    print(text)

    # Only record the buckets once delivery succeeded, so a webhook outage
    # retries on the next poll instead of swallowing the only alert.
    if notify(text, "CANARY KEY USED", "urgent"):
        keep = {h["at"] for h in hits} | alerted
        cutoff = (start - timedelta(hours=6)).isoformat().replace("+00:00", "Z")
        state["alerted"] = sorted(a for a in keep if a >= cutoff)
    raise RuntimeError(f"canary used: {len(fresh)} new bucket(s)")


@app.function(image=image, secrets=[secret], schedule=modal.Cron("0 7 * * *"))
def heartbeat():
    """Prove the watcher is still alive.

    Silence from a tripwire is indistinguishable from a tripwire that has
    stopped running, which is the failure mode worth guarding against.
    """
    last = state.get("last_run", "never")
    ok = state.get("last_ok", False)
    notify(
        f"canary watcher alive; last poll {last}, healthy={ok}",
        "Canary watcher heartbeat",
        "min",
    )


@app.function(image=image, secrets=[secret])
def probe_remote():
    return scan()


@app.local_entrypoint()
def probe():
    """Run one poll and print what it sees, without alerting.

    Runs remotely so the admin key stays in Modal and never has to be
    present in the local shell.
    """
    print(json.dumps(probe_remote.remote(), indent=2))
