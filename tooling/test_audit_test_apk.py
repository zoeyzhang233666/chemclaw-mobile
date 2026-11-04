"""Deterministic tests for the APK security diagnostics parser."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_test_apk import parse_badging, parse_permissions, parse_signature

class AuditTestApkTest(unittest.TestCase):
    def test_parse_package(self):
        data = ("package: name='com.chemcloud.chemclaw.mobile' versionCode='11041234' versionName='0.1.0'\n"
                "sdkVersion:'26'\ntargetSdkVersion:'28'\n")
        parsed = parse_badging(data)
        self.assertEqual(parsed["application_id"], "com.chemcloud.chemclaw.mobile")
        self.assertEqual(parsed["target_sdk"], "28")

    def test_reject_untrusted_signature(self):
        with self.assertRaisesRegex(RuntimeError, "not verified"):
            parse_signature("Verified using v1 scheme: true\nVerified using v2 scheme: false")

    def test_debug_cert_is_explicit(self):
        raw = ("Verified using v2 scheme (APK Signature Scheme v2): true\n"
               "Verified using v3 scheme (APK Signature Scheme v3): false\n"
               "Signer #1 certificate DN: CN=Android Debug, O=Android, C=US\n"
               "Signer #1 certificate SHA-256 digest: " + "a" * 64 + "\n")
        s = parse_signature(raw)
        self.assertTrue(s["temporary_debug_signing"])
        self.assertIn(2, s["schemes"])

    def test_permissions_are_deduplicated(self):
        data = ("package: com.chemcloud.chemclaw.mobile\n"
                "uses-permission: name='android.permission.INTERNET'\n"
                "uses-permission: name='android.permission.MANAGE_EXTERNAL_STORAGE'\n"
                "uses-permission: name='android.permission.INTERNET'\n")
        self.assertEqual(parse_permissions(data),
                         ["android.permission.INTERNET", "android.permission.MANAGE_EXTERNAL_STORAGE"])

if __name__ == "__main__":
    unittest.main()
