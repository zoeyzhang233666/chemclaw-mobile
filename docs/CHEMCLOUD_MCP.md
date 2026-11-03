# ChemClaw 手机版：化工数据 MCP 接入与验收

## 如何工作

MCP 工具属于实际运行 DeepSeek Harness 的 **Host**。Flutter 客户端呈现工具调用结果；它本身不会自动变成 MCP Server。

| 连接模式 | 配置位置 | 状态 |
|---|---|---|
| Android 本机 DSH | 手机内 DSH profile | 底层支持 MCP，行业服务器仍需配置和实测 |
| SSH 连接 Windows／Linux | 远端 DSH profile | 复用远程主机 MCP；需核实远端插件与 Bot |
| DSH Remote | 服务端 DSH profile | MCP 执行依赖服务端；Bot／群聊不保证 |

底层 DSH 已有 `@deepseek-ai/dsh-mcp-client`，支持 stdio 及 Streamable HTTP。不是在手机上另造一个数据源代理。

## 配置流程

1. 请数据中台负责人提供 **实际 MCP URL**、协议和访问凭据。平台首页网址不等于 MCP 协议地址。
2. 查看 [配置模板](../config/chemcloud-mcp.example.yml)。模板使用不可路由的 `.invalid` 域名，绝不是可用服务。
3. 仅在当前活动 Host 上合并适当的插件条目，**不得覆盖整个 profile**。按该主机支持的安全凭据机制注入 Token，不在公开仓库、APK、日志或聊天记录中明文保存。
4. 重启当前 Host；确认工具初始化、`tools/list` 返回真实结果。旧版 SSH／relay 模式不应据此推断全部功能可写。
5. 使用手机「设置 → 化工数据 MCP」复制验证问题，在对应主机的 Agent 会话中执行。

## 业务验收（全部需要真实数据）

- 甲醇、纯碱、SBS 等**现货**查询：明确市场、规格、单位、时间、价税及交货口径；MCP 优先，不能用期货冒充现货。
- 甲醇、乙二醇**期现基差**：现货和期货分别有来源、频率、合约及时间戳；必要时区分主力、主连。
- 无 MCP、HTTP 401/403、超时、Host 切换、断线：不能显示虚假的「已连接」状态，也不能伪造工具结果。
- Bot／群聊和经典模式分别测试工具调用；确保模型能引用证据。
- 手机打开历史价格图、GenUI 卡片、下载文件及公告链接，必须真机验收。

## 边界

目前仓库只有 MCP 配置模板、Host 感知的配置说明页和测试问题；**没有实装数据中台正式 endpoint，也没有完成在线连通性验收**。连接不等于已经迁移桌面版 ChemClaw 的全部功能。
