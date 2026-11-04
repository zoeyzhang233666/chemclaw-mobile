// Bot 首页: the DS Bot team of the active
// host. Main Bots pinned first, the other Bots by latest activity, then the
// group chats; each row says who it is, what it said or does, and whether
// something is unread. Without a usable DS Bot, the install card.

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/bots_state.dart';
import '../common/list_page_row.dart';
import '../features/feature_kit.dart';
import '../features/feature_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'bot_avatar.dart';
import 'bot_chat_page.dart';
import 'chemclaw_expert_chat_page.dart';
import 'bot_format.dart';
import 'install_card.dart';
import 'new_bot_page.dart';
import 'new_room_sheet.dart';
import 'room_chat_page.dart';

class BotsPage extends ConsumerWidget {
  const BotsPage({super.key, this.chemclawOnly = false});

  /// The ChemClaw feature entry must never rebrand a generic DS Bot team.
  final bool chemclawOnly;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const BotsPage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(dsBotProvider);
    final team = status.team;
    return AppPage.list(
      // UI is ChemClaw-branded; installed Host plugin compatibility is checked
      // separately. Do not misrepresent an absent DS Bot-compatible service.
      title: 'ChemClaw · Bot 与群聊',
      subtitle: Text(_summary(status)),
      children: [
        if (status.ready && team != null && !chemclawOnly)
          _Team(status: status, team: team)
        else if (status.desktopTeam case final desktop?)
          _DesktopRoster(status: status, desktop: desktop)
        else if (chemclawOnly)
          DsBotInstallCard(status: status)
        else
          switch (status.availability) {
            DsBotAvailability.offline => const FeatureOffline(),
            DsBotAvailability.relay => FeatureMessage(
              icon: AppIcons.disconnected,
              title: l10n.botsRelayUnavailable,
              body: l10n.botsUseSsh,
            ),
            DsBotAvailability.missing || DsBotAvailability.outdated => DsBotInstallCard(status: status),
            DsBotAvailability.failed => FeatureMessage(
              icon: AppIcons.error,
              title: l10n.botsTeamLoadFailed,
              body: status.error,
              action: (l10n.commonRetry, () => ref.read(dsBotProvider.notifier).retry()),
            ),
            _ => const QuietSpinner(),
          },
      ],
    );
  }
}

/// 「本机 · 4 个 Bot · 2 个群聊」.
String _summary(DsBotStatus status) {
  final team = status.team;
  if (!status.ready || team == null) return status.hostLabel;
  return [
    status.hostLabel,
    appL10n.botsBotCount(team.bots.length),
    if (team.rooms.isNotEmpty) appL10n.botsRoomCount(team.rooms.length),
  ].join(' · ');
}

/// Live inventory of the *connected Host's* desktop ChemClaw team.
/// Read-only by design: this is the real roster, not locally cloned Bots.
class _DesktopRoster extends ConsumerStatefulWidget {
  const _DesktopRoster({required this.status, required this.desktop});

  final DsBotStatus status;
  final ChemClawDesktopTeam desktop;

  @override
  ConsumerState<_DesktopRoster> createState() => _DesktopRosterState();
}

class _DesktopRosterState extends ConsumerState<_DesktopRoster> {
  String query = '';
  bool allExperts = false;
  bool allSkills = false;

  @override
  Widget build(BuildContext context) {
    final desktop = widget.desktop;
    final english = AppLocale.isEnglish;
    final theme = Theme.of(context);
    final q = query.trim().toLowerCase();
    bool hit(String text) => q.isEmpty || text.toLowerCase().contains(q);
    final experts = desktop.expertItems
        .where((e) => hit([e.name, e.role, ...e.skills].join(' ')))
        .toList();
    final groups = desktop.groupItems
        .where((e) => hit([e.name, e.admin ?? '', ...e.members].join(' ')))
        .toList();
    final skills = desktop.skillItems.where(hit).toList();
    final shownExperts = q.isNotEmpty || allExperts ? experts : experts.take(12).toList();
    final shownSkills = q.isNotEmpty || allSkills ? skills : skills.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? 'ChemClaw expert team' : 'ChemClaw 专家团队',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    english
                        ? '${desktop.bots} Bots · ${desktop.rooms} groups · ${desktop.skills} skills'
                        : '${desktop.bots} 位专家 · ${desktop.rooms} 个专家群 · ${desktop.skills} 项专业技能',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    english
                        ? 'From the connected Host: ${widget.status.hostLabel}. Skills and permissions stay on that Host. Open Web to chat with these experts until native mobile protocol support is verified.'
                        : '来自当前主机：${widget.status.hostLabel}。专家关联的 Skill、MCP 与权限保留在该主机。原生消息协议适配完成前，请通过网页版与这些专家对话。',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('dsbot-open-web'),
                      onPressed: () => ref.read(dsBotWebOpenerProvider)(context, ref),
                      icon: const Icon(AppIcons.webApp, size: 18),
                      label: Text(english ? 'Open ChemClaw Web' : '打开 ChemClaw 网页版'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            key: const ValueKey('chemclaw-roster-search'),
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: english ? 'Find an expert, group or skill' : '搜索专家、群聊或技能',
            ),
          ),
        ),
        if (experts.isNotEmpty)
          ListPageCard(
            title: english ? 'Experts (${experts.length})' : '专家（${experts.length}）',
            children: [
              for (final expert in shownExperts)
                ListPageRow(
                  icon: AppIcons.bot,
                  title: expert.name,
                  subtitle: expert.skills.isNotEmpty
                      ? (english ? 'Skills: ' : '关联技能：') + expert.skills.join('、')
                      : expert.role.isNotEmpty ? expert.role : null,
                  subtitleMaxLines: 2,
                  chevron: expert.id.isNotEmpty,
                  onTap: expert.id.isEmpty ? null : () => Navigator.of(context).push(
                    ChemClawExpertChatPage.route(id: expert.id, name: expert.name, role: expert.role),
                  ),
                ),
              if (shownExperts.length < experts.length)
                ListPageRow(
                  icon: AppIcons.expand,
                  title: english ? 'Show all experts' : '查看全部专家',
                  onTap: () => setState(() => allExperts = true),
                ),
            ],
          ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListPageCard(
            title: english ? 'Groups (${groups.length})' : '专家群（${groups.length}）',
            children: [
              for (final group in groups)
                ListPageRow(
                  icon: AppIcons.newGroupChat,
                  title: group.name,
                  subtitle: group.members.join('、'),
                  subtitleMaxLines: 2,
                  chevron: true,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(group.name, style: Theme.of(sheetContext).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          if (group.admin != null) Text(english ? 'Admin: ${group.admin}' : '管理员：${group.admin}'),
                          Text(english ? 'Members: ${group.members.join(', ')}' : '成员：${group.members.join('、')}'),
                          const SizedBox(height: 12),
                          Text(english
                              ? 'This is the live ChemClaw group roster. Full group turns and rich tool cards remain in the connected ChemClaw Host.'
                              : '这里展示当前 ChemClaw 主机真实的专家群。完整群聊消息、任务过程与交互卡片仍由原主机提供。'),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              ref.read(dsBotWebOpenerProvider)(context, ref);
                            },
                            icon: const Icon(AppIcons.webApp),
                            label: Text(english ? 'Open ChemClaw group in Web' : '在 ChemClaw 网页版查看群聊'),
                          )),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListPageCard(
            title: english ? 'Skill library (${skills.length})' : '专业技能（${skills.length}）',
            children: [
              for (final name in shownSkills)
                ListPageRow(icon: AppIcons.skill, title: name, chevron: false),
              if (shownSkills.length < skills.length)
                ListPageRow(
                  icon: AppIcons.expand,
                  title: english ? 'Show all skills' : '查看全部技能',
                  onTap: () => setState(() => allSkills = true),
                ),
            ],
          ),
        ],
        if (experts.isEmpty && groups.isEmpty && skills.isEmpty)
          FeatureNote(english ? 'No matching experts, groups or skills.' : '未找到匹配的专家、群聊或技能。'),
      ],
    );
  }
}

class _Team extends ConsumerWidget {
  const _Team({required this.status, required this.team});

  final DsBotStatus status;
  final DsBotTeam team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final inbox = ref.watch(dsBotInboxProvider);
    final readOnly = status.readOnly != null;
    DateTime? latest(String id) => inbox.latest[id]?.time;
    int newest(DateTime? a, DateTime? b) => (b ?? DateTime(0)).compareTo(a ?? DateTime(0));
    final mains = [for (final id in team.mainBotIds) ?team.bot(id)];
    final others = [
      for (final bot in team.bots)
        if (!team.isMain(bot.id)) bot,
    ]..sort((a, b) => newest(latest(a.id) ?? a.createdAt, latest(b.id) ?? b.createdAt));
    final rooms = [...team.rooms]..sort((a, b) => newest(latest(a.id) ?? a.createdAt, latest(b.id) ?? b.createdAt));
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListPageCard(
          title: 'Bot',
          children: [
            for (final bot in [...mains, ...others])
              FadeSlideIn(
                index: index++,
                child: BotRow(bot: bot, team: team, live: status.live, inbox: inbox),
              ),
            ListPageRow(
              icon: AppIcons.add,
              title: l10n.botsNewBot,
              leadingWidth: 40,
              chevron: false,
              onTap: readOnly ? null : () => Navigator.of(context).push(NewBotPage.route()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListPageCard(
          title: l10n.botsGroupChat,
          children: [
            for (final room in rooms)
              FadeSlideIn(
                index: index++,
                child: RoomRow(room: room, team: team, live: status.live, inbox: inbox),
              ),
            ListPageRow(
              icon: AppIcons.newGroupChat,
              title: l10n.botsNewGroup,
              leadingWidth: 40,
              chevron: false,
              onTap: readOnly || team.bots.length < 2 ? null : () => showNewRoomSheet(context),
            ),
          ],
        ),
        if (readOnly) FeatureNote('${status.readOnly}'),
      ],
    );
  }
}

/// A Bot: avatar (with a dot while it works), name with a 「主」 tag, its last
/// words or what it is doing, the time and an unread count.
class BotRow extends StatelessWidget {
  const BotRow({super.key, required this.bot, required this.team, required this.live, required this.inbox});

  final DsBot bot;
  final DsBotTeam team;
  final DsBotLive live;
  final DsBotInbox inbox;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final work = live.bots[bot.id];
    final doing = workPhrase(work, activity: live.activity[bot.id]);
    final notice = inbox.latest[bot.id];
    final unread = inbox.unreadOf(bot.id);
    final question = team.questionOf(bot) != null || team.viewOf(bot) != null;
    final String subtitle;
    Color? subtitleColor;
    if (doing != null) {
      final room = team.room(work?.roomId);
      subtitle = room == null ? doing : '$doing · ${room.name}';
      subtitleColor = DshColors.of(context).info;
    } else if (question) {
      subtitle = l10n.commonWaitingAnswer;
      subtitleColor = DshColors.of(context).warning;
    } else if (bot.waiting) {
      subtitle = l10n.botsChooseModelStart;
      subtitleColor = DshColors.of(context).warning;
    } else if (notice != null && notice.roomId == null && notice.text.isNotEmpty) {
      subtitle = notice.text;
    } else {
      subtitle = bot.role.isEmpty ? l10n.botsNoChats : bot.role;
    }
    void open() => Navigator.of(context).push(BotChatPage.route(bot.id));
    return Semantics(
      button: true,
      onTap: open,
      label: [
        bot.name,
        if (team.isMain(bot.id)) l10n.botsMainBot,
        subtitle,
        if (unread > 0) l10n.botsUnreadCount(unread),
      ].join(l10n.botsListSeparator),
      excludeSemantics: true,
      child: ListPageRow(
        leading: BotAvatar(bot: bot, size: 40, working: work != null),
        leadingWidth: 40,
        title: bot.name,
        badge: team.isMain(bot.id) ? BotTag(l10n.botsMainTag) : null,
        subtitle: subtitle,
        subtitleColor: subtitleColor,
        meta: notice == null ? null : shortTime(notice.time),
        trailing: unread > 0 ? UnreadBadge(unread) : null,
        chevron: false,
        onTap: open,
      ),
    );
  }
}

/// A group chat: members stacked, its name, the last line or who works.
class RoomRow extends StatelessWidget {
  const RoomRow({super.key, required this.room, required this.team, required this.live, required this.inbox});

  final DsBotRoom room;
  final DsBotTeam team;
  final DsBotLive live;
  final DsBotInbox inbox;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final working = live.rooms[room.id] ?? const <DsBotWork>[];
    final notice = inbox.latest[room.id];
    final unread = inbox.unreadOf(room.id);
    final waiting = live.approvals.any((a) => a.roomId == room.id && a.answerable);
    final String subtitle;
    Color? subtitleColor;
    if (waiting) {
      subtitle = l10n.botsMemberNeedsApproval;
      subtitleColor = DshColors.of(context).warning;
    } else if (working.isNotEmpty) {
      final names = [for (final w in working) team.bot(w.botId)?.name ?? 'Bot'];
      subtitle = names.length == 1
          ? l10n.botsNamedWorking(names.first)
          : l10n.botsNamesWorking(names.take(2).join(l10n.botsNameSeparator));
      subtitleColor = DshColors.of(context).info;
    } else {
      final preview = roomPreview(room, team);
      subtitle = preview.isEmpty ? l10n.botsMemberCount(room.members.length) : preview;
    }
    void open() => Navigator.of(context).push(RoomChatPage.route(room.id));
    return Semantics(
      button: true,
      onTap: open,
      label: [room.name, subtitle, if (unread > 0) l10n.botsUnreadCount(unread)].join(l10n.botsListSeparator),
      excludeSemantics: true,
      child: ListPageRow(
        leading: RoomAvatar(room: room, team: team, size: 40),
        leadingWidth: 40,
        title: room.name,
        subtitle: subtitle,
        subtitleColor: subtitleColor,
        meta: notice == null ? null : shortTime(notice.time),
        trailing: unread > 0 ? UnreadBadge(unread) : null,
        chevron: false,
        onTap: open,
      ),
    );
  }
}

/// Count of unread messages: a primary capsule, round for one digit.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key});

  final int count;

  static const height = 20.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: height, minHeight: height, maxHeight: height),
      child: DecoratedBox(
        decoration: ShapeDecoration(color: scheme.primary, shape: const StadiumBorder()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              count > 99 ? '99+' : '$count',
              textScaler: TextScaler.noScaling,
              style: AppType.tabular(
                Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600, height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small quiet tag after a name (「主」「管理员」).
class BotTag extends StatelessWidget {
  const BotTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusXs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          style: theme.textTheme.labelSmall?.copyWith(color: dsh.textTertiary, height: 1.2),
        ),
      ),
    );
  }
}
