"""Regression: every DSH mode must compose one bridge package source only.

The first PR #2 APK inserted web-search-auto.js and third-party-search.js as
separate active Loader modules. Both belong to dsh-go-bridge/package.json and
DSH client-modules rejected them before normal *or safe* startup.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rtbuild_search", ROOT / "lib" / "rtbuild.py")
rtbuild = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rtbuild)


class ChemClawSearchOverlayTests(unittest.TestCase):
    def test_generated_overlay_uses_one_bridge_loader_package(self):
        entries = rtbuild.overlay_entries({}, with_bridge=True, with_pnpm=True)
        patch = entries["etc/dsh-app/dsh-web.patch.yml"].read().decode()
        self.assertEqual(patch.count("    - id: dsh-go-bridge\n"), 1)
        self.assertEqual(patch.count("      name: /opt/dsh-go/dsh-go-bridge/lib/index.js\n"), 1)
        self.assertNotIn("name: /opt/dsh-go/dsh-go-bridge/lib/web-search-auto.js", patch)
        self.assertNotIn("name: /opt/dsh-go/dsh-go-bridge/lib/third-party-search.js", patch)
        self.assertNotIn("- id: chemclaw-web-search-auto", patch)
        self.assertNotIn("- id: chemclaw-third-party-search", patch)
        self.assertIn("    searchProvider: auto\n", patch)
        self.assertIn("    fetchProvider: http\n", patch)

    def test_no_bridge_has_no_chemclaw_search_registration(self):
        entries = rtbuild.overlay_entries({}, with_bridge=False, with_pnpm=True)
        patch = entries["etc/dsh-app/dsh-web.patch.yml"].read().decode()
        self.assertNotIn("dsh-go-bridge/lib", patch)
        self.assertNotIn("searchProvider: auto", patch)


if __name__ == "__main__":
    unittest.main()
