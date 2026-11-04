# ChemClaw 手机版：打包 Android 测试 APK

本流程**只涉及** `zoeyzhang233666/chemclaw-mobile`；不要在 `chemclaw-bot` 桌面仓库创建工作树或执行命令。

## 最容易的方式：GitHub Actions 在线打包

已提供 `.github/workflows/android-test-apk.yml`，在分支 `feat/chemclaw-mobile-brand-and-mcp` 上有 **push** 时自动执行以下流程：

1. checkout 本手机版 Fork，安装 Flutter 3.47.7、Node 24.22.1、Java 17、Gradle 9.3.1。
2. 运行品牌和包名的源码检查。
3. `bash runtime/build-runtime.sh arm64-v8a`：制作手机侧 DSH Linux rootfs。
4. `bash tooling/build-apk.sh --release --flavor arm64`：构建带 rootfs 的 ARM64 APK。
5. 验证 APK 的 Android 签名（v2/v3）、包名、ARM64 运行时、ZIP CRC 和权限；计算 SHA-256。核验失败则不提供 APK 下载。
6. 使用 GitHub Actions v7 的 `archive: false` **直接上传 APK 文件，不再额外封装为 ZIP**；另外上传校验和与审计报告。

### 第一次启用 Fork 的 GitHub Actions

打开 [手机版 Actions](https://github.com/zoeyzhang233666/chemclaw-mobile/actions)。新 Fork 可能显示 **I understand my workflows, go ahead and enable them**；点击启用后，只有**之后发生的 push** 才会触发本分支上的自动打包。可以在开发分支新增一次提交，或在本 PR 后续更新时自动触发。

请注意：这个工作流目前**只在开发分支**，尚未加入 `main`，GitHub 的 **Run workflow** 手动按钮通常要求工作流先存在于默认分支。不要为看到按钮而提前合并尚未验收的 PR。

### 成功后怎么下载（现在无需 ZIP 解压）

打开 [手机版 Actions](https://github.com/zoeyzhang233666/chemclaw-mobile/actions) 中最新的 **ChemClaw Mobile · Android test APK** 成功运行：

1. 在运行页面底部 **Artifacts** 点击 **ChemClaw-Mobile-Android-arm64-TEST.apk**。现在下载的是原始 APK，**不再是 `.zip`**，也无需解压（依赖 GitHub Actions upload-artifact v7）。
2. 构建页面 **Summary** 会显示 APK SHA-256、签名证书指纹、敏感权限清单和源码提交 SHA。
3. 单独的 **ChemClaw-Mobile-Android-arm64-AUDIT** 工件包含 `SHA256SUMS` 和 `APK_AUDIT.json`（此报告工件可仍为 ZIP）。
4. 在 Windows PowerShell 中检查下载的 APK：
   ```powershell
   Get-FileHash -Algorithm SHA256 -Path .\ChemClaw-Mobile-Android-arm64-TEST.apk
   ```
   将结果与构建 Summary 或 `SHA256SUMS` 中的十六进制哈希逐字比对。不一致就丢弃文件。

### Chrome 提示「已屏蔽危险的下载内容」怎么办？

原来是 Actions 额外压缩产生的 ZIP（内含可执行 APK）；直接下载 APK 可以去掉 ZIP 检测层，但**不会绕过 Chrome 对 APK 自身的安全评估**。

- **不要关闭 Chrome 安全浏览、强制保留、改扩展名或给 ZIP 加密码。**
- 先检查本次构建的 `APK_AUDIT.json`：签名方案、包名、权限、SDK 版本、证书哈希；它证明文件完整且由对应构建签名，**不等于杀毒扫描通过**。
- APK 包含可执行 Linux DSH rootfs，而且当前测试包仍使用 CI 的**临时 Android debug 证书**（每次构建的证书可能不同）；部分敏感权限来自手机操控、悬浮窗、文件系统和应用更新。这些都需要独立审查。
- 如 Chrome **直接拦截 APK**，记录安全提示详细分类和文件哈希，暂停安装；排查第三方检测结果和应用权限后，再通过软件发行商纠错渠道申请复核。
- 安卓 ARM64、Android 8.0+ 为当前目标；个人测试也不要把测试包当成已通过安全审计的正式版本。

### 日后可信直接下载

已增加手动的 `prepare-verified-android-apk.yml` 工作流。仅在 **main 全量 CI 通过、确认素材授权和权限风险、配置稳定的私有 Android 签名密钥、APK 签名/校验通过、独立 ClamAV 检测成功**后，才能生成一个包含直接 `.apk` 文件的 **GitHub Release 草稿**。草稿还须经过人工复核才能公开发布。它不是目前测试工件的自动镜像，也不保证 Chrome 一定信任发布的 APK。

### 失败怎么办

打开失败的 Actions 运行，展开红色步骤并复制错误日志。重点检查：`Build bundled ARM64 DSH runtime`、`Resolve Flutter packages` 和 `Package signed-for-testing release-mode APK`。首次构建会下载 Ubuntu/Node/DSH/proot/Flutter 等大量依赖，网络、空间、SDK 或 Gradle 都可能导致失败。

### 自己在 Linux / WSL2 打包

需在 **同一个 Linux 环境中**配置 Flutter、Android SDK、JDK 17、Node 24、Gradle 9、网络和构建工具。使用新的手机版 Fork：

```bash
git clone https://github.com/zoeyzhang233666/chemclaw-mobile.git
cd chemclaw-mobile
git fetch origin
git switch feat/chemclaw-mobile-brand-and-mcp
(cd app && flutter pub get --enforce-lockfile)
bash runtime/build-runtime.sh arm64-v8a
bash tooling/build-apk.sh --flavor arm64
```

输出：`app/build/app/outputs/flutter-apk/app-arm64-release.apk`。

## 测试包与正式版的区别

- **签名**：没有公司正式签名密钥时，release 构建回落到 Android debug 签名。安装测试可以，但将来正式发布时需要稳定的自有 release key。
- **兼容性**：目前尚未验证 ChemClaw Bot／群聊、MCP 真实接口、GenUI、文件预览和运行时真机表现；APK 构建成功不表示全部功能可用。
- **版权**：原 DSH Go 的部分吉祥物/宣传素材没有开源授权；公开发布前必须完成 `ASSETS.md` 的素材清理与所有品牌资源审计。
- **升级**：不要把上游原 DSH Go 的签名、下载服务或更新通道当成自己的。
- **仓库**：仅从 `chemclaw-mobile` 构建，不对桌面 ChemClaw main 做任何改动。
