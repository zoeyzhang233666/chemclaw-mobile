import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/hosts_state.dart';
import '../plugins/plugins_screen.dart';

/// Help users connect ChemClaw's industry MCP to the ACTIVE DSH host.
///
/// A Flutter client cannot claim that a remote MCP server is connected
/// without asking the host. This page intentionally does not store secrets,
/// invent an endpoint or report a fabricated connection state.
class ChemClawMcpPage extends ConsumerWidget {
  const ChemClawMcpPage({super.key});

  static const testPrompt =
      '请先确认当前主机是否已加载 chem-data-hub MCP 工具。'
      '如果可用，请通过 MCP 查询甲醇华东现货最近一个月价格，'
      '注明地区、日期、单位、价格口径和数据源。'
      '如果没有 MCP 工具或查询失败，请明确说明，'
      '不要用期货价格冒充现货，也不要编造价格。';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(activeHostProvider);
    final local = host.isLocal;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = local ? '本机 DSH 引擎' : '当前远程 DSH 主机';

    Widget paragraph(String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(body, style: text.bodyMedium),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('化工数据 MCP')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('目标：$active', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    local
                        ? '本机模式：需要在手机运行的 DSH 主机中配置可访问的 HTTPS MCP 服务。'
                        : '远程模式：MCP 应配置在远程电脑／服务器的 DSH 主机上，手机复用该主机的工具。',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('接入步骤', style: text.titleLarge),
          const SizedBox(height: 12),
          paragraph('1. 联系数据中台管理员确认正式的 MCP 地址、协议与鉴权方式。普通网页地址不等于 MCP 接口。'),
          paragraph('2. 在当前主机的 DSH 配置中启用 @deepseek-ai/dsh-mcp-client，使用 Streamable HTTP 或已有的 stdio MCP Server。'),
          paragraph('3. 在主机上安全保存凭据，完成引擎重启和初始化测试；不要把密钥粘贴到聊天或公开仓库。'),
          paragraph('4. 用下方提示词验证数据中台能否返回真实现货行情。是否连接成功，以实际工具返回为准。'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.extension_outlined),
            label: const Text('打开当前主机的插件管理'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PluginsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制 MCP 查询测试问题'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: testPrompt));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('测试问题已复制到剪贴板')),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('注意', style: text.titleMedium?.copyWith(color: scheme.error)),
          const SizedBox(height: 8),
          paragraph(
            '本页是配置向导，不会自动连接数据中台，也不代表已通过鉴权。'
            'SSH 主机和本机的 MCP 配置彼此独立，切换主机后需分别验证。'
            'DSH Remote 的 Bot／群聊兼容性需要单独验收。',
          ),
        ],
      ),
    );
  }
}
