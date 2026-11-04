# ChemClaw 手机版：打包 Android 测试 APK

本流程**只涉及** `zoeyzhang233666/chemclaw-mobile`；不要在 `chemclaw-bot` 桌面仓库创建工作树或执行命令。

## 最容易的方式：GitHub Actions 在线打包

已提供 `.github/workflows/android-test-apk.yml`，在分支 `feat/chemclaw-mobile-brand-and-mcp` 上有 **push** 时自动执行以下流程：

1. checkout 本手机版 Fork，安装 Flutter 3.47.7、Node 24.22.1、Java 17、Gradle 9.3.1。
2. 运行品牌和包名的源码检查。
3. `bash runtime/build-runtime.sh arm64-v8a`：制作手机侧 DSH Linux rootfs。
4. `bash tooling/build-apk.sh --release --flavor arm64`：构建带 rootfs 的 ARM64 APK。
5. 验证 rootfs 在包内，上传 GitHub Actions 工件（Artifact）。

### 第一次启用 Fork 的 GitHub Actions

打开 [手机版 Actions](https://github.com/zoeyzhang233666/chemclaw-mobile/actions)。新 Fork 可能显示 **I understand my workflows, go ahead and enable them**；点击启用后，只有**之后发生的 push** 才会触发本分支上的自动打包。可以在开发分支新增一次提交，或在本 PR 后续更新时自动触发。

请注意：这个工作流目前**只在开发分支**，尚未加入 `main`，GitHub 的 **Run workflow** 手动按钮通常要求工作流先存在于默认分支。不要为看到按钮而提前合并尚未验收的 PR。

### 成功后怎么下载

在 **Actions** 中打开 **ChemClaw Mobile · Android test APK** 的成功运行 → 页面底部 **Artifacts** → **ChemClaw-Mobile-Android-arm64-TEST**。下载得到 ZIP，解压找到：

- `ChemClaw-Mobile-Android-arm64-TEST.apk`
- `SHA256SUMS`

将 APK 传到 Android 手机，点击文件安装；手机可能需要给文件管理器授权“安装未知应用”。这只是用于功能验证的测试包，**不在 GitHub Releases 公开发布**。需要 Android 8.0+ 且 CPU 支持 ARM64。

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
