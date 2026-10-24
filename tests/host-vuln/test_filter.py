"""Tests for host-vuln-filter.

Every case below is either a documented filter rule or a REGRESSION for a bug that
actually shipped. The regressions are marked; do not delete them to make a change pass.
"""
import json, os, subprocess, sys, unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures")
BIN = os.environ.get("HOST_VULN_BIN", os.path.expanduser("~/.local/bin"))
FILTER = os.path.join(BIN, "host-vuln-filter")


def load(path, name):
    """Import an extensionless executable as a module."""
    spec = spec_from_loader(name, SourceFileLoader(name, path))
    mod = module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Predicates(unittest.TestCase):
    """Version classification. These decide whether a finding is suppressed, so a wrong
    answer here hides a real vulnerability."""

    @classmethod
    def setUpClass(cls):
        cls.m = load(FILTER, "hvfilter")

    def test_dates_are_dates(self):
        for v in ("2023-09-12", "2024-10-01", "2017-01-12"):
            self.assertTrue(self.m.is_date(v), v)
            self.assertFalse(self.m.comparable(v), v)

    def test_prereleases(self):
        for v in ("3.15.0a6", "3.15.0rc3", "2.93test9", "0.9-rc4", "0.9_rc3",
                  "8.22.0~rc2", "1.0.0-beta", "2.0-alpha1"):
            self.assertTrue(self.m.is_prerelease(v), v)
            self.assertFalse(self.m.comparable(v), v)

    def test_openssl_letter_releases_are_NOT_prereleases(self):
        # REGRESSION: the first version of this regex treated a bare trailing letter as a
        # prerelease. openssl 1.1.1a..1.1.1w are real releases, so every openssl finding
        # would have been silently suppressed.
        for v in ("1.1.1a", "1.1.1b", "1.1.1w", "1.0.2k"):
            self.assertFalse(self.m.is_prerelease(v), v)
            self.assertTrue(self.m.comparable(v), v)

    def test_plain_releases_are_comparable(self):
        for v in ("8.23.0", "2.45", "156.0.8087.47", "5.4.86", "0.10.2", "9.20.30"):
            self.assertTrue(self.m.comparable(v), v)


class EndToEnd(unittest.TestCase):
    """Runs the real CLI, which is the contract host-vuln-scan depends on."""

    @classmethod
    def setUpClass(cls):
        out = subprocess.run(
            [FILTER, os.path.join(FIX, "grype-sample.json"),
             "--patched-map", os.path.join(FIX, "patches-sample.json"),
             "--suppress", os.path.join(FIX, "suppress-sample.toml")],
            capture_output=True, text=True)
        if out.returncode != 0:
            raise AssertionError(f"filter failed ({out.returncode}): {out.stderr}")
        cls.r = json.loads(out.stdout)
        cls.kept = {(f["id"], f["name"]) for f in cls.r["kept"]}
        cls.reason = {(f["id"], f["name"]): f["_reason"] for f in cls.r["removed"]}

    def test_dedupes_by_cve_package_version(self):
        # REGRESSION: grype emits one match per store path, so curl appeared 3x and the
        # counts disagreed with the table a human was reading.
        self.assertEqual(self.r["summary"]["total"], 13)   # 15 raw matches, curl x3 collapsed
        self.assertEqual(sum(1 for f in self.r["kept"] if f["name"] == "curl"), 1)

    def test_multibranch_fix_is_kept(self):
        # curl 8.22.0 sits between recorded fixes; 8.23.0 fixes its branch, so this is
        # genuinely outstanding and must survive the already-fixed rule.
        self.assertIn(("CVE-2026-92392", "curl"), self.kept)

    def test_already_fixed_uses_the_maximum(self):
        self.assertEqual(self.reason[("CVE-2026-6791", "glibc")], "already-fixed")
        self.assertEqual(self.reason[("CVE-2020-27815", "linux")], "already-fixed")
        self.assertIn(("CVE-2026-89092", "glibc"), self.kept)   # fix 2.45 > installed

    def test_date_and_prerelease_artefacts(self):
        self.assertEqual(self.reason[("CVE-2023-4039", "gcc")], "artefact:date")
        self.assertEqual(self.reason[("CVE-2025-15367", "python3")], "artefact:prerel")
        self.assertEqual(self.reason[("CVE-2026-12345", "python3")], "artefact:prerel")

    def test_patched_map_is_version_keyed(self):
        # avahi 0.8 is patched; the SAME CVE on avahi 0.9 must NOT be suppressed, or a
        # suppression would outlive the version it was verified against.
        self.assertEqual(self.reason[("CVE-2023-38471", "avahi")], "patched")
        self.assertIn(("CVE-2023-38471", "avahi"), self.kept)
        kept_avahi = [f for f in self.r["kept"] if f["name"] == "avahi"]
        self.assertEqual([f["version"] for f in kept_avahi], ["0.9"])

    def test_suppression_applies_and_carries_its_reason(self):
        self.assertEqual(self.reason[("CVE-2021-43635", "codex")], "suppressed")
        entry = next(f for f in self.r["removed"] if f["id"] == "CVE-2021-43635")
        self.assertIn("CPE collision", entry["_detail"])

    def test_distro_scoped_suppression_does_not_apply_here(self):
        self.assertNotIn(("CVE-2099-00001", "distro-only-pkg"), self.reason)

    def test_openssl_finding_survives(self):
        # REGRESSION, paired with the predicate test above.
        self.assertIn(("CVE-2026-11111", "openssl"), self.kept)

    def test_kev_counted_and_risk_ordered(self):
        self.assertEqual(self.r["summary"]["kev"], 1)
        risks = [f["risk"] for f in self.r["kept"]]
        self.assertEqual(risks, sorted(risks, reverse=True))

    def test_finding_with_no_fix_version_is_kept_not_crashed(self):
        self.assertIn(("CVE-2026-22222", "nofix"), self.kept)

    def test_summary_is_internally_consistent(self):
        s = self.r["summary"]
        self.assertEqual(s["kept"], len(self.r["kept"]))
        self.assertEqual(s["total"], len(self.r["kept"]) + len(self.r["removed"]))
        self.assertEqual(sum(s["removed_by"].values()), len(self.r["removed"]))
        self.assertEqual(s["high_critical"],
                         sum(1 for f in self.r["kept"] if f["sev"] in ("High", "Critical")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
