# ChemClaw 手机版：APIHub 与行业 MCP 预置

本功能只在 zoeyzhang233666/chemclaw-mobile 中实现；电脑版 chemclaw-bot 是独立项目。

## 手机首次使用

首次打开可选「连接 ChemClaw 服务（APIHub / MCP）」。随后在「设置 → ChemClaw 服务连接」也能修改。必须先连接本机 DSH 运行环境，才能安全写入本机密钥。

| 服务 | 预设 HTTPS 地址 | 获取密钥 | 使用步骤 |
|---|---|---|---|
| APIHub 模型 | https://apihub.chem-cloud.cn/v1 | https://apihub.chem-cloud.cn/keys | 粘贴 Key → 用真实模型列表验证 → 建立 apihub 渠道 → 保存到 DSH 凭据库 |
| 芯化和云数据中台 | https://datahub.chem-cloud.cn/mcp | https://mcp.chem-cloud.cn/ | 粘贴 MCP Key → 保存到 DSH 凭据库 → 当前 Host 尝试加载 HTTP MCP |
| 化工社公开查询 | https://huagongshe.com/mcp | https://huagongshe.com/zh-CN/mcp-guide | 公开只读工具无需密钥，私有/写操作禁止 |
| 企查查（可选） | https://agent.qcc.com/mcp/{company,ipr,operation,risk}/stream | 用户向企查查开通授权 | 仅粘贴一次 QCC 密钥，即可按账号权限连接四项 HTTPS MCP |

**APIHub 与数据中台需要两份各自授权的密钥**，二者不能随意互换。服务是否可用取决于密钥账号与实时网络、后端状态。一个 Key 不保证可以调用任何模型或查询所有数据。

## 技术实现

- APIHub：OpenAI Completions 协议，使用真实模型发现；凭据引用 APIHUB_API_KEY，用户配置文件只存引用，不存密钥值。本机 Android Keystore 可备份供 DSH 恢复。
- 数据中台：Streamable HTTP + Bearer，凭据引用 CHEM_DATA_HUB。HTTP 地址与源码均不包含客户密钥。
- 企查查：4 个官方 HTTPS MCP 地址共用 QCC 凭据引用。未提供密钥不建立连接；是否可用取决于用户的商业授权。
- 宿主桥接：runtime/bridge/dsh-go-bridge/lib/chemclaw-connectors.js 使用 DSH 原有的 MCP 客户端和工具调用路径；Flutter 只负责配置与展示真实 Host 状态。
- 预置的 MCP 连接在实际 MCP 初始化通过后才会显示已挂载；仍须用真实工具查询验证数据。401、403、DNS、超时、未装旧版 Bridge 都不得假报可用。
- Android 本机和 SSH/Relay 远端 Host 配置彼此独立。远端未装 ChemClaw Bridge 时，无法直接使用新版一键 MCP 设置；可另行配置远端 Host。

## 业务与发布验收

数据中台需在真实 Android 手机上查询甲醇华东现货，输出市场、日期、单位、规格与来源；没有现货价格时明确回答缺失，绝不使用期货冒充。需要进一步检验上下文模型切换、断线重连、秘钥更新、远端 Host 切换、真机工具调用与授权撤销。

以上只预置 **APIHub、芯化和云数据中台、公开化工社及可选企查查** 服务；不会自动迁移桌面版的全部 Bots、群聊、100+ 行业 Skills、Office、GenUI 或私有服务。仍需分别做功能适配与真实验收。

保留上游作者署名，受限素材需在公开发布前完成许可审计。PR #1 保持 Draft，所有测试及 APK 真机验收通过后才决定发布。
