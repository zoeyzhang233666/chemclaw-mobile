// Native ChemClaw expert private chat against the existing desktop Host API.
// The source of truth is the selected ChemClaw Host: no cloned Bots, skills,
// model keys or MCP credentials are stored in the mobile client.
import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/bots_state.dart';
import 'install_card.dart';

class ChemClawExpertChatPage extends ConsumerStatefulWidget {
  const ChemClawExpertChatPage({
    super.key,
    required this.id,
    required this.name,
    this.role = '',
  });

  final String id;
  final String name;
  final String role;

  static Route<void> route({required String id, required String name, String role = ''}) =>
      MaterialPageRoute<void>(
        builder: (_) => ChemClawExpertChatPage(id: id, name: name, role: role),
      );

  @override
  ConsumerState<ChemClawExpertChatPage> createState() => _ChemClawExpertChatPageState();
}

class _ChemClawExpertChatPageState extends ConsumerState<ChemClawExpertChatPage> {
  final _composer = TextEditingController();
  Timer? _poll;
  List<DsBotItem> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Desktop ChemClaw exposes the actual 'chat' and 'send' endpoints, even
    // though it does not implement the unrelated DS Bot mobile hello/feed API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
      _poll = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) unawaited(_refresh());
      });
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final status = ref.read(dsBotProvider);
    final api = ref.read(dsBotProvider.notifier).api;
    if (status.desktopTeam == null || api == null) {
      setState(() {
        _loading = false;
        _error = '当前主机没有提供 ChemClaw 专家服务，请重新连接。';
      });
      return;
    }
    try {
      final page = await api.chat(widget.id);
      if (!mounted || ref.read(dsBotProvider.notifier).api != api) return;
      setState(() {
        _messages = page.items.where((item) => item.text.trim().isNotEmpty).toList();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || ref.read(dsBotProvider.notifier).api != api) return;
      setState(() {
        _loading = false;
        _error = '无法读取专家对话，请检查当前 ChemClaw 主机连接。';
      });
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final status = ref.read(dsBotProvider);
    final api = ref.read(dsBotProvider.notifier).api;
    if (text.isEmpty || _sending || api == null || status.desktopTeam == null ||
        status.readOnly != null) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.send(widget.id, text);
      if (!mounted || ref.read(dsBotProvider.notifier).api != api) return;
      _composer.clear();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = '发送失败，请确认专家是否可用；未确认前不会自动重复发送。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dsBotProvider);
    final connected = status.desktopTeam != null;
    final writable = connected && status.readOnly == null && !_sending;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (widget.role.isNotEmpty)
            Text(widget.role, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall),
        ],
      ), actions: [
        IconButton(
          icon: const Icon(Icons.open_in_browser),
          tooltip: '在 ChemClaw 网页版中查看完整交互',
          onPressed: () => ref.read(dsBotWebOpenerProvider)(context, ref),
        ),
      ]),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '已连接的 ChemClaw 专家 · 使用原主机的模型、技能、MCP 与权限。'
              '高级交互卡、图表和群聊仍请在原主机中查看。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (_error case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Text(message, style: TextStyle(color: theme.colorScheme.error))),
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: '重试读取'),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      key: const ValueKey('chemclaw-expert-messages'),
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        final own = item.kind == DsBotItemKind.user;
                        return Align(
                          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Card(
                              color: own ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(own ? '我' : widget.name, style: theme.textTheme.labelSmall),
                                    const SizedBox(height: 4),
                                    SelectableText(item.text),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (!connected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('请连接已运行 ChemClaw 的主机，不能通过安装通用 DS Bot 替代。'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chemclaw-expert-input'),
                  controller: _composer,
                  enabled: writable,
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(hintText: '向专家发送问题', border: OutlineInputBorder()),
                  onSubmitted: (_) => unawaited(_send()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const ValueKey('chemclaw-expert-send'),
                onPressed: writable ? _send : null,
                tooltip: '发送给 ChemClaw 专家',
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
