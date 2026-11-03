# ChemClaw Mobile

An independent Android adaptation of [DSH Go](https://github.com/ccch1mneyyy/dsh-Go) for ChemClaw, the chemical-industry AI agent.

**Status: development only. Not a verified APK or production release.**

The first-stage changes provide ChemClaw identity, a separate Android application ID, Paper light/dark colors, a cloud launcher icon, a separate update repository, and an in-app guide to connecting an MCP service to the currently selected DSH host.

**MCP**: DSH's local runtime and SSH-connected remote hosts can execute MCP tools configured on the *active host*. A real ChemCloud MCP endpoint and credentials must be provided by the data service operator. No URL or token is bundled and no live connection has been verified. See [MCP setup and acceptance](docs/CHEMCLOUD_MCP.md).

ChemClaw desktop Bot/group sessions, interactive GenUI charts, Office output and full Skills integration **still require mobile adaptation and testing**. DSH Remote compatibility must be tested separately.

**Redistribution warning:** The upstream project is [AGPL-3.0](LICENSE), with third-party notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Upstream [ASSETS.md](ASSETS.md) explicitly excludes certain mascot, branding and promotional assets from the open-source license. Those must be removed or replaced before public builds.

Upstream author: [ccch1mneyyy](https://github.com/ccch1mneyyy). ChemClaw desktop reference: [chemclaw-bot](https://github.com/zoeyzhang233666/chemclaw-bot) (read-only reference; this fork is separate). Not an official DeepSeek Android app.
