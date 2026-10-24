"""Tests for host-vuln-patches pedigree extraction (the --from-sbom path)."""
import json, os, subprocess, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures")
BIN = os.environ.get("HOST_VULN_BIN", os.path.expanduser("~/.local/bin"))
PATCHES = os.path.join(BIN, "host-vuln-patches")


class Pedigree(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = subprocess.run([PATCHES, "--from-sbom", os.path.join(FIX, "sbom-sample.cdx.json")],
                             capture_output=True, text=True)
        if out.returncode != 0:
            raise AssertionError(f"failed ({out.returncode}): {out.stderr}")
        cls.r = json.loads(out.stdout)
        cls.by = {(p["pname"], p["version"]): set(p["cves"]) for p in cls.r["packages"]}

    def test_unions_cves_across_components_of_one_package(self):
        # avahi appears twice (out and dev); both sets must merge, not overwrite.
        self.assertEqual(self.by[("avahi", "0.8")],
                         {"CVE-2023-38471", "CVE-2021-3468", "CVE-2026-24401"})

    def test_only_security_resolves_count(self):
        # type="other" is a feature backport, not a fix for this CVE.
        self.assertEqual(self.by[("cups", "2.4.19")], {"CVE-2026-87875"})

    def test_non_cve_ids_are_ignored(self):
        self.assertNotIn(("ghsaonly", "1.0"), self.by)

    def test_packages_without_usable_pedigree_are_absent(self):
        self.assertNotIn(("nopedigree", "2.0"), self.by)
        self.assertNotIn(("emptypatches", "3.0"), self.by)

    def test_source_is_reported(self):
        self.assertTrue(any("sbom-pedigree" in s for s in self.r["sources"]))

    def test_no_package_has_an_empty_cve_list(self):
        for p in self.r["packages"]:
            self.assertTrue(p["cves"], p)


if __name__ == "__main__":
    unittest.main(verbosity=2)
