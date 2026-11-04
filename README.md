# ChemClaw 手机版

**ChemClaw Mobile · 基于 DSH Go 的独立 Android 化工行业 AI Agent**

这是 [DSH Go](https://github.com/ccch1mneyyy/dsh-Go) 的独立 Fork，用于开发 ChemClaw 的 Android 客户端。当前为**开发分支改造阶段**，不是已完成的正式 APK。

## 开发定位

- **手机本机运行**：尽可能保留 DSH Go 的本机 DSH 引擎、工具、Skills 与 MCP 宿主能力。
- **远程工作**：通过 SSH 连接已有的 DSH/ChemClaw 主机，由该主机执行工具、MCP 和耗时任务。
- **行业数据**：计划接入芯化和云数据中台的 MCP（实际地址、权限必须由服务方提供），优先使用可靠现货数据，明确区分期货与现货。
- **ChemClaw 品牌**：使用 ChemClaw 的云朵标识、Paper 主题及独立 Android Application ID。
- **多智能体协作**：保留 DSH 原生「智能体团队」插件；手机版不再开发独立的化工专家／专家群／ChemClaw Bot 页面。行业 Skills、GenUI 交互图表、Office 文件交付与预览仍需单独测试。

## 当前进度

已在独立开发分支修改 App 名称、Paper 主题（亮／暗）、图标资源与更新仓库。手机「设置」首页的首选服务现已优先展示 **APIHub 模型服务** 和 **芯化和云数据中台 MCP** 两个独立配置入口，点击后直接展示对应的密钥配置卡片。DeepSeek 官方账号登录保留在页面下方。MCP 执行能力来自底层 DSH，**没有预置真实的数据中台地址、Token，也没有完成真实调用验收**。

完整的配置方式与测试清单： [docs/CHEMCLOUD_MCP.md](docs/CHEMCLOUD_MCP.md)。

### 构建

本项目仍沿用 DSH Go 的 Flutter／Android 构建流程与 rootfs 运行时打包方式。第一次构建前须核对 `runtime/out` 所需产物、Flutter SDK、Android SDK 与 Java 版本。**不要直接把原项目的安装包当成 ChemClaw 手机版发布。**

当前版本源于 DSH Go v1.0.9，ChemClaw 手机版版本暂定 `0.1.0`。

### 发布前阻断项

- 清理原 DSH Go 非自由授权的品牌、吉祥物、鲸鱼、桌宠与宣传素材（不仅是启动图标）；见上游 [ASSETS.md](ASSETS.md)。
- Android 真机 UI 回归、更新分享域名检查、权限审计、Golden 视觉快照更新。
- 使用真实 MCP 服务端验证 `initialize`／`tools/list` 和行情工具调用。
- 验证本机／SSH／DSH Remote 下的 DSH 原生智能体团队、GenUI、Skills 及文件交付兼容性。
- APK 构建、签名与自动更新发布流程。

**当前代码禁止作为已经验收的正式客户端对外宣传。**

## 授权与来源

本项目是 [DSH Go](https://github.com/ccch1mneyyy/dsh-Go) 的派生项目，保留 Git 历史、[AGPL-3.0 许可证](LICENSE) 及 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 中的原作者与第三方软件声明。原 DSH Go 的部分品牌／吉祥物资产不在 AGPL 授权范围内，**不能因为 Fork 就获得重新发布的授权**。

ChemClaw 桌面端品牌参考：[zoeyzhang233666/chemclaw-bot](https://github.com/zoeyzhang233666/chemclaw-bot)（**仅只读参考，移动版代码不写回该仓库**）。

---
原始 DSH Go 项目由 [ccch1mneyyy](https://github.com/ccch1mneyyy) 开发。ChemClaw 手机版为独立派生版本，不是 DeepSeek 官方 Android 应用。
