import 'dart:convert';

enum SyncRole { host, client }

enum SyncStatus {
  disconnected,
  listening,
  connecting,
  connected,
  syncing,
  error,
}

enum SyncStrategy {
  safeMerge, // Additive union (preserves local & adds missing)
  overwritePeer, // Force replaces peer database
  restoreFromPeer, // Force replaces local database with peer's
}

class SyncMessage {
  final String type; // 'auth', 'auth_ok', 'auth_fail', 'snapshot', 'ping', 'pong', 'request_snapshot'
  final String? token;
  final String? deviceName;
  final String syncMode; // 'safe_merge' | 'force_replace'
  final dynamic payload;
  final int timestamp;

  SyncMessage({
    required this.type,
    this.token,
    this.deviceName,
    this.syncMode = 'safe_merge',
    this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'type': type,
    if (token != null) 'token': token,
    if (deviceName != null) 'deviceName': deviceName,
    'syncMode': syncMode,
    if (payload != null) 'payload': payload,
    'timestamp': timestamp,
  };

  String toJson() => jsonEncode(toMap());

  factory SyncMessage.fromMap(Map<String, dynamic> map) {
    return SyncMessage(
      type: map['type'] as String? ?? 'unknown',
      token: map['token'] as String?,
      deviceName: map['deviceName'] as String?,
      syncMode: map['syncMode'] as String? ?? 'safe_merge',
      payload: map['payload'],
      timestamp:
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory SyncMessage.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SyncMessage.fromMap(map);
  }
}

class SyncConnectionInfo {
  final String host;
  final int port;
  final String token;
  final String pin;
  final String deviceName;

  const SyncConnectionInfo({
    required this.host,
    required this.port,
    required this.token,
    required this.pin,
    required this.deviceName,
  });

  String toQrString() {
    return jsonEncode({
      'v': 1,
      'h': host,
      'p': port,
      't': token,
      'pin': pin,
      'd': deviceName,
    });
  }

  static SyncConnectionInfo? fromQrString(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final host = map['h']?.toString();
      final port = int.tryParse(map['p']?.toString() ?? '');
      final token = map['t']?.toString();
      final pin = map['pin']?.toString() ?? '';
      final device = map['d']?.toString() ?? 'Remote Peer';
      if (host != null && port != null && token != null) {
        return SyncConnectionInfo(
          host: host,
          port: port,
          token: token,
          pin: pin,
          deviceName: device,
        );
      }
    } catch (_) {}
    return null;
  }
}
