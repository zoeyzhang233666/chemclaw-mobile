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
