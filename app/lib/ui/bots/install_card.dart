// Explains the required mobile capability and offers the authenticated Web UI
// when the host has no usable mobile API. Missing plugins can also be installed.

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

/// ChemClaw setup/compatibility state. Never installs the unrelated ds-bot
/// package: doing that would create a different team with none of the built-in
/// ChemClaw experts, expert groups, or industry skills.
class DsBotInstallCard extends ConsumerWidget {
  const DsBotInstallCard({super.key, required this.status});
  final DsBotStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final english = AppLocale.isEnglish;
    final desktop = status.desktopTeam;
    final title = desktop != null
        ? (english ? 'ChemClaw experts available' : '已连接 ChemClaw 专家团队')
        : (english ? 'Connect to ChemClaw' : '连接 ChemClaw 专家团队');
    final message = desktop != null
        ? (english
            ? 'The selected ChemClaw host provides the expert roster. Expert chats use its authenticated API; groups and advanced cards still need mobile protocol support.'
            : '当前 ChemClaw 主机提供专家、专家群与技能。专家私聊直接使用主机接口；群聊完整消息与高级卡片仍需进一步适配。')
        : (english
            ? 'Select a DSH host running ChemClaw, not generic DS Bot. The ChemClaw specialists and their skills are managed by that host; installing DS Bot would create a separate, unrelated team.'
            : '请切换到已运行 ChemClaw 的主机。化工专家、专家群和专业技能由 ChemClaw 管理；安装通用 DS-Bot 会创建另一套不相关的团队。');
    return EmptyView(
      icon: AppIcons.bot,
      title: title,
      message: message,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      action: Column(mainAxisSize: MainAxisSize.min, children: [
        if (desktop != null) ...[
          FilledButton.icon(
            key: const ValueKey('dsbot-open-web'),
            onPressed: () => ref.read(dsBotWebOpenerProvider)(context, ref),
            icon: const Icon(AppIcons.webApp, size: 18),
            label: Text(english ? 'Open ChemClaw Web' : '打开 ChemClaw 网页版'),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          key: const ValueKey('dsbot-recheck-mobile'),
          onPressed: () => ref.read(dsBotProvider.notifier).retry(),
          child: Text(english ? 'Check connection again' : '重新检测主机'),
        ),
      ]),
    );
  }
}
