#!/usr/bin/env bash
# Test suite for the host-vuln-* tools.
#
#   ./run-tests.sh                 test the DEPLOYED scripts in ~/.local/bin
#   HOST_VULN_BIN=... ./run-tests.sh   test another copy
#
# Why these exist: in one session of building this, seven bugs shipped and exactly one
# was caught by anything resembling a test -- the rest surfaced by luck, by re-reading
# the code, or by someone asking a good question. The tools suppress 26 of 35 findings
# in the CPE pass and roughly half the distro rows, and a regression in that logic hides
# a real vulnerability silently. Cases marked REGRESSION in the files below are bugs that
# actually shipped; do not delete one to make a change pass.
#
# No network and no 3.3 GB grype database needed: the SQL path runs against a synthetic
# SQLite built by make_test_db.py, which mirrors only the tables and columns the tools
# read. That doubles as documentation of the coupling to grype's internal schema, and
# will fail here if that schema moves.
set -uo pipefail
cd "$(dirname "$0")"

BIN=${HOST_VULN_BIN:-$HOME/.local/bin}
export HOST_VULN_BIN="$BIN"

fail=0
for t in host-vuln-filter host-vuln-patches host-vuln-distro; do
  if [[ ! -x $BIN/$t ]]; then
    echo "MISSING: $BIN/$t -- run 'chezmoi apply' first" >&2
    exit 2
  fi
done

echo "== rebuilding the synthetic database =="
python3 make_test_db.py fixtures/test-vuln.db >/dev/null || { echo "FAILED to build test DB" >&2; exit 2; }

for f in test_filter.py test_patches.py test_distro.py; do
  echo
  echo "== $f =="
  python3 "$f" 2>&1 | tail -4
  # shellcheck disable=SC2181
  [[ ${PIPESTATUS[0]} -eq 0 ]] || fail=1
done

echo
echo "== smoke: each tool prints usage and exits cleanly =="
for t in host-vuln-filter host-vuln-patches host-vuln-distro; do
  if "$BIN/$t" --help >/dev/null 2>&1; then echo "  ok   $t --help"; else echo "  FAIL $t --help"; fail=1; fi
done

echo
if ((fail)); then echo "SUITE FAILED"; else echo "SUITE PASSED"; fi
exit $fail
