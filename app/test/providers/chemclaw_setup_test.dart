import 'package:dsh_app/state/chemclaw_setup.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preset endpoints match ChemClaw desktop sources', () {
    expect(apiHubBaseUrl, 'https://apihub.chem-cloud.cn/v1');
    expect(dataHubMcpUrl, 'https://datahub.chem-cloud.cn/mcp');
    expect(huagongsheMcpUrl, 'https://huagongshe.com/mcp');
    expect(apiHubKeyRef, 'APIHUB_API_KEY');
    expect(chemDataHubKeyRef, 'CHEM_DATA_HUB');
  });

  test('dynamic model discovery omits obvious auxiliary models and duplicate ids', () {
    const candidates = [
      DiscoveredModel(id: 'qwen3.5', name: 'Qwen'),
      DiscoveredModel(id: 'text-embedding-3'),
      DiscoveredModel(id: 'qwen3.5'),
      DiscoveredModel(id: 'whisper-1'),
      DiscoveredModel(id: 'deepseek-v4'),
    ];
    expect(pickApiHubModels(candidates).map((x) => x.id), ['qwen3.5', 'deepseek-v4']);
    expect(pickApiHubModels(candidates, limit: 1).map((x) => x.id), ['qwen3.5']);
  });

  test('valid APIHub key discovers before writing; profile contains only key ref', () async {
    final backend = FakeProviderBackend(discoverResult: const [
      DiscoveredModel(id: 'deepseek-v4', name: 'DeepSeek'),
    ]);
    final vault = MemoryProviderKeyVault();
    final result = await configureApiHub(backend, 'sk-private-example', vault: vault);
    expect(result.created, isTrue);
    expect(result.models, 1);
    expect(backend.callNames, ['read', 'discover', 'read', 'create', 'storeKey']);
    final profile = backend.profiles.single;
    expect(profile.route, apiHubRouteId);
    expect(profile.baseUrl, apiHubBaseUrl);
    expect(profile.api, ProviderApi.openaiCompletions.wire);
    expect(profile.apiKeyEnv, apiHubKeyRef);
    expect(profile.toJson().toString(), isNot(contains('sk-private-example')));
    expect(backend.stored[apiHubKeyRef], 'sk-private-example');
    expect(vault.data[apiHubRouteId], 'sk-private-example');
  });

  test('invalid key or no discovered chat models makes no writes', () async {
    final backend = FakeProviderBackend();
    await expectLater(configureApiHub(backend, 'APIHUB_API_KEY=sk-wrong'), throwsFormatException);
    await expectLater(configureApiHub(backend, 'sk-one sk-two'), throwsFormatException);
    await expectLater(configureApiHub(backend, 'sk-one\nother'), throwsFormatException);
    expect(backend.calls, isEmpty);
    await expectLater(configureApiHub(backend, 'sk-any'), throwsStateError);
    expect(backend.callNames, ['read', 'discover']);
    expect(backend.profiles, isEmpty);
    expect(backend.stored, isEmpty);
  });

  test('conflicting apihub id does not overwrite a different provider', () async {
    final backend = FakeProviderBackend(
      profiles: const [ProviderProfile(
        route: apiHubRouteId,
        api: 'openai-completions',
        baseUrl: 'https://some-other-provider.example/v1',
      )],
    );
    await expectLater(configureApiHub(backend, 'sk-user'), throwsStateError);
    expect(backend.callNames, ['read']);
    expect(backend.profiles.single.baseUrl, 'https://some-other-provider.example/v1');
  });

  test('remote Host never writes the optional Android Keystore backup', () async {
    final backend = FakeProviderBackend(isLocal: false, discoverResult: const [
      DiscoveredModel(id: 'qwen3.5'),
    ]);
    final vault = MemoryProviderKeyVault();
    await configureApiHub(backend, 'sk-remote-example', vault: vault);
    expect(backend.stored[apiHubKeyRef], 'sk-remote-example');
    expect(vault.data, isEmpty);
  });
}
