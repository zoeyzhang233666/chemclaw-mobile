/// Strongly typed optional ChemClaw MCP bridge, unavailable on old/relay hosts.
/// Customer keys use DSH credentials/set; the bridge receives no secret body.
library;

import 'carrier.dart';
import 'errors.dart';
import 'json.dart';
import 'session_api.dart';

const chemclawMcpPath = '/dsh-go/v1/chemclaw/connectors';
const chemDataHubId = 'chem-data-hub';
const huagongsheId = 'huagongshe';
const chemDataHubKeyRef = 'CHEM_DATA_HUB';

class ChemClawConnectorStatus {
  const ChemClawConnectorStatus({
    required this.id,
    required this.state,
    required this.anonymous,
    this.reason,
  });

  factory ChemClawConnectorStatus.fromJson(Map<String, Object?> raw) =>
      ChemClawConnectorStatus(
        id: raw['id'] is String ? raw['id'] as String : '',
        state: raw['state'] is String ? raw['state'] as String : 'unknown',
        anonymous: raw['anonymous'] == true,
        reason: raw['reason'] is String ? raw['reason'] as String : null,
      );

  final String id;
  final String state;
  final bool anonymous;
  final String? reason;
  bool get ready => state == 'ready';
}

extension ChemClawConnectorsApi on DshClient {
  Future<List<ChemClawConnectorStatus>?> listChemClawConnectors({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final transport = carrier;
    if (!canReachDshGo || transport is! DshHttpCarrier) return null;
    final response = await transport.connection.get(chemclawMcpPath, timeout: timeout);
    if (response.statusCode == 404 || response.statusCode == 405) return null;
    if (response.statusCode != 200 || response.contentType != 'application/json') {
      throw DshHttpException(response.statusCode, 'ChemClaw MCP inventory unavailable');
    }
    final json = asMap(tryDecodeJson(response.text));
    if (json?['v'] != 1 || json?['services'] is! List) {
      throw const DshProtocolException('ChemClaw MCP service inventory invalid');
    }
    return [
      for (final item in json!['services'] as List)
        if (asMap(item) case final map?) ChemClawConnectorStatus.fromJson(map),
    ];
  }

  Future<ChemClawConnectorStatus> connectChemClawMcp(
    String serviceId, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (serviceId != chemDataHubId && serviceId != huagongsheId) {
      throw ArgumentError.value(serviceId, 'serviceId', 'unsupported service');
    }
    final transport = carrier;
    if (!canReachDshGo || transport is! DshHttpCarrier) {
      throw const DshRemoteException('unavailable', 'ChemClaw MCP bridge not accessible');
    }
    final response = await transport.connection.postJson(
      '$chemclawMcpPath/$serviceId',
      const {'action': 'connect'},
      timeout: timeout,
    );
    if (response.statusCode == 404 || response.statusCode == 405) {
      throw const DshRemoteException('unavailable', 'ChemClaw MCP bridge not installed');
    }
    if (response.statusCode != 200 || response.contentType != 'application/json') {
      throw DshHttpException(response.statusCode, 'ChemClaw MCP connection failed');
    }
    final json = asMap(tryDecodeJson(response.text));
    final service = asMap(json?['service']);
    if (json?['v'] != 1 || service?['id'] != serviceId) {
      throw const DshProtocolException('ChemClaw MCP connection reply invalid');
    }
    return ChemClawConnectorStatus.fromJson(service!);
  }
}
