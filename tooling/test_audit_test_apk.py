"""Deterministic tests for the APK security diagnostics parser."""
import base64
import hashlib
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

    def test_sdk_ranged_signer_from_new_apksigner(self):
        raw = ("Verifies\n"
               "Verified using v1 scheme (JAR signing): false\n"
               "Verified using v2 scheme (APK Signature Scheme v2): true\n"
               "Signer (minSdkVersion=26, maxSdkVersion=32) certificate SHA-256 digest: "
               + "b" * 64 + "\n"
               "Signer (minSdkVersion=26, maxSdkVersion=32) certificate DN: CN=Android Debug,O=Android\n")
        signature = parse_signature(raw)
        self.assertEqual(signature["certificate_sha256"], "b" * 64)
        self.assertEqual(signature["signers"][0]["signer"], "(minSdkVersion=26, maxSdkVersion=32)")
        self.assertTrue(signature["temporary_debug_signing"])

    def test_sdk_ranged_cert_without_dn_is_unknown_not_release(self):
        raw = ("Verified using v3 scheme (APK Signature Scheme v3): true\n"
               "Signer (minSdkVersion=28, maxSdkVersion=99) certificate SHA-256 digest: "
               + "c" * 64 + "\n")
        signature = parse_signature(raw)
        self.assertIsNone(signature["certificate_dn"])
        self.assertIsNone(signature["temporary_debug_signing"])

    def test_multiple_distinct_signers_are_not_mixed(self):
        raw = ("Verified using v2 scheme (APK Signature Scheme v2): true\n"
               "Signer (minSdkVersion=26, maxSdkVersion=27) certificate SHA-256 digest: " + "1" * 64 + "\n"
               "Signer (minSdkVersion=28, maxSdkVersion=99) certificate SHA-256 digest: " + "2" * 64 + "\n"
               "Signer (minSdkVersion=28, maxSdkVersion=99) certificate DN: CN=Android Debug\n")
        s = parse_signature(raw)
        self.assertEqual(len(s["signers"]), 2)
        self.assertIsNone(s["temporary_debug_signing"])
        self.assertEqual(s["signers"][1]["certificate_sha256"], "2" * 64)

    def test_reject_missing_certificate_digest_even_when_v2_verified(self):
        raw = ("Verified using v2 scheme (APK Signature Scheme v2): true\n"
               "Signer #1 certificate DN: CN=Android Debug\n")
        with self.assertRaisesRegex(RuntimeError, "invalid SHA-256"):
            parse_signature(raw)

    def test_reject_truncated_digest(self):
        raw = ("Verified using v2 scheme (APK Signature Scheme v2): true\n"
               "Signer #1 certificate SHA-256 digest: ff00\n")
        with self.assertRaisesRegex(RuntimeError, "invalid SHA-256"):
            parse_signature(raw)

    def test_verified_pem_fallback_without_signer_labels(self):
        # Synthetic DER validates the fingerprint plumbing. APK trust still
        # requires apksigner verify to exit successfully on the actual file.
        der = bytes((0x30, 0x04, 0x02, 0x02, 0x00, 0x01))
        pem = "-----BEGIN CERTIFICATE-----\\n" + base64.b64encode(der).decode() + "\\n-----END CERTIFICATE-----"
        result = parse_signature(
            "Verified using v2 scheme (APK Signature Scheme v2): true\\n" + pem
        )
        self.assertEqual(result["certificate_sha256"], hashlib.sha256(der).hexdigest())
        self.assertIsNone(result["temporary_debug_signing"])
        self.assertEqual(result["signers"][0]["signer"], "pem-1")

    def test_verified_signature_without_any_certificate_still_fails(self):
        with self.assertRaisesRegex(RuntimeError, "no signer fields or X.509 PEM"):
            parse_signature("Verified using v2 scheme (APK Signature Scheme v2): true\\n")

    def test_permissions_are_deduplicated(self):
        data = ("package: com.chemcloud.chemclaw.mobile\n"
                "uses-permission: name='android.permission.INTERNET'\n"
                "uses-permission: name='android.permission.MANAGE_EXTERNAL_STORAGE'\n"
                "uses-permission: name='android.permission.INTERNET'\n")
        self.assertEqual(parse_permissions(data),
                         ["android.permission.INTERNET", "android.permission.MANAGE_EXTERNAL_STORAGE"])

if __name__ == "__main__":
    unittest.main()
