# ChemClaw Mobile: DSH startup and credential-button regression (2026-11-06)

## Observed failure

The PR #2 Android test APK could not start the local DSH engine, including the safe profile. Its diagnostic log reported:

```
client-modules: package dsh-go-bridge resolves from multiple active Loader sources
```

The two conflicting loader file paths belonged to `web-search-auto.js` and `third-party-search.js` in the same `dsh-go-bridge` package.

## Fix and safety boundaries

- The generated DSH web patch now inserts only `dsh-go-bridge/lib/index.js` from this package; the auto and commercial search implementations are registered from the bridge's web-service injection. They remain independent search providers, but **not separate Loader sources**.
- A minimal or safe-mode runtime without a web service must be able to start the bridge without registering search.
- The APIHub and ChemCloud MCP key buttons can be tapped while the host is offline to show an explicit connection error. They do **not** claim to save a key without a running DSH host; typed secrets are not cleared on failure.
- Keys must only be written through the intended host credential interfaces. Never embed API keys in the APK, source, CI logs, or bug reports.

## Required validation before merge

1. Node regression tests for search registration and absent web service.
2. Real DSH normal- and safe-profile startup using the generated overlay, confirming no required-plugin failure and that bridge inventory is served.
3. Flutter widget, visual golden, Dart package and Android JVM CI checks.
4. Rebuilt ARM64 APK with embedded DSH rootfs, verified signing, package ID, file integrity and SHA-256.
5. On-device acceptance: normal/safe engine start, connect APIHub, save the ChemCloud MCP key, retrieve tools, and execute a cited spot-price query. Desktop ChemClaw remains untouched.

Automated host-side DSH startup checks do not replace Android-device testing. Test builds are not cleared for public release or auto-updates.
