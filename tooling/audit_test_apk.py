#!/usr/bin/env python3
"""Auditable checks for the ChemClaw *test* APK (not a malware clearance).

No downloads, secrets, signing-key material or network calls. Validates the
actual built APK with Android SDK tools before GitHub makes it downloadable.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

EXPECTED_PACKAGE = "com.chemcloud.chemclaw.mobile"
ROOTFS = "assets/runtime/rootfs-arm64-v8a.tar.xz"
SENSITIVE = {
    "android.permission.MANAGE_EXTERNAL_STORAGE": "All-files storage access",
    "android.permission.REQUEST_INSTALL_PACKAGES": "Install other applications",
    "android.permission.SYSTEM_ALERT_WINDOW": "Display over other apps",
    "android.permission.WRITE_SECURE_SETTINGS": "Privileged settings access",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS": "Battery exception",
    "android.permission.RECORD_AUDIO": "Microphone access",
}

def locate_tool(sdk, name):
    parent = Path(sdk) / "build-tools"
    candidates = sorted(parent.glob(f"*/{name}"), key=lambda p: tuple(
        int(x) if x.isdigit() else x for x in re.split(r"(\d+)", p.parent.name)
    ))
    if not candidates:
        raise RuntimeError(f"Android SDK build-tools {name} not found in {parent}")
    return str(candidates[-1])

def run_tool(path, *args):
    proc = subprocess.run([path, *map(str, args)], capture_output=True, text=True, check=False)
    if proc.returncode:
        raise RuntimeError(f"{Path(path).name} exited {proc.returncode}: {proc.stderr[-800:]}")
    return proc.stdout

def parse_badging(raw):
    def required(pattern, field):
        match = re.search(pattern, raw)
        if not match:
            raise RuntimeError(f"aapt badging missing {field}")
        return match.group(1)
    return {
        "application_id": required(r"package: name='([^']+)'", "package"),
        "version_code": required(r"versionCode='([^']+)'", "versionCode"),
        "version_name": required(r"versionName='([^']+)'", "versionName"),
        "min_sdk": required(r"sdkVersion:'([^']+)'", "minSdk"),
        "target_sdk": required(r"targetSdkVersion:'([^']+)'", "targetSdk"),
    }

def parse_signature(raw):
    scheme = [int(n) for n, value in re.findall(
        r"Verified using v([1234]) scheme[^:]*:\s*(true|false)", raw, re.I
    ) if value.lower() == "true"]
    if not ({2, 3, 4} & set(scheme)):
        raise RuntimeError("APK is not verified with v2/v3/v4 APK signing")
    sha = re.search(r"Signer #1 certificate SHA-256 digest:\s*([a-fA-F0-9:]+)", raw)
    dn = re.search(r"Signer #1 certificate DN:\s*(.*)", raw)
    if not sha or not dn:
        raise RuntimeError("Cannot establish APK signer certificate identity")
    return {
        "schemes": scheme,
        "certificate_sha256": sha.group(1).replace(":", "").lower(),
        "certificate_dn": dn.group(1).strip(),
        "temporary_debug_signing": "android debug" in dn.group(1).lower(),
    }

def parse_permissions(raw):
    return sorted(set(re.findall(r"uses-permission(?:-[\w]+)?: name='([^']+)'", raw)))

def sha256(path):
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for piece in iter(lambda: f.read(1024 * 1024), b""):
            hasher.update(piece)
    return hasher.hexdigest()

def audit(apk, sdk):
    with zipfile.ZipFile(apk) as z:
        names = set(z.namelist())
        if ROOTFS not in names:
            raise RuntimeError(f"DSH rootfs missing: {ROOTFS}")
        if not any(name.startswith("lib/arm64-v8a/") for name in names):
            raise RuntimeError("ARM64 libraries are missing")
        corrupt = z.testzip()
        if corrupt:
            raise RuntimeError(f"APK archive CRC error: {corrupt}")
    badging = parse_badging(run_tool(locate_tool(sdk, "aapt"), "dump", "badging", apk))
    if badging["application_id"] != EXPECTED_PACKAGE:
        raise RuntimeError(f"unexpected package id: {badging['application_id']}")
    if int(badging["min_sdk"]) < 26:
        raise RuntimeError("unexpected minSdk, must be Android 8+")
    signed = parse_signature(run_tool(locate_tool(sdk, "apksigner"),
                                      "verify", "--verbose", "--print-certs", apk))
    permissions = parse_permissions(run_tool(locate_tool(sdk, "aapt"), "dump", "permissions", apk))
    if "android.permission.READ_PHONE_STATE" in permissions:
        raise RuntimeError("READ_PHONE_STATE reappeared in the merged APK")
    return {
        "file": Path(apk).name,
        "size_bytes": Path(apk).stat().st_size,
        "apk_sha256": sha256(apk),
        "package": badging,
        "signature": signed,
        "permissions": permissions,
        "sensitive_permission_review": {k: reason for k, reason in SENSITIVE.items() if k in permissions},
        "status": "structurally verified; not malware-scanned or approved for public release",
        "public_distribution_approved": False,
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--sdk", default=os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not args.sdk:
        parser.error("ANDROID_HOME or --sdk is required")
    try:
        report = audit(args.apk, args.sdk)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(json.dumps({k: report[k] for k in ("file", "apk_sha256", "signature", "status")}, indent=2))
        return 0
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"APK safety verification failed: {error}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
