# ChemClaw mobile adaptation — Paper, connectivity, pet and schedules

This document describes the mobile PR's scoped implementation; it does not
assert feature parity with the desktop ChemClaw application.

## Shipped in this change

- Android cloud launcher: reduce the foreground cloud's size without changing
  the original ChemClaw shape or orange line; keep adaptive and raster paths
  consistent. Generated PNGs must be rebuilt before APK packaging.
- Default built-in **deepy-whale**: a reversible runtime red/blue channel swap
  creates a warm orange appearance in Flutter chat **and** native Android pet
  overlay. Other pet packs retain their original appearance and animations.
  Do not strip upstream author/source/license information.
- First connection and model-provider screens recommend APIHub and ChemCloud data MCP through the
  existing configured-credentials flow. Official DeepSeek sign-in and generic
  API-key connection remain available.
- Task list keeps its existing Host-backed schedule creation, editor, history,
  manual run and deletion, with a small-screen advisory about host availability
  and Android battery restrictions.
- The mobile Bot/group-chat page gets a ChemClaw-facing title; its underlying
  plugin API remains DS Bot-compatible and must be tested against ChemClaw desktop.

## Required before public release

- **Asset rights:** verify the upstream DSH-TUI pet and all other restricted art
  under ASSETS.md and original author permissions. Brand recoloring does not
  grant redistribution or trademark rights.
- **Device acceptance:** check icon at 48dp across Pixel/Xiaomi/Oppo launchers;
  golden images alone cannot validate actual optical centering.
- **Schedule reliability:** on a phone-local Host, test background execution,
  reboot, battery optimization, process death, timezone and DST; on a remote
  Host, verify continuation while the phone is off and notification delivery
  after reconnect. Do not claim OS-exact alarms or guaranteed execution.
- **Task integrity:** regression-test create/edit/disable/delete/manual-run,
  next run display and history without changing schedule IDs or Host storage.
- **Connection:** validate live APIHub model discovery, credential isolation
  per Host, ChemCloud MCP authorization and spot-vs-futures attribution.
- **Desktop parity:** inventory ChemClaw desktop Skills, Bots, group chats,
  GenUI and Office with explicit compatibility checks. A Fork of DSH Go does
  not automatically inherit the desktop Bot/group-chat architecture.
- **UI:** visually inspect Paper contrast, smaller screen layouts, icon and
  pet pose quality; compare expected screenshots before updating goldens.

This remains a development test APK; CI and legal/visual acceptance are required
before a branded public release.

## Verified compatibility and CI audit · November 4, 2026

- The mobile native Bot client expects DS Bot mobile protocol v1: POST
  `/api/bot` with `hello` and `room-chat`, plus an SSE feed. Desktop
  `chemclaw-bot` uses the same HTTP route but lacks those mobile endpoints;
  sharing the URL alone does not provide native compatibility. Do not install
  upstream `ds-bot` to access existing ChemClaw desktop Bot/group data: it
  uses a separate state store. Until a verified adapter exists, open the
  active Host's DSH web client as a fallback, without claiming native sync.
- Android JVM launcher test now checks generated ChemClaw PNG fallback assets
  and their signatures instead of prohibiting the intended new rasters.
- The launch test renderer accepts Paper's flat colour background (previous
  two-stop-only gradient construction crashed).
- Rebranded native entry points use the project's AppIcons roles, while the
  renderer still uses the original Pet animation frames and tests RGB channel
  conversion without removing nearest-neighbour integrity assertions.
- Schedule list offers a direct path to the Android background settings on
  a local Host; no new scheduler is created. A remote Host remains responsible
  for tasks hosted remotely.
- Classic web container titles are rebranded; its embedded upstream web client
  still needs separate, tested Paper/brand styling. This commit does not claim
  that the entire embedded DSH user interface has been reskinned.
- Multiple legacy Flutter update tests and other UI assertions remain outside
  this patch. Do not turn them off or release publicly without triage.

## Desktop ChemClaw team detection (no data duplication)

The mobile DS Bot client requires the v1 native hello/room-chat API, but
ChemClaw desktop v0.3.0 ships the older `/api/bot` state endpoint without
that handshake. When hello returns `bot/not-found`, the mobile app performs
one authenticated, read-only `state` probe. A ChemClaw-specific state shape
(bots, rooms, mainBotIds, workspaceId and capability library array) is used
to show real Bot, group and skill counts with a Web fallback on the **same
active Host**. It does **not** install `ds-bot`, copy secrets or create a
new team. Legacy DS Bot without a capability library stays on its existing
update/install path. All network errors remain best-effort fallback and
reconnect resets the state. Native desktop parity requires an explicit
versioned compatibility adapter; this read-only probe does not provide it.
