// 「联网搜索」, after `dsh-client-ui-settings-web-search`: the switch between
// DeepSeek Messages search (`web-search-deepseek`) and the Search / Fetch
// APIs (`web-deepseek-api`), which writes both provider selections of `web`
// together; then the selected API's key, endpoint and per-search limit. The
// key goes to the credential the selected section names.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/engine_settings_state.dart';
import '../../state/providers_state.dart';
import '../theme/theme.dart';
import 'field_row.dart';
import 'namespace_copy.dart';
import 'schema_form.dart';

/// Provider ids the switch writes, by `web` field and position.
const webSearchProviders = {
  'searchProvider': (api: 'deepseek-search-api', messages: 'deepseek-official'),
  'fetchProvider': (api: 'deepseek-fetch-api', messages: 'http'),
};

/// The `web` edits for one switch position: a target equal to the composed
/// value clears the override instead of storing a copy of it.
List<SettingsOp> webSearchSwitchOps(SettingsNamespaceView web, {required bool api}) => [
  for (final MapEntry(:key, :value) in webSearchProviders.entries)
    if (lookupPath(web.base, [key]).$2 == (api ? value.api : value.messages))
      SettingsOp.unset([key])
    else
      SettingsOp.set([key], api ? value.api : value.messages),
];

class WebSearchSettingsPage extends ConsumerWidget {
  const WebSearchSettingsPage({super.key});

  static const messagesNs = 'web-search-deepseek';
  static const apiNs = 'web-deepseek-api';
  static const webNs = 'web';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return EngineFormScaffold(
      title: l10n.engineSearchTitle,
      namespaces: const [messagesNs],
      builder: (context, settings) {
        final switchable = settings.served(webNs) && settings.served(apiNs);
        final api = switchable && settings.valueOf(const FieldRef(webNs, ['searchProvider'])) == 'deepseek-search-api';
        final selected = settings.valueOf(const FieldRef(webNs, ['searchProvider']))?.toString() ?? 'auto';
        final chemclaw = selected == 'auto' || selected.startsWith('chemclaw-');
        final ns = api ? apiNs : messagesNs;
        SchemaFieldSpec field(String key) => SchemaFieldSpec(
          ns,
          [key],
          copy: copyOf(ns, [key]),
          keyboardType: key == 'baseURL' ? TextInputType.url : null,
        );
        return schemaFormGroups([
          if (settings.served(webNs))
            SchemaFormSection(
              title: AppLocale.isEnglish ? 'Search provider' : '联网搜索来源',
              children: [_ChemClawSearchPicker(settings: settings, selected: selected)],
            ),
          if (!chemclaw && switchable)
            SchemaFormSection(children: [_ApiSwitch(settings: settings, api: api)]),
          if (!chemclaw)
            SchemaFormSection(
              title: l10n.engineSearchDeepSeek,
              fields: [field('apiKey'), field('baseURL'), field(api ? 'count' : 'maxUses')],
            ),
          if (selected.startsWith('chemclaw-'))
            SchemaFormSection(
              title: AppLocale.isEnglish ? 'Search API credential' : '搜索 API 密钥',
              children: [_ThirdPartySearchKey(key: ValueKey(selected), id: selected)],
            ),
          if (selected == 'auto')
            SchemaFormSection(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(AppLocale.isEnglish
                    ? 'Tries supported search tools on the current model route, then falls back to Bing or DuckDuckGo. No DeepSeek login required.'
                    : '先尝试当前模型渠道支持的搜索能力，失败后使用 Bing 或 DuckDuckGo 网页搜索。无需登录 DeepSeek 账号。'),
              ),
            ]),
        ], settings: settings);
      },
    );
  }
}

class _ApiSwitch extends ConsumerWidget {
  const _ApiSwitch({required this.settings, required this.api});

  final EngineSettings settings;
  final bool api;

  static const _fields = [
    FieldRef(WebSearchSettingsPage.webNs, ['searchProvider']),
    FieldRef(WebSearchSettingsPage.webNs, ['fetchProvider']),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = DshColors.of(context);
    final web = settings[WebSearchSettingsPage.webNs]!;
    final saving = _fields.any(settings.isSaving);
    final error = _fields.map(settings.errorOf).nonNulls.firstOrNull;
    final enabled = settings.canWrite(WebSearchSettingsPage.webNs) && !saving;
    final layer = settings.layerOf(_fields.first);
    void toggle(bool on) {
      for (final f in _fields) {
        ref.read(engineSettingsProvider.notifier).clearError(f);
      }
      unawaited(
        ref
            .read(engineSettingsProvider.notifier)
            .write(WebSearchSettingsPage.webNs, webSearchSwitchOps(web, api: on), fields: _fields),
      );
    }

    return MergeSemantics(
      child: EngineFieldRow(
        title: l10n.engineSearchNewApi,
        subtitle: error ?? (layer == FieldLayer.locked ? lockedHint : null),
        subtitleColor: error != null ? colors.danger : null,
        badge: layer == FieldLayer.user && enabled ? modifiedBadge : null,
        enabled: enabled,
        onTap: enabled ? () => toggle(!api) : null,
        trailing: Switch(value: api, onChanged: enabled ? toggle : null),
      ),
    );
  }
}


/// Stable ids registered by the bundled DSH web plugins, not model provider ids.
const chemclawSearchChoices = <String>[
  'auto', 'chemclaw-brave', 'chemclaw-tavily', 'chemclaw-serper',
  'deepseek-official', 'deepseek-search-api',
];

String chemclawSearchLabel(String id) => switch (id) {
  'auto' => AppLocale.isEnglish ? 'Automatic (recommended)' : '自动搜索（推荐）',
  'chemclaw-brave' => 'Brave Search API',
  'chemclaw-tavily' => 'Tavily Search API',
  'chemclaw-serper' => 'Serper Google Search',
  'deepseek-official' => AppLocale.isEnglish ? 'DeepSeek Messages' : 'DeepSeek 官方搜索',
  'deepseek-search-api' => 'DeepSeek Search API',
  _ => id,
};

String? chemclawSearchCredential(String id) => switch (id) {
  'chemclaw-brave' => 'BRAVE_SEARCH_API_KEY',
  'chemclaw-tavily' => 'TAVILY_API_KEY',
  'chemclaw-serper' => 'SERPER_API_KEY',
  _ => null,
};

class _ChemClawSearchPicker extends ConsumerWidget {
  const _ChemClawSearchPicker({required this.settings, required this.selected});
  final EngineSettings settings;
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const ns = WebSearchSettingsPage.webNs;
    const fields = [FieldRef(ns, ['searchProvider']), FieldRef(ns, ['fetchProvider'])];
    final enabled = settings.canWrite(ns) && !fields.any(settings.isSaving);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in chemclawSearchChoices)
            ChoiceChip(
              label: Text(chemclawSearchLabel(id)),
              selected: selected == id,
              onSelected: !enabled ? null : (_) {
                final notifier = ref.read(engineSettingsProvider.notifier);
                for (final f in fields) { notifier.clearError(f); }
                unawaited(notifier.write(ns, [
                  SettingsOp.set(['searchProvider'], id),
                  SettingsOp.set(['fetchProvider'], 'http'),
                ], fields: fields));
              },
            ),
        ],
      ),
    );
  }
}

class _ThirdPartySearchKey extends ConsumerStatefulWidget {
  const _ThirdPartySearchKey({super.key, required this.id});
  final String id;
  @override
  ConsumerState<_ThirdPartySearchKey> createState() => _ThirdPartySearchKeyState();
}
class _ThirdPartySearchKeyState extends ConsumerState<_ThirdPartySearchKey> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy) return;
    final keyRef = chemclawSearchCredential(widget.id);
    final backend = ref.read(providerBackendProvider);
    if (keyRef == null || backend == null) {
      setState(() => _message = AppLocale.isEnglish ? 'Connect a DSH host first' : '请先连接 DSH 主机');
      return;
    }
    final key = _controller.text.trim();
    if (key.isEmpty || key.length > 1024 || !RegExp(r'^[\x21-\x7E]+$').hasMatch(key)) {
      setState(() => _message = AppLocale.isEnglish ? 'Paste a valid API key' : '请粘贴有效的 API 密钥');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await backend.storeKey(keyRef, key);
      _controller.clear();
      if (mounted) {
        setState(() => _message = AppLocale.isEnglish
          ? 'Saved to the connected DSH host credentials. Try a web search to verify.'
          : '密钥已保存到当前 DSH 主机的凭据库，请在对话中试一次联网搜索。');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = AppLocale.isEnglish
          ? 'Could not save the key. Check host permissions and connection.'
          : '保存失败，请检查当前主机的权限和连接状态。');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: chemclawSearchCredential(widget.id),
            helperText: AppLocale.isEnglish ? 'Key stays on your chosen DSH host' : '密钥仅保存到当前 DSH 主机',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? (AppLocale.isEnglish ? 'Saving…' : '保存中…') : (AppLocale.isEnglish ? 'Save API key' : '保存搜索密钥')),
        ),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
      ],
    ),
  );
}
