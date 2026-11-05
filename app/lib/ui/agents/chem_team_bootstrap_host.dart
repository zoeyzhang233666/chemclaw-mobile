// One-time local-host bootstrap of DeepSeek's official Agent Teams profile.
// Never reenable after the user has disabled it; never touch a remote host.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/agents_state.dart';
import '../../state/plugins_state.dart';

const chemTeamBootstrapPreference = 'chemclaw.official-team.bootstrap.v1';
const chemTeamOfficialSpec = '@deepseek-ai/dsh-experimental-agent-team-profile@0.2.1-rc.4';

enum ChemTeamBootstrapAction { skip, install, enable, remember }

ChemTeamBootstrapAction chemTeamBootstrapPlan({
  required bool local,
  required bool writable,
  required bool safeMode,
  required bool seen,
  required bool installed,
  required bool enabled,
}) {
  if (!local || !writable || safeMode || seen) return ChemTeamBootstrapAction.skip;
  if (!installed) return ChemTeamBootstrapAction.install;
  return enabled ? ChemTeamBootstrapAction.remember : ChemTeamBootstrapAction.enable;
}

/// An invisible host inside the phone home shell. Plugin install is queued only
/// once at a time and uses the same host permission safeguards as the plugin page.
class ChemTeamBootstrapHost extends ConsumerStatefulWidget {
  const ChemTeamBootstrapHost({super.key});
  @override
  ConsumerState<ChemTeamBootstrapHost> createState() => _ChemTeamBootstrapHostState();
}

class _ChemTeamBootstrapHostState extends ConsumerState<ChemTeamBootstrapHost> {
  bool _working = false;
  bool _attempted = false;
  Future<void> _setup() async {
    if (_working || _attempted || !mounted) return;
    _working = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final seen = prefs.getBool(chemTeamBootstrapPreference) ?? false;
      final host = ref.read(pluginHostProvider);
      final bundles = ref.read(installedPluginsProvider).value;
      if (bundles == null || host == null) return;
      final row = bundles.where((b) => b.name == agentTeamBundle).firstOrNull;
      final action = chemTeamBootstrapPlan(
        local: host.isLocal, writable: row == null ? host.canInstall : row.readOnlyReason == null,
        safeMode: ref.read(localSafeModeProvider), seen: seen,
        installed: row != null, enabled: row?.enabled ?? false,
      );
      if (action == ChemTeamBootstrapAction.skip) return;
      _attempted = true;
      bool success = false;
      switch (action) {
        case ChemTeamBootstrapAction.install:
          final job = await ref.read(pluginInstallsProvider.notifier).install(
            const PluginInstallRequest(
              name: agentTeamBundle, spec: chemTeamOfficialSpec, title: '化工专家团',
            ),
          );
          success = job.phase == PluginInstallPhase.succeeded;
          break;
        case ChemTeamBootstrapAction.enable:
          final result = await ref.read(installedPluginsProvider.notifier).setEnabled(row!, true);
          success = result.succeeded;
          break;
        case ChemTeamBootstrapAction.remember:
          success = true;
          break;
        case ChemTeamBootstrapAction.skip:
          break;
      }
      if (success) await prefs.setBool(chemTeamBootstrapPreference, true);
      // A plugin may require a safe engine restart to activate. Do not restart
      // automatically while the user is chatting; the plugin page offers it.
    } catch (_) {
      // The expert-team page can retry explicitly if a host is offline or
      // plugin installation is unavailable. Other app features must still start.
    } finally { _working = false; }
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(pluginHostProvider);
    final list = ref.watch(installedPluginsProvider);
    if (host != null && host.isLocal && list.hasValue && list.value != null && !_attempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) unawaited(_setup()); });
    }
    return const SizedBox.shrink();
  }
}
