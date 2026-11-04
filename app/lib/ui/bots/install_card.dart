// Legacy generic Bot compatibility fallback; no ChemClaw expert/team installation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/bots_state.dart';
import '../common/empty_view.dart';
import '../theme/app_icons.dart';
import '../web/dsh_web_launcher.dart';
import '../web/web_target.dart';

/// Uses the existing authenticated DSH Web launcher. Tests replace only this edge.
final dsBotWebOpenerProvider = Provider<void Function(BuildContext context, WidgetRef ref)>(
  (ref) =>
      (context, ref) => openDshWeb(context, ref, target: const DshWebTarget(sidebar: true)),
);

/// The standalone Bot feature is not surfaced in ChemClaw Mobile.
/// Users should use DSH's built-in Agent Teams feature instead.
class DsBotInstallCard extends ConsumerWidget {
  const DsBotInstallCard({super.key, required this.status});
  final DsBotStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final english = AppLocale.isEnglish;
    return EmptyView(
      icon: AppIcons.bot,
      title: english ? 'Use Agent Teams' : '请使用智能体团队',
      message: english
          ? 'ChemClaw Mobile no longer provides a separate expert or group chat feature. Use All Features → Agent Teams for DSH team workflows.'
          : '手机版已取消独立的化工专家和专家群。请在「全部功能 → 智能体团队」中使用 DSH 原生团队协作。',
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      action: TextButton(
        key: const ValueKey('dsbot-recheck-mobile'),
        onPressed: () => ref.read(dsBotProvider.notifier).retry(),
        child: Text(english ? 'Check connection again' : '重新检测主机'),
      ),
    );
  }
}
