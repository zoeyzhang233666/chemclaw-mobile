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
- DSH's native **Agent Teams** remains accessible under All Features → Agent Teams. The separate mobile ChemClaw expert/group roster has been retired.

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
- **Desktop parity:** audit industry Skills, GenUI and Office support on Android.
  Do not attempt to recreate desktop ChemClaw's Bot/group-chat architecture
  in this mobile project; DSH Agent Teams is the supported mobile workflow.
- **UI:** visually inspect Paper contrast, smaller screen layouts, icon and
  pet pose quality; compare expected screenshots before updating goldens.

This remains a development test APK; CI and legal/visual acceptance are required
before a branded public release.

## Product decision · November 4, 2026

The separate mobile **chemical experts, expert groups, and ChemClaw Bot**
feature has been removed at the user's request. Mobile users should use
DSH's already available **Agent Teams** plugin instead.

Implementation:
- Removed the `chemclaw-team` card from All Features and its custom
  native expert chat page, ChemClaw roster mapping, and group listing.
- Removed the separate Bot drawer entry and the always-on Bot feed/notification
  bridge. Previously owned DSH sessions remain visible in the ordinary
  session list; user data and desktop ChemClaw are left unchanged.
- Kept the DSH `agent-team` feature and `TeamPage`, along with MCP,
  schedules, models, Paper theme, launcher, and pet customizations.
- Some upstream generic Bot compatibility source remains unexposed to avoid
  destabilizing the underlying DSH Go libraries and tests; it is **not** a
  ChemClaw Mobile product feature and does not create or install another team.
- ARM64 rootfs downloads still require pinned SHA256 checks and trusted
  signed package-index verification.

This is a development branch. Flutter/Android CI, phone acceptance, licence
checks and visual references must pass before public distribution.
