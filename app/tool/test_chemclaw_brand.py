"""ChemClaw Mobile source-only branding regressions. Run with unittest."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

def source(p):
    return (ROOT / p).read_text(encoding='utf-8')

class ChemClawBrandTest(unittest.TestCase):
    def test_mobile_identity_isolated(self):
        self.assertIn("static const name = 'ChemClaw';", source('app/lib/state/app_info.dart'))
        self.assertIn('android:label="ChemClaw"', source('app/android/app/src/main/AndroidManifest.xml'))
        self.assertIn('applicationId = "com.chemcloud.chemclaw.mobile"', source('app/android/app/build.gradle.kts'))
        self.assertIn("const updateRepo = 'zoeyzhang233666/chemclaw-mobile'", source('app/lib/update/update_config.dart'))

    def test_paper_color_consistency(self):
        s = source('app/lib/ui/theme/accent.dart')
        for value in ['0xFFD97757', '0xFFE08A6D']:
            self.assertIn(value, s)
        self.assertIn('chemPaper', source('app/lib/ui/theme/palette.dart'))

    def test_vector_cloud_and_launcher_asset_consistency(self):
        dart = source('app/lib/ui/shell/brand_glyph.g.dart')
        self.assertIn('BrandGlyph', dart)
        self.assertIn('..cubicTo(26.6, 23.5, 29.0, 21.3, 29.0, 18.4)', dart)
        for name in ['glyph-light.svg','glyph-dark.svg','glyph-mono.svg','tile.svg']:
            self.assertIn('M8.5,23.5', source('app/assets/brand/' + name))
        d = source('app/android/app/src/main/res/drawable/ic_chemclaw_foreground.xml')
        self.assertIn('M8.5,23.5', d)
        self.assertIn('M8.5,23.5', source('app/android/app/src/main/res/drawable/ic_stat_dsh.xml'))
        r = ROOT / 'app/android/app/src/main/res'
        # Before image regeneration there may be no PNGs. After regeneration,
        # all 60 must be our generated cloud assets, never partial fish-tail sets.
        raster = [list((r / ('mipmap-' + density)).glob('ic_launcher*.png'))
                  for density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']]
        counts = [len(files) for files in raster]
        self.assertIn(counts, [[0] * 5, [12] * 5], 'incomplete launcher asset migration')
        self.assertIn('BEZIERS', source('app/tool/render_chemclaw_launcher.py'))
        for name in ['ic_launcher','ic_launcher_round','ic_launcher_night','ic_launcher_night_round','ic_launcher_frost','ic_launcher_frost_round','ic_launcher_ink','ic_launcher_ink_round']:
            self.assertIn('@drawable/ic_chemclaw_foreground',
                source('app/android/app/src/main/res/mipmap-anydpi-v26/' + name + '.xml'))

    def test_default_paper_theme(self):
        self.assertIn('AppAccent accent = AppAccent.paper',
                      source('app/lib/ui/theme/app_theme.dart'))
        self.assertIn("this.presetId = 'paper'",
                      source('app/lib/state/appearance_state.dart'))
        self.assertIn('forAccent(AppAccent accent)',
                      source('app/lib/ui/theme/palette.dart'))

    def test_manifest_android_classes_resolve_in_source_namespace(self):
        manifest = source('app/android/app/src/main/AndroidManifest.xml')
        self.assertNotIn('android:name=".', manifest)
        self.assertNotIn('android:targetActivity=".', manifest)
        self.assertIn('android:name="io.github.ccch1mneyyy.dsh_app.MainActivity"', manifest)
        self.assertIn('android:name="io.github.ccch1mneyyy.dsh_app.LauncherMist"', manifest)

    def test_mcp_not_hardcoded_to_a_real_host(self):
        config = source('config/chemcloud-mcp.example.yml')
        self.assertIn('transport: streamable-http', config)
        self.assertIn('.invalid/mcp', config)
        self.assertNotIn('Bearer sk-', config)

if __name__ == '__main__':
    unittest.main()
