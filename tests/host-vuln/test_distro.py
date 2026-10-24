"""Tests for host-vuln-distro: version helpers, and the SQL path against a synthetic DB."""
import os, re, subprocess, unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures")
BIN = os.environ.get("HOST_VULN_BIN", os.path.expanduser("~/.local/bin"))
DISTRO = os.path.join(BIN, "host-vuln-distro")


def load(path, name):
    spec = spec_from_loader(name, SourceFileLoader(name, path))
    mod = module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class VersionHelpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = load(DISTRO, "hvdistro")

    def test_upstream_strips_revision_and_epoch(self):
        self.assertEqual(self.m.upstream("7.36.0-r0"), "7.36.0")
        self.assertEqual(self.m.upstream("1.0.9-1"), "1.0.9")
        self.assertEqual(self.m.upstream("0:1.1.0-7.el10_1"), "1.1.0")
        # An upstream version may itself contain a hyphen; only a trailing revision goes.
        self.assertEqual(self.m.upstream("1.0-beta"), "1.0-beta")

    def test_revision_beyond_first(self):
        # First packaging of a NEW upstream release: the version carries the fix.
        self.assertFalse(self.m.revision_beyond_first("1.2.1-r0"))
        self.assertFalse(self.m.revision_beyond_first("1.2.1-1"))
        # Only the revision moved: the patch IS the fix, so stripping would lose it.
        self.assertTrue(self.m.revision_beyond_first("1.2.0-r1"))
        self.assertTrue(self.m.revision_beyond_first("1.2.0-2"))
        self.assertTrue(self.m.revision_beyond_first("7.88.1-10+deb12u5"))

    def test_usable_threshold_rejects_snapshots_and_prereleases(self):
        for bad in ("0.8+r127+g55d783d", "0.9_rc3", "8.22.0~rc2", "2.0-rc1", ""):
            self.assertFalse(self.m.usable_threshold(bad), bad)
        for good in ("1.2.1", "9.20.30", "1.1.1w", "2.46.1"):
            self.assertTrue(self.m.usable_threshold(good), good)

    def test_verkey_never_raises_on_mixed_components(self):
        # REGRESSION: the first sort key mixed ints and strs and raised TypeError.
        vk = self.m.verkey
        self.assertLess(vk("1.2.0"), vk("1.2.1"))
        self.assertLess(vk("1.2.0"), vk("1.2.0a"))
        sorted([vk("1.2.0"), vk("1.2.0a"), vk("1.10.0"), vk("1.2")])

    def test_archlinux_is_not_a_configured_feed(self):
        # Dormant upstream and AVG-only ids; see the ROLLING comment. If someone re-adds
        # it, the CVE-id filter would silently discard everything it provides.
        self.assertNotIn(("archlinux", "rolling"), self.m.ROLLING)
        self.assertIn(("debian", "unstable"), self.m.ROLLING)


class SyntheticDatabase(unittest.TestCase):
    """Exercises the real SQL and bucketing against a hand-built DB."""

    @classmethod
    def setUpClass(cls):
        out = subprocess.run(
            [DISTRO, os.path.join(FIX, "sbom-sample.cdx.json"),
             "--db", os.path.join(FIX, "test-vuln.db"),
             "--patched-map", os.path.join(FIX, "patches-distro.json"),
             "--suppress", os.path.join(FIX, "suppress-distro.toml"),
             "--unfixed-since-year", "2025"],
            capture_output=True, text=True)
        cls.rc, cls.out, cls.err = out.returncode, out.stdout, out.stderr
        if out.returncode != 0:
            raise AssertionError(f"failed ({out.returncode}): {out.stderr}\n{out.stdout}")
        cls.ids = set()
        for line in cls.out.splitlines():
            if line.startswith("CVES_DISTRO"):
                cls.ids = set(line.split()[1:])

    def test_version_bump_fix_is_reported_with_its_threshold(self):
        self.assertIn("CVE-2026-00001", self.ids)
        self.assertRegex(self.out, r"brotli\s+1\.2\.0\s+->\s+1\.2\.1")

    def test_sources_are_unioned_not_duplicated(self):
        # CVE-2026-00001 appears via debian (< 1.2.1-1) and alpine (< 1.2.1-r0).
        self.assertRegex(self.out, r"brotli.*\[alpine/edge, debian/unstable\]")

    def test_recent_unfixed_is_reported(self):
        self.assertIn("CVE-2026-00002", self.ids)
        self.assertIn("AFFECTED, NO FIX PUBLISHED", self.out)

    def test_ancient_unfixed_is_age_gated(self):
        # Debian's unfixed set holds decades of wontfix entries; age is the only
        # discriminator available, since fix.state is "not-fixed" for both.
        self.assertNotIn("CVE-2004-00003", self.ids)

    def test_revision_only_fix_lands_in_its_own_bucket(self):
        self.assertIn("CVE-2026-00004", self.ids)
        self.assertIn("PATCHED AT YOUR EXACT VERSION", self.out)
        self.assertRegex(self.out, r"revpkg\s+1\.2\.0")

    def test_rejected_cves_are_dropped(self):
        self.assertNotIn("CVE-2026-00005", self.ids)

    def test_non_cve_identifiers_are_dropped(self):
        self.assertNotIn("AVG-123", self.ids)
        self.assertNotIn("avgpkg", self.out)

    def test_unconfigured_feeds_are_ignored(self):
        self.assertNotIn("CVE-2026-00007", self.ids)
        self.assertNotIn("wrongfeed", self.out)

    def test_nixpkgs_patched_is_dropped(self):
        self.assertNotIn("CVE-2026-00008", self.ids)
        self.assertIn("patched in nixpkgs", self.out)

    def test_suppression_applies_to_the_distro_pass(self):
        self.assertNotIn("CVE-2099-00009", self.ids)
        self.assertIn("suppressed", self.out)

    def test_prerelease_threshold_is_dropped(self):
        self.assertNotIn("CVE-2026-00010", self.ids)

    def test_only_contributing_feeds_are_listed(self):
        # REGRESSION: archlinux was advertised as a source while supplying nothing.
        src = next(l for l in self.out.splitlines() if l.startswith("sources:"))
        self.assertNotIn("ubuntu", src)

    def test_feeds_absent_from_the_database_are_flagged(self):
        # The synthetic DB holds only debian/unstable and alpine/edge, so the other
        # configured feeds are missing. That is coverage loss with no symptom otherwise:
        # a rename or dropped provider would just look like fewer findings.
        line = next(l for l in self.out.splitlines() if l.startswith("FEEDS_QUIET"))
        flagged = set(line.split()[1:])
        self.assertEqual(flagged, {"chainguard/rolling", "wolfi/rolling",
                                   "minimos/rolling", "hummingbird/rolling"})
        self.assertIn("NOT IN THE DATABASE", self.out)

    def test_missing_db_fails_loudly(self):
        out = subprocess.run([DISTRO, os.path.join(FIX, "sbom-sample.cdx.json"),
                              "--db", "/nonexistent/vuln.db"],
                             capture_output=True, text=True)
        self.assertNotEqual(out.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
