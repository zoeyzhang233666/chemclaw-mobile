import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/chemclaw_setup.dart';
import '../../state/connection_state.dart';
import '../../state/hosts_state.dart';
import '../../state/models_state.dart';
import '../../state/provider_keys.dart';
import '../../state/providers_state.dart';
import '../plugins/plugins_screen.dart';

/// Preconfigured ChemClaw services. Readiness comes from the active Host.
class ChemClawMcpPage extends ConsumerStatefulWidget {
  const ChemClawMcpPage({super.key});
  static const testPrompt =
      '请先确认当前主机是否已加载 chem-data-hub MCP 工具。'
      '如果可用，请通过 MCP 查询甲醇华东现货最近一个月价格，'
      '注明地区、日期、单位、价格口径和数据源。'
      '如果没有 MCP 工具或查询失败，请明确说明，'
      '不要用期货价格冒充现货，也不要编造价格。';

  @override
  ConsumerState<ChemClawMcpPage> createState() => _ChemClawMcpPageState();
}

class _ChemClawMcpPageState extends ConsumerState<ChemClawMcpPage> {
  final _apiKey = TextEditingController();
  final _hubKey = TextEditingController();
  bool _busyApi = false, _busyHub = false, _busyPublic = false;
  bool _hideApi = true, _hideHub = true;
  String? _apiMessage, _hubMessage;
  DshClient? _statusClient;
  Future<List<ChemClawConnectorStatus>?>? _statuses;

  @override
  void dispose() {
    _apiKey.dispose();
    _hubKey.dispose();
    super.dispose();
  }

  void _refresh(DshClient? client) {
    setState(() {
      _statusClient = client;
      _statuses = client?.listChemClawConnectors();
    });
  }

  void _note(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _paste(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final key = data?.text?.trim() ?? '';
    if (key.isEmpty) return;
    controller.value = TextEditingValue(text: key, selection: TextSelection.collapsed(offset: key.length));
  }

  Future<void> _openKeyPage(String url) async {
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) _note('已复制官方密钥页面网址');
  }

  Future<void> _saveApiHub() async {
    if (_busyApi) return;
    final backend = ref.read(providerBackendProvider);
    if (backend == null) { _note('请先连接 DSH 主机'); return; }
    setState(() { _busyApi = true; _apiMessage = null; });
    try {
      final result = await configureApiHub(
        backend, _apiKey.text,
        vault: backend.isLocal ? ref.read(providerKeyVaultProvider) : null,
      );
      _apiKey.clear();
      ref..invalidate(customProvidersProvider)..invalidate(modelCatalogProvider);
      if (mounted) setState(() => _apiMessage =
          '已安全保存 APIHub，自动发现并导入 ${result.models} 个聊天模型。'
          '请在聊天中选择 APIHub 模型并发送一次消息验证。');
    } catch (error) {
      if (mounted) setState(() => _apiMessage = error is FormatException || error is StateError
          ? error.toString().replaceFirst(RegExp(r'^(Bad state: |FormatException: )'), '')
          : 'APIHub 验证失败，请检查密钥、网络和服务状态');
    } finally {
      if (mounted) setState(() => _busyApi = false);
    }
  }

  Future<void> _connectHub() async {
    if (_busyHub) return;
    final client = ref.read(activeConnectionProvider).value?.client;
    if (client == null) { _note('请先连接 DSH 主机'); return; }
    setState(() { _busyHub = true; _hubMessage = null; });
    try {
      final services = await client.listChemClawConnectors();
      if (services == null || !services.any((s) => s.id == chemDataHubId)) {
        throw StateError('当前主机不支持 ChemClaw MCP 预置接口；本机模式请更新安装包');
      }
      final key = _hubKey.text.replaceAll(RegExp(r'\s'), '');
      if (key.isNotEmpty) {
        if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(key) ||
            RegExp(r'^[A-Z][A-Z0-9_]*=').hasMatch(key)) {
          throw const FormatException('请只粘贴数据中台密钥，不要包含空格或变量名');
        }
        await client.setProviderKey(key, ref: chemDataHubKeyRef);
        _hubKey.clear();
      } else {
        final stored = await client.describeCredentials([chemDataHubKeyRef]);
        if (stored[chemDataHubKeyRef]?.configured != true) {
          throw const FormatException('请先粘贴数据中台 MCP 密钥');
        }
      }
      final result = await client.connectChemClawMcp(chemDataHubId);
      if (mounted) {
        _refresh(client);
        setState(() => _hubMessage = result.ready
            ? '已挂载数据中台 MCP；请用下方测试问题验证现货工具实际返回。'
            : '凭据已保存，但 MCP 尚未就绪（${result.state}）。请检查密钥及网络并重试。');
      }
    } catch (error) {
      if (mounted) setState(() => _hubMessage = error is FormatException || error is StateError
          ? error.toString().replaceFirst(RegExp(r'^(Bad state: |FormatException: )'), '')
          : 'MCP 连接未确认成功，请检查当前主机、密钥和网络后重试');
    } finally {
      if (mounted) setState(() => _busyHub = false);
    }
  }

  Future<void> _connectPublic() async {
    if (_busyPublic) return;
    final client = ref.read(activeConnectionProvider).value?.client;
    if (client == null) return;
    setState(() => _busyPublic = true);
    try {
      final result = await client.connectChemClawMcp(huagongsheId);
      if (mounted) {
        _refresh(client);
        _note(result.ready ? '公开化学检索已就绪（只读）' : '化工社连接未就绪');
      }
    } catch (_) {
      if (mounted) _note('化工社查询暂不可用，请检查当前主机');
    } finally {
      if (mounted) setState(() => _busyPublic = false);
    }
  }

  Widget _keyField(TextEditingController controller, String label, bool hidden, VoidCallback toggle) =>
      TextField(
        controller: controller,
        obscureText: hidden,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.visiblePassword,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: hidden ? '显示密钥' : '隐藏密钥',
              icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: toggle,
            ),
            IconButton(
              tooltip: '从剪贴板粘贴',
              icon: const Icon(Icons.content_paste),
              onPressed: () => _paste(controller),
            ),
          ]),
        ),
      );

  Widget _card(String title, String description, String endpoint, Widget content) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(description),
        const SizedBox(height: 8),
        SelectableText(endpoint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 15),
        content,
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(activeHostProvider);
    final backend = ref.watch(providerBackendProvider);
    final client = ref.watch(activeConnectionProvider).value?.client;
    final snap = ref.watch(customProvidersProvider).value;
    final apihub = snap?.byId(apiHubRouteId);
    final configured = apihub != null && snap?.healthOf(apihub) == ProviderHealth.ready;
    if (!identical(_statusClient, client)) {
      _statusClient = client;
      _statuses = client?.listChemClawConnectors();
    }
    final busy = _busyApi || _busyHub || _busyPublic;
    return Scaffold(
      appBar: AppBar(title: const Text('ChemClaw 服务连接')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('当前主机：${host.isLocal ? '本机 DSH 引擎' : '远程 DSH 主机'}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('APIHub 和数据中台的地址与协议都已预置。'
            '模型 API Key 与数据中台 MCP 密钥分别授权，需各粘贴一次。'
            '密钥不会随 APK 发布。'),
        const SizedBox(height: 16),
        _card('APIHub · 模型服务',
            configured ? '已在当前主机注册 APIHub 模型渠道' : '自动验证密钥，读取可用模型并创建模型渠道',
            apiHubBaseUrl,
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _keyField(_apiKey, '粘贴 APIHub 密钥', _hideApi, () => setState(() => _hideApi = !_hideApi)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy || backend == null ? null : _saveApiHub,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_busyApi ? '正在获取模型…' : '验证并保存 APIHub'),
              ),
              TextButton(onPressed: () => _openKeyPage(apiHubKeysUrl), child: const Text('获取 APIHub 密钥')),
              if (_apiMessage != null) Text(_apiMessage!),
            ]),
        ),
        _card('芯化和云数据中台 · MCP',
            '现货价格、企业及化合物数据；预置 Streamable HTTP 和 Bearer 鉴权',
            dataHubMcpUrl,
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _keyField(_hubKey, '粘贴数据中台 MCP 密钥', _hideHub, () => setState(() => _hideHub = !_hideHub)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy || client == null ? null : _connectHub,
                icon: const Icon(Icons.hub_outlined),
                label: Text(_busyHub ? '正在连接 MCP…' : '保存密钥并连接数据中台'),
              ),
              TextButton(onPressed: () => _openKeyPage(dataHubKeysUrl), child: const Text('获取数据中台密钥')),
              if (_hubMessage != null) Text(_hubMessage!),
              const SizedBox(height: 8),
              FutureBuilder<List<ChemClawConnectorStatus>?>(
                future: _statuses,
                builder: (context, state) {
                  if (client == null) return const Text('状态：DSH 主机尚未连接');
                  if (state.connectionState != ConnectionState.done) return const Text('正在检查 MCP 状态…');
                  if (state.hasError) return const Text('MCP 状态未知，请点击刷新');
                  if (state.data == null) return const Text('此主机未安装 ChemClaw MCP 预置桥接');
                  final service = state.data!.where((s) => s.id == chemDataHubId).firstOrNull;
                  return Text('数据中台状态：${switch (service?.state) {
                    'ready' => '已挂载（待实际查询验证）',
                    'needs-key' => '等待密钥',
                    'connecting' => '连接中',
                    'error' => '连接失败',
                    _ => '尚未就绪',
                  }}');
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: client == null ? null : () => _refresh(client),
                  child: const Text('刷新 MCP 状态'),
                ),
              ),
            ]),
        ),
        _card('化工社 · 公开化学检索', '免密钥，默认只允许公开只读工具',
            huagongsheMcpUrl,
            OutlinedButton.icon(
              onPressed: busy || client == null ? null : _connectPublic,
              icon: const Icon(Icons.science_outlined),
              label: Text(_busyPublic ? '连接中…' : '连接公开检索（免密钥）'),
            ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: ChemClawMcpPage.testPrompt));
            if (context.mounted) _note('MCP 查询测试问题已复制');
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('复制现货行情验证问题'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PluginsScreen(),
          )),
          icon: const Icon(Icons.extension_outlined),
          label: const Text('高级插件管理'),
        ),
        const SizedBox(height: 16),
        const Text('说明：预置不代表已授权，挂载不代表工具查询成功。'
            '本机和远程主机各自保存凭据；旧版或 Relay 主机可能不支持 ChemClaw MCP 桥接。'),
      ]),
    );
  }
}
