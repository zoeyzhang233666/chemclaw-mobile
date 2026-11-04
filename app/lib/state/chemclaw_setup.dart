/// ChemClaw official service presets, checked against the desktop plugin.
/// All endpoints are fixed and HTTPS; no user credentials are bundled.
import 'package:dsh_client/dsh_client.dart';

import 'provider_backend.dart';
import 'provider_keys.dart';

const apiHubBaseUrl = 'https://apihub.chem-cloud.cn/v1';
const apiHubKeysUrl = 'https://apihub.chem-cloud.cn/keys';
const dataHubMcpUrl = 'https://datahub.chem-cloud.cn/mcp';
const dataHubKeysUrl = 'https://mcp.chem-cloud.cn/';
const huagongsheMcpUrl = 'https://huagongshe.com/mcp';
const apiHubRouteId = 'apihub';
const apiHubKeyRef = 'APIHUB_API_KEY';

bool isApiHubChatModel(String id) {
  return !RegExp(
    r'embed|rerank|moderation|whisper|text-to-speech|speech-to-text|tts|transcrib|'
    r'stable-diffusion|flux|dall-e|image-gen|image-generation|video-gen|sora|'
    r'suno|music|realtime',
  ).hasMatch(id.toLowerCase());
}

List<ProviderModelSpec> pickApiHubModels(List<DiscoveredModel> source, {int limit = 12}) {
  final selected = <ProviderModelSpec>[];
  final seen = <String>{};
  for (final model in source) {
    if (!isApiHubChatModel(model.id) || !seen.add(model.id)) continue;
    selected.add(model.toSpec());
    if (selected.length >= limit) break;
  }
  return selected;
}

class ApiHubSetupResult {
  const ApiHubSetupResult({required this.models, required this.created});
  final int models;
  final bool created;
}

/// Discovers actual models before updating the host, then writes an API key
/// reference into the provider profile and the secret value to credentials.
/// Existing routes with conflicting endpoints are never overwritten.
Future<ApiHubSetupResult> configureApiHub(
  ProviderBackend backend,
  String suppliedKey, {
  ProviderKeyVault? vault,
}) async {
  final key = suppliedKey.replaceAll(RegExp(r'\s'), '');
  if (key.isEmpty || !RegExp(r'^[\x21-\x7E]+$').hasMatch(key) ||
      RegExp(r'^[A-Z][A-Z0-9_]*=').hasMatch(key)) {
    throw const FormatException('请粘贴 APIHub 密钥，不要包含空格、引号或环境变量名称');
  }
  final initial = await backend.read();
  if (initial == null || !initial.writable) {
    throw StateError('当前 DSH 主机无法编辑模型配置');
  }
  final found = initial.byRoute(apiHubRouteId);
  if (found != null && (found.baseUrl?.replaceFirst(RegExp(r'/+$'), '') != apiHubBaseUrl ||
      (found.api != null && found.api != ProviderApi.openaiCompletions.wire))) {
    throw StateError('已有其他模型渠道占用了 apihub 名称');
  }

  final candidates = await backend.discover(
    baseUrl: apiHubBaseUrl,
    api: ProviderApi.openaiCompletions,
    apiKey: key,
  );
  final models = pickApiHubModels(candidates);
  if (models.isEmpty) throw StateError('APIHub 没有返回可用的聊天模型');

  final current = await backend.read();
  if (current == null || !current.writable) throw StateError('模型配置已变为不可写');
  final existing = current.byRoute(apiHubRouteId);
  if (existing != null && (existing.baseUrl?.replaceFirst(RegExp(r'/+$'), '') != apiHubBaseUrl ||
      (existing.api != null && existing.api != ProviderApi.openaiCompletions.wire))) {
    throw StateError('已有其他渠道占用 apihub，未修改其配置');
  }

  if (existing == null) {
    await backend.create(ProviderProfile(
      route: apiHubRouteId,
      displayName: 'APIHub',
      api: ProviderApi.openaiCompletions.wire,
      baseUrl: apiHubBaseUrl,
      apiKeyEnv: apiHubKeyRef,
      models: models,
    ));
  } else {
    await backend.update(
      apiHubRouteId,
      displayName: 'APIHub',
      api: ProviderApi.openaiCompletions,
      baseUrl: apiHubBaseUrl,
      apiKeyEnv: existing.apiKeyEnv == apiHubKeyRef ? null : apiHubKeyRef,
      models: existing.models.isEmpty ? models : existing.models,
      expectedRevision: current.revision,
    );
  }
  await backend.storeKey(apiHubKeyRef, key);
  if (backend.isLocal && vault != null) {
    try {
      await vault.write(apiHubRouteId, key);
    } catch (_) {
      // Engine credentials remain authoritative even if phone backup fails.
    }
  }
  return ApiHubSetupResult(models: models.length, created: existing == null);
}
