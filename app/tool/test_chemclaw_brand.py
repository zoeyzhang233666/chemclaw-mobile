"""ChemClaw Mobile source-only branding regressions. Run with unittest."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

def source(p):
    return (ROOT / p).read_text(encoding='utf-8')

class ChemClawBrandTest(unittest.TestCase):
    def test_mobile_identity_isolated(self):
        self.assertIn("static const name = 'ChemClaw 手机版';", source('app/lib/state/app_info.dart'))
        self.assertIn('applicationId = "com.chemcloud.chemclaw.mobile"', source('app/android/app/build.gradle.kts'))
        self.assertIn("const updateRepo = 'zoeyzhang233666/chemclaw-mobile'", source('app/lib/update/update_config.dart'))

    def test_paper_color_consistency(self):
        s = source('app/lib/ui/theme/accent.dart')
        for value in ['0xFFD97757', '0xFFE08A6D']:
            self.assertIn(value, s)
        self.assertIn('chemPaper', source('app/lib/ui/theme/palette.dart'))

    def test_vector_cloud_and_no_original_launcher_png(self):
        dart = source('app/lib/ui/shell/brand_glyph.g.dart')
        self.assertIn('BrandGlyph', dart)
        self.assertIn('..cubicTo(26.6, 23.5, 29.0, 21.3, 29.0, 18.4)', dart)
        for name in ['glyph-light.svg','glyph-dark.svg','glyph-mono.svg','tile.svg']:
            self.assertIn('M8.5,23.5', source('app/assets/brand/' + name))
        d = source('app/android/app/src/main/res/drawable/ic_chemclaw_foreground.xml')
        self.assertIn('M8.5,23.5', d)
        self.assertIn('M8.5,23.5', source('app/android/app/src/main/res/drawable/ic_stat_dsh.xml'))
        r = ROOT / 'app/android/app/src/main/res'
        for density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']:
            self.assertFalse(list((r / ('mipmap-' + density)).glob('ic_launcher*.png')))
        for name in ['ic_launcher','ic_launcher_round','ic_launcher_night','ic_launcher_night_round','ic_launcher_frost','ic_launcher_frost_round','ic_launcher_ink','ic_launcher_ink_round']:
            self.assertIn('@drawable/ic_chemclaw_foreground',
                source('app/android/app/src/main/res/mipmap-anydpi-v26/' + name + '.xml'))

    def test_mcp_not_hardcoded_to_a_real_host(self):
        config = source('config/chemcloud-mcp.example.yml')
        self.assertIn('transport: streamable-http', config)
        self.assertIn('.invalid/mcp', config)
        self.assertNotIn('Bearer sk-', config)

if __name__ == '__main__':
    unittest.main()
