import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../database/db_helper.dart';
import 'crdt_merge_service.dart';

class SyncBrokerService {
  final String serverUrl;
  final String nodeId;
  final String companyId;
  final String authToken;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;

  SyncBrokerService({
    required this.serverUrl,
    required this.nodeId,
    required this.companyId,
    required this.authToken,
    WebSocketChannel? channelOverride,
  }) : _channel = channelOverride {
    if (channelOverride != null) {
      _isConnected = true;
      _subscription = channelOverride.stream.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (error) => _onDisconnected(),
        cancelOnError: true,
      );
    }
  }

  void connect() {
    if (_isConnected) return;

    try {
      final uri = Uri.parse(
          '$serverUrl/ws?node_id=$nodeId&company_id=$companyId&token=$authToken');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (error) => _onDisconnected(),
        cancelOnError: true,
      );

      _isConnected = true;
      pushPendingDeltas();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _onMessageReceived(dynamic message) async {
    try {
      final Map<String, dynamic> data = jsonDecode(message as String);
      final String type = data['type'] as String? ?? '';

      if (type == 'SYNC_DELTAS') {
        final List<dynamic> rawDeltas = data['payload'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> remoteDeltas =
            rawDeltas.cast<Map<String, dynamic>>();

        // Ingest remote deltas inside SQLite transaction
        await CRDTMergeService.instance.applyRemoteDeltas(remoteDeltas);

        // Acknowledge processed watermark
        if (_channel != null) {
          _channel!.sink.add(jsonEncode({
            'type': 'ACK_DELTAS',
            'last_hlc': data['last_hlc'],
          }));
        }
      }
    } catch (_) {}
  }

  Future<void> pushPendingDeltas() async {
    if (!_isConnected || _channel == null) return;

    final unsyncedLogs =
        await DBHelper.instance.getPendingSyncChangelogs(limit: 100);
    if (unsyncedLogs.isEmpty) return;

    _channel!.sink.add(jsonEncode({
      'type': 'PUSH_DELTAS',
      'node_id': nodeId,
      'company_id': companyId,
      'payload': unsyncedLogs,
    }));

    final changeIds =
        unsyncedLogs.map((e) => e['change_id'] as String).toList();
    await DBHelper.instance.markSyncChangelogsSynced(changeIds);
  }

  void _onDisconnected() {
    _isConnected = false;
    _subscription?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
