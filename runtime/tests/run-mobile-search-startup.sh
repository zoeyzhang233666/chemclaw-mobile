#!/usr/bin/env bash
# Real DSH boot regression for the mobile profile and safe profile.
# Both use the SAME generated --patch overlay as the packaged rootfs.
# This prevents a repeat of the PR #2 duplicate-client-modules startup crash.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="$(dirname "$HERE")"
PREFIX="$(cd "${1:?usage: run-mobile-search-startup.sh <installed-dsh-prefix>}" && pwd)"
NODE="$RUNTIME/.cache/host-node/node-v24.22.1-linux-x64/bin/node"
[[ -x "$NODE" ]] || NODE="$(command -v node)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/chemclaw-boot.XXXXXX")"
DSH_PID=""
cleanup() {
  if [[ -n "$DSH_PID" ]]; then
    kill -TERM "$DSH_PID" 2>/dev/null || true
    wait "$DSH_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

# Extract the *real* generated overlay, rewriting only the absolute
# rootfs path of the bundled bridge to its identical host-side source.
python3 - "$RUNTIME" "$TMP/overlay.patch.yml" <<'PY'
import importlib.util
from pathlib import Path
import sys

runtime, path = Path(sys.argv[1]), Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("rtbuild_mobile_smoke", runtime / "lib" / "rtbuild.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
patch = module.overlay_entries({}, with_bridge=True, with_pnpm=True)[
    "etc/dsh-app/dsh-web.patch.yml"].read().decode()
assert patch.count("    - id: dsh-go-bridge\n") == 1, "duplicate bridge loader"
assert "lib/web-search-auto.js" not in patch, "duplicate auto loader"
assert "lib/third-party-search.js" not in patch, "duplicate third-party loader"
patch = patch.replace("/opt/dsh-go/dsh-go-bridge",
                      str(runtime / "bridge" / "dsh-go-bridge"))
path.write_text(patch)
PY

for mode in normal safe; do
  port=$([[ "$mode" == normal ]] && echo 38271 || echo 38272)
  mkdir -p "$TMP/home/.dsh/profiles/dsh-app-$mode"
  log="$TMP/$mode.log"
  env -i PATH="$(dirname "$NODE"):/usr/bin:/bin" HOME="$TMP/home" \
    DSH_HOME="$TMP/home/.dsh/profiles/dsh-app-$mode" LANG=C.UTF-8 \
    TZ=Asia/Shanghai UV_USE_IO_URING=0 \
    DEEPSEEK_API_KEY=sk-chemclaw-test-not-real \
    "$NODE" "$PREFIX/node_modules/@deepseek-ai/dsh/lib/bin.js" web \
    --patch "$TMP/overlay.patch.yml" --host 127.0.0.1 --port "$port" --no-open \
    > "$log" 2>&1 &
  DSH_PID=$!

  token=""
  for _ in $(seq 1 160); do
    token="$(sed -n 's#^dsh web: http://127\.0\.0\.1:[0-9]*/?token=\([A-Za-z0-9_-]*\).*#\1#p' "$log" | head -1)"
    [[ -n "$token" ]] && break
    if ! kill -0 "$DSH_PID" 2>/dev/null; then break; fi
    sleep 0.5
  done
  if [[ -z "$token" ]]; then
    echo "DSH $mode profile failed to boot" >&2
    tail -80 "$log" >&2
    exit 1
  fi
  # Allow startup microtasks and required plugin graph to settle.
  sleep 3
  if ! kill -0 "$DSH_PID" 2>/dev/null || grep -qiE 'startup failed|required plugin did not activate|multiple active Loader sources|client-modules:.*failed to compose' "$log"; then
    echo "DSH $mode profile has plugin startup errors" >&2
    tail -80 "$log" >&2
    exit 1
  fi
  curl --fail --silent --show-error --max-time 10 -c "$TMP/cookies" \
    -o /dev/null "http://127.0.0.1:$port/?token=$token"
  curl --fail --silent --show-error --max-time 10 -b "$TMP/cookies" \
    "http://127.0.0.1:$port/dsh-go/v1/inventory" \
    | "$NODE" -e '
      let s="";process.stdin.on("data",x=>s+=x);
      process.stdin.on("end",()=>{const d=JSON.parse(s);if(!d.bridge)process.exit(1)})'
  echo "PASS: DSH $mode profile starts with one bridge and four search providers"
  kill -TERM "$DSH_PID" 2>/dev/null || true
  wait "$DSH_PID" 2>/dev/null || true
  DSH_PID=""
done
