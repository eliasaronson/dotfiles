"""Build a tiny SQLite matching the subset of grype's v6 schema host-vuln-distro reads.

Exercising the real 3.3 GB DB would make these tests slow, non-deterministic and
dependent on whatever Anchore published today. This mirrors only the five tables and
columns the tool queries -- which doubles as documentation of that coupling, and will
fail loudly here if grype's schema moves.
"""
import json, os, sqlite3, sys

SCHEMA = """
CREATE TABLE operating_systems (id INTEGER PRIMARY KEY, name TEXT, release_id TEXT,
  major_version TEXT, minor_version TEXT, label_version TEXT, codename TEXT, channel TEXT,
  eol_date TEXT, eoas_date TEXT);
CREATE TABLE packages (id INTEGER PRIMARY KEY, ecosystem TEXT, name TEXT);
CREATE TABLE vulnerability_handles (id INTEGER PRIMARY KEY, name TEXT, status TEXT,
  published_date TEXT, modified_date TEXT, withdrawn_date TEXT, provider_id TEXT, blob_id INTEGER);
CREATE TABLE blobs (id INTEGER PRIMARY KEY, value TEXT);
CREATE TABLE affected_package_handles (id INTEGER PRIMARY KEY, vulnerability_id INTEGER,
  operating_system_id INTEGER, package_id INTEGER, blob_id INTEGER);
"""

OSES = [(1, "debian", "unstable"), (2, "alpine", "edge"), (3, "ubuntu", "")]

# (cve, status, package, version-less-pkg-name, os_id, constraint or None)
ROWS = [
    # a normal fix: upstream version moved, we are behind it
    ("CVE-2026-00001", "active", "brotli",     1, "< 1.2.1-1"),
    # affected with no fix recorded, recent -> unfixed bucket
    ("CVE-2026-00002", "active", "brotli",     1, None),
    # affected with no fix recorded, ancient -> age-gated out
    ("CVE-2004-00003", "active", "oldpkg",     1, None),
    # fix is a revision bump on the EXACT installed upstream version -> revfix bucket
    ("CVE-2026-00004", "active", "revpkg",     1, "< 1.2.0-2"),
    # every provider rejected this CVE -> must be dropped entirely
    ("CVE-2026-00005", "rejected", "rejpkg",   1, "< 2.0-1"),
    # non-CVE identifier (Arch style) -> must be dropped
    ("AVG-123",        "active", "avgpkg",     1, "< 2.0-1"),
    # a feed that is not a configured rolling source -> must be ignored
    ("CVE-2026-00007", "active", "wrongfeed",  3, "< 2.0-1"),
    # would be affected, but the nixpkgs derivation patches it
    ("CVE-2026-00008", "active", "patchedpkg", 1, "< 2.0-1"),
    # would be affected, but a suppression entry covers it
    ("CVE-2099-00009", "active", "supppkg",    1, "< 2.0-1"),
    # threshold is a prerelease -> not comparable, must be dropped
    ("CVE-2026-00010", "active", "prerelpkg",  1, "< 2.0~rc1-1"),
    # same CVE via a second feed, to prove sources are unioned not duplicated
    ("CVE-2026-00001", "active", "brotli",     2, "< 1.2.1-r0"),
]


def main(path):
    if os.path.exists(path):
        os.unlink(path)
    c = sqlite3.connect(path)
    c.executescript(SCHEMA)
    for oid, name, lab in OSES:
        c.execute("INSERT INTO operating_systems (id,name,label_version,major_version,"
                  "minor_version,codename,channel) VALUES (?,?,?,'','','','')", (oid, name, lab))
    pkg_ids, vuln_ids, bid = {}, {}, 0
    for i, (cve, status, pkg, osid, con) in enumerate(ROWS, start=1):
        if pkg not in pkg_ids:
            pkg_ids[pkg] = len(pkg_ids) + 1
            c.execute("INSERT INTO packages (id,ecosystem,name) VALUES (?,?,?)",
                      (pkg_ids[pkg], "deb", pkg))
        if (cve, status) not in vuln_ids:
            vuln_ids[(cve, status)] = len(vuln_ids) + 1
            c.execute("INSERT INTO vulnerability_handles (id,name,status,provider_id,blob_id) "
                      "VALUES (?,?,?,?,0)", (vuln_ids[(cve, status)], cve, status, "test"))
        bid += 1
        ver = {"type": "dpkg"}
        if con:
            ver["constraint"] = con
        blob = {"ranges": [{"version": ver,
                            "fix": {"state": "fixed" if con else "not-fixed"}}]}
        c.execute("INSERT INTO blobs (id,value) VALUES (?,?)", (bid, json.dumps(blob)))
        c.execute("INSERT INTO affected_package_handles (id,vulnerability_id,"
                  "operating_system_id,package_id,blob_id) VALUES (?,?,?,?,?)",
                  (i, vuln_ids[(cve, status)], osid, pkg_ids[pkg], bid))
    c.commit()
    c.close()
    print(path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "fixtures/test-vuln.db")
