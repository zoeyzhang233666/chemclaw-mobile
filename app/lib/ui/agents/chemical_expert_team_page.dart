// Guided creation using DSH's official Agent Teams; no separate Bot product.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../state/agents_state.dart';
import '../../state/composer_insert.dart';
import '../../state/plugins_state.dart';
import '../../state/sessions_state.dart';
import '../plugins/plugin_actions.dart' show runPluginInstall, togglePluginBundle;
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'chem_team_bootstrap_host.dart';
import 'team_page.dart';

const chemicalTeamScenarios = <String>[
  '国内采购寻源', '外贸客户开发', '现货与期现研究',
  '供应商尽调', '合同与贸易风险', '自定义化工业务',
];

String chemicalTeamPrompt({required String scenario, required String product, required String goal}) =>
  '请使用已经启用的 DSH 官方 Agent Teams 工具为我完成化工业务任务。'
  '\n场景：$scenario\n产品、地区或客户：${product.trim()}\n目标和交付要求：${goal.trim()}'
  '\n先设计必要的专家分工及验收标准，再按实际工作量动态创建 2—4 个专家。'
  '确需分工时调用 spawn_teammate，使用团队消息和共享任务板协作；不要复活旧的 Bot 专家群。'
  '现货优先用芯化和云数据中台 MCP，查不到再联网，不得用期货冒充现货。'
  '每项价格、企业资质和结论附来源及时间，标记未核验信息，最后汇总可执行的业务建议。';

class ChemicalExpertTeamPage extends ConsumerStatefulWidget {
  const ChemicalExpertTeamPage({super.key});
  @override
  ConsumerState<ChemicalExpertTeamPage> createState() => _ChemicalExpertTeamPageState();
}

class _ChemicalExpertTeamPageState extends ConsumerState<ChemicalExpertTeamPage> {
  final _product = TextEditingController();
  final _goal = TextEditingController();
  String _scenario = chemicalTeamScenarios.first;
  bool _working = false;
  String? _note;
  @override
  void dispose() { _product.dispose(); _goal.dispose(); super.dispose(); }

  Future<void> _activate() async {
    if (_working) return;
    final bundle = ref.read(agentTeamBundleProvider).value;
    setState(() { _working = true; _note = null; });
    try {
      if (bundle == null) {
        final job = await runPluginInstall(context, const PluginInstallRequest(
          name: agentTeamBundle, spec: chemTeamOfficialSpec, title: '化工专家团'));
        if (mounted && job.phase != PluginInstallPhase.succeeded) {
          setState(() => _note = '安装失败，请检查网络和当前主机的插件权限。');
        }
      } else if (!bundle.enabled) {
        await togglePluginBundle(context, bundle, true);
      }
      if (mounted) ref.invalidate(installedPluginsProvider);
    } catch (_) {
      if (mounted) setState(() => _note = '启用失败，请检查连接和插件配置。');
    } finally { if (mounted) setState(() => _working = false); }
  }

  void _start() {
    if (_product.text.trim().isEmpty || _goal.text.trim().isEmpty) {
      setState(() => _note = '请填写产品或地区，以及具体的业务目标。');
      return;
    }
    final prompt = chemicalTeamPrompt(
      scenario: _scenario, product: _product.text, goal: _goal.text);
    ref.read(currentSessionProvider.notifier).select(null);
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(composerInsertProvider.notifier).request(ComposerInsert(token: prompt, sessionId: null));
  }

  @override
  Widget build(BuildContext context) {
    final english = AppLocale.isEnglish;
    final bundle = ref.watch(agentTeamBundleProvider).value;
    final ready = bundle?.enabled == true;
    return AppPage.list(
      title: english ? 'Chemical expert team' : '化工专家团',
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Text(english
            ? 'Build a dynamic team for chemical trading tasks using official DSH Agent Teams.'
            : '由官方 DSH 智能体团队根据化工业务目标动态安排专家分工、任务板与协作消息。')),
        SettingsSection(
          title: english ? 'Official plugin' : '官方插件',
          children: [
            SettingsTile(icon: AppIcons.team,
              title: english ? 'Agent Teams status' : '智能体团队状态',
              subtitle: ready ? '已启用' : bundle == null ? '当前主机尚未安装' : '尚未启用'),
            if (!ready) Padding(padding: const EdgeInsets.all(16),
              child: FilledButton(onPressed: _working ? null : _activate,
                child: Text(_working ? '处理中…' : '安装或启用官方智能体团队'))),
          ],
        ),
        SettingsSection(
          title: english ? 'Your business task' : '创建化工专家团',
          children: [
            Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _scenario,
                    decoration: const InputDecoration(labelText: '业务场景'),
                    items: [for (final item in chemicalTeamScenarios)
                      DropdownMenuItem(value: item, child: Text(item))],
                    onChanged: (value) { if (value != null) setState(() => _scenario = value); },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _product, maxLength: 160,
                    decoration: const InputDecoration(labelText: '产品、地区或客户',
                      hintText: '例如：华东地区甲醇采购')),
                  const SizedBox(height: 12),
                  TextField(controller: _goal, maxLength: 1200, minLines: 3, maxLines: 5,
                    decoration: const InputDecoration(labelText: '业务目标及交付要求',
                      hintText: '寻找供应商，核验报价、运费和风险，输出采购建议')),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: ready ? _start : null,
                    icon: const Icon(AppIcons.team),
                    label: Text(english ? 'Create team in a new chat' : '在新对话中创建专家团')),
                  const SizedBox(height: 8),
                  Text(english ? 'Review the inserted task in the editor before sending.'
                    : '任务先填入对话输入框，确认发送后才会调用官方团队工具。',
                    style: Theme.of(context).textTheme.bodySmall),
                  if (_note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_note!)),
                ],
              )),
          ],
        ),
        SettingsSection(title: english ? 'Current team' : '查看已有团队',
          children: [
            SettingsTile(icon: AppIcons.team,
              title: english ? 'Members and task board' : '成员、任务板与消息',
              onTap: () => Navigator.of(context).push(
                TeamPage.route(sessionId: ref.read(currentSessionProvider)))),
          ]),
      ],
    );
  }
}
