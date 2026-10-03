import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/sync/sync_models.dart';
import 'package:cashflow/services/sync/sync_crypto.dart';
import 'package:cashflow/services/sync/sync_network_helper.dart';

class LiveSyncService {
  static final LiveSyncService instance = LiveSyncService._internal();

  LiveSyncService._internal() {
    DatabaseHelper.dataRevision.addListener(_onLocalDataRevisionChanged);
  }

  // Reactive state notifiers
  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(
    SyncStatus.disconnected,
  );
  final ValueNotifier<SyncRole?> roleNotifier = ValueNotifier<SyncRole?>(null);
  final ValueNotifier<String?> peerDeviceNameNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> activePinNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> activeQrPayloadNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> activeIpNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> activePortNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> canUndoNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastMergeSummaryNotifier =
      ValueNotifier<String?>(null);

  HttpServer? _server;
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _debounceTimer;

  String? _sessionToken;
  String? _sessionPin;
  bool _isApplyingRemoteSnapshot = false;
  int _failedAuthAttempts = 0;

  bool get isConnected => statusNotifier.value == SyncStatus.connected;

  /// Starts listening as a local Sync Host (Desktop default)
  Future<bool> startHost({int port = SyncNetworkHelper.defaultPort}) async {
    if (kIsWeb) return false;
    await disconnect();

    try {
      final localIp = await SyncNetworkHelper.getLocalIpAddress();
      if (localIp == null) {
        statusNotifier.value = SyncStatus.error;
        statusMessageNotifier.value =
            'Could not detect local IP address. Check Wi-Fi or Hotspot.';
        return false;
      }

      _sessionToken = SyncCrypto.generateSessionToken();
      _sessionPin = SyncCrypto.generatePin();
      _failedAuthAttempts = 0;

      // Bind to 0.0.0.0
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      } catch (_) {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }

      final actualPort = _server!.port;
      final deviceName = SyncNetworkHelper.getDeviceName();

      final connectionInfo = SyncConnectionInfo(
        host: localIp,
        port: actualPort,
        token: _sessionToken!,
        pin: _sessionPin!,
        deviceName: deviceName,
      );

      roleNotifier.value = SyncRole.host;
      activeIpNotifier.value = localIp;
      activePortNotifier.value = actualPort;
      activePinNotifier.value = _sessionPin;
      activeQrPayloadNotifier.value = connectionInfo.toQrString();
      statusNotifier.value = SyncStatus.listening;
      statusMessageNotifier.value = 'Waiting for peer to scan or connect...';

      _server!.listen(
        _handleIncomingHttpRequest,
        onError: (e) {
          developer.log('Sync server error: $e', name: 'LiveSyncService');
          unawaited(disconnect());
        },
      );

      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to start host',
        name: 'LiveSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      statusNotifier.value = SyncStatus.error;
      statusMessageNotifier.value = 'Failed to start sync host: $e';
      return false;
    }
  }

  void _handleIncomingHttpRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('WebSocket connections only');
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);

      if (_failedAuthAttempts >= 3) {
        socket.add(
          SyncMessage(
            type: 'auth_fail',
            payload: 'Too many failed attempts.',
          ).toJson(),
        );
        await socket.close(WebSocketStatus.policyViolation, 'Rate limited');
        return;
      }

      // Check query param authentication
      final queryToken = request.uri.queryParameters['token'];
      if (queryToken != null &&
          _sessionToken != null &&
          SyncCrypto.constantTimeEquals(queryToken, _sessionToken!)) {
        _attachSocket(socket, peerName: 'Paired Device', role: SyncRole.host);
        return;
      }

      // Otherwise, wait for first auth message
      StreamSubscription? authSub;
      final authTimeout = Timer(const Duration(seconds: 10), () {
        unawaited(authSub?.cancel());
        unawaited(
          socket.close(WebSocketStatus.policyViolation, 'Auth timeout'),
        );
      });

      authSub = socket.listen((data) {
        authTimeout.cancel();
        unawaited(authSub?.cancel());
        try {
          final msg = SyncMessage.fromJson(data.toString());
          if (msg.type == 'auth') {
            final providedToken = msg.token ?? '';
            final isTokenValid =
                _sessionToken != null &&
                SyncCrypto.constantTimeEquals(providedToken, _sessionToken!);
            final isPinValid =
                _sessionPin != null &&
                SyncCrypto.constantTimeEquals(providedToken, _sessionPin!);

            if (isTokenValid || isPinValid) {
              socket.add(
                SyncMessage(
                  type: 'auth_ok',
                  deviceName: SyncNetworkHelper.getDeviceName(),
                ).toJson(),
              );
              _attachSocket(
                socket,
                peerName: msg.deviceName ?? 'Mobile Device',
                role: SyncRole.host,
              );
            } else {
              _failedAuthAttempts++;
              socket.add(
                SyncMessage(
                  type: 'auth_fail',
                  payload: 'Invalid token or PIN',
                ).toJson(),
              );
              unawaited(
                socket.close(WebSocketStatus.policyViolation, 'Unauthorized'),
              );
            }
          }
        } catch (_) {
          unawaited(socket.close(WebSocketStatus.protocolError));
        }
      });
    } catch (e) {
      developer.log('Socket upgrade error: $e', name: 'LiveSyncService');
    }
  }

  /// Connects to a Host using scanned QR payload
  Future<bool> connectWithQr(String qrData) async {
    final info = SyncConnectionInfo.fromQrString(qrData);
    if (info == null) {
      statusNotifier.value = SyncStatus.error;
      statusMessageNotifier.value = 'Invalid QR code scanned.';
      return false;
    }
    return connectToHost(
      host: info.host,
      port: info.port,
      token: info.token,
      expectedPeerName: info.deviceName,
    );
  }

  /// Connects to Host using manual IP and PIN
  Future<bool> connectWithPin({
    required String host,
    required int port,
    required String pin,
  }) async {
    return connectToHost(
      host: host,
      port: port,
      token: pin,
      expectedPeerName: 'Desktop Host',
    );
  }

  /// Connects to Host WebSocket
  Future<bool> connectToHost({
    required String host,
    required int port,
    required String token,
    String? expectedPeerName,
  }) async {
    if (kIsWeb) return false;
    await disconnect();

    roleNotifier.value = SyncRole.client;
    statusNotifier.value = SyncStatus.connecting;
    statusMessageNotifier.value = 'Connecting to $host:$port...';

    try {
      final uri = Uri.parse('ws://$host:$port?token=$token');
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 8));

      _attachSocket(
        socket,
        peerName: expectedPeerName ?? 'Desktop Host',
        role: SyncRole.client,
      );

      // Send client auth message for double verification
      socket.add(
        SyncMessage(
          type: 'auth',
          token: token,
          deviceName: SyncNetworkHelper.getDeviceName(),
        ).toJson(),
      );

      return true;
    } catch (e) {
      statusNotifier.value = SyncStatus.error;
      statusMessageNotifier.value =
          'Failed to connect. Check same Wi-Fi/Hotspot: $e';
      return false;
    }
  }

  void _attachSocket(
    WebSocket socket, {
    required String peerName,
    required SyncRole role,
  }) {
    _socket = socket;
    peerDeviceNameNotifier.value = peerName;
    statusNotifier.value = SyncStatus.connected;
    statusMessageNotifier.value = 'Live Sync Active with $peerName';

    _socketSubscription = socket.listen(
      _handleSocketMessage,
      onError: (e) {
        developer.log('Socket error: $e', name: 'LiveSyncService');
        _handleDisconnectNotice('Connection error: $e');
      },
      onDone: () {
        _handleDisconnectNotice('Peer disconnected');
      },
    );

    _startHeartbeat();

    // Trigger initial safe merge exchange immediately for both peers with slight delay for socket readiness
    Future.delayed(const Duration(milliseconds: 100), () {
      if (isConnected && _socket != null) {
        unawaited(triggerSafeMerge());
      }
    });
  }

  void _handleSocketMessage(dynamic raw) async {
    try {
      final msg = SyncMessage.fromJson(raw.toString());
      switch (msg.type) {
        case 'ping':
          _socket?.add(SyncMessage(type: 'pong').toJson());
          break;
        case 'pong':
          break;
        case 'auth_ok':
          if (msg.deviceName != null) {
            peerDeviceNameNotifier.value = msg.deviceName;
          }
          unawaited(triggerSafeMerge());
          break;
        case 'auth_fail':
          statusNotifier.value = SyncStatus.error;
          statusMessageNotifier.value = 'Authentication failed: ${msg.payload}';
          await disconnect();
          break;
        case 'request_snapshot':
          // Peer requested our snapshot with requested mode
          unawaited(_broadcastCurrentSnapshot(mode: msg.syncMode));
          break;
        case 'snapshot':
          final snapshotPayload = msg.payload?.toString();
          if (snapshotPayload != null && snapshotPayload.isNotEmpty) {
            await _applyRemoteSnapshot(snapshotPayload, syncMode: msg.syncMode);
          }
          break;
      }
    } catch (e) {
      developer.log('Error handling sync message: $e', name: 'LiveSyncService');
    }
  }

  Future<void> _applyRemoteSnapshot(
    String jsonPayload, {
    required String syncMode,
  }) async {
    _isApplyingRemoteSnapshot = true;
    try {
      statusNotifier.value = SyncStatus.syncing;

      if (syncMode == 'force_replace') {
        await DatabaseHelper.instance.createPreSyncBackup();
        final success = await DatabaseHelper.instance.importDatabaseFromJSON(
          jsonContentForTesting: jsonPayload,
        );
        if (success) {
          lastMergeSummaryNotifier.value = 'Replaced local data from peer';
          statusMessageNotifier.value =
              'Local database replaced with peer copy.';
        }
      } else {
        // Safe additive merge (default)
        final results = await DatabaseHelper.instance.mergeDatabaseFromJSON(
          jsonPayload,
        );
        final txCount = results['transactions'] ?? 0;
        final accCount = results['accounts'] ?? 0;
        final catCount = results['categories'] ?? 0;
        final goalCount = results['goals'] ?? 0;

        final summary =
            'Safe Merge: +$txCount tx, +$accCount acc, +$catCount cat, +$goalCount goals';
        lastMergeSummaryNotifier.value = summary;
        statusMessageNotifier.value = summary;
      }

      canUndoNotifier.value = DatabaseHelper.instance.hasPreSyncBackup;
    } catch (e) {
      developer.log(
        'Failed to apply remote snapshot: $e',
        name: 'LiveSyncService',
      );
      statusMessageNotifier.value = 'Merge error: $e';
    } finally {
      _isApplyingRemoteSnapshot = false;
      statusNotifier.value = SyncStatus.connected;
    }
  }

  void _onLocalDataRevisionChanged() {
    if (_isApplyingRemoteSnapshot || !isConnected || _socket == null) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_broadcastCurrentSnapshot(mode: 'safe_merge'));
    });
  }

  Future<void> _broadcastCurrentSnapshot({String mode = 'safe_merge'}) async {
    if (!isConnected || _socket == null) return;
    try {
      final jsonSnapshot = await DatabaseHelper.instance
          .exportDatabaseToJSONString();
      final message = SyncMessage(
        type: 'snapshot',
        syncMode: mode,
        deviceName: SyncNetworkHelper.getDeviceName(),
        payload: jsonSnapshot,
      );
      _socket?.add(message.toJson());
    } catch (e) {
      developer.log(
        'Failed to broadcast snapshot: $e',
        name: 'LiveSyncService',
      );
    }
  }

  /// Triggers a non-destructive additive safe merge between both devices
  Future<void> triggerSafeMerge() async {
    if (!isConnected || _socket == null) return;
    statusMessageNotifier.value = 'Merging changes from both devices...';
    // 1. Send our snapshot to peer with safe_merge
    await _broadcastCurrentSnapshot(mode: 'safe_merge');
    // 2. Request peer's snapshot with safe_merge
    _socket?.add(
      SyncMessage(
        type: 'request_snapshot',
        syncMode: 'safe_merge',
        deviceName: SyncNetworkHelper.getDeviceName(),
      ).toJson(),
    );
  }

  /// Pushes this device's data to overwrite the peer device completely
  Future<void> triggerForcePush() async {
    if (!isConnected || _socket == null) return;
    statusMessageNotifier.value = 'Pushing local database to overwrite peer...';
    await _broadcastCurrentSnapshot(mode: 'force_replace');
  }

  /// Requests the peer's database to overwrite this device's local data
  Future<void> triggerRestoreFromPeer() async {
    if (!isConnected || _socket == null) return;
    statusMessageNotifier.value =
        'Requesting peer database to restore local copy...';
    _socket?.add(
      SyncMessage(
        type: 'request_snapshot',
        syncMode: 'force_replace',
        deviceName: SyncNetworkHelper.getDeviceName(),
      ).toJson(),
    );
  }

  /// Undoes the last sync operation using the pre-sync backup
  Future<bool> undoLastSync() async {
    final success = await DatabaseHelper.instance.restorePreSyncBackup();
    canUndoNotifier.value = DatabaseHelper.instance.hasPreSyncBackup;
    if (success) {
      lastMergeSummaryNotifier.value = 'Restored pre-sync snapshot';
      statusMessageNotifier.value = 'Restored data to state before last sync.';
    }
    return success;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isConnected && _socket != null) {
        try {
          _socket?.add(SyncMessage(type: 'ping').toJson());
        } catch (_) {
          _handleDisconnectNotice('Heartbeat failed');
        }
      }
    });
  }

  void _handleDisconnectNotice(String reason) {
    _heartbeatTimer?.cancel();
    unawaited(_socketSubscription?.cancel());
    _socket = null;
    if (roleNotifier.value == SyncRole.host && _server != null) {
      statusNotifier.value = SyncStatus.listening;
      statusMessageNotifier.value =
          'Peer disconnected. Waiting for connection...';
    } else {
      statusNotifier.value = SyncStatus.disconnected;
      statusMessageNotifier.value = reason;
    }
  }

  /// Cleanly closes connections
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;

    statusNotifier.value = SyncStatus.disconnected;
    roleNotifier.value = null;
    peerDeviceNameNotifier.value = null;
    activePinNotifier.value = null;
    activeQrPayloadNotifier.value = null;
    activeIpNotifier.value = null;
    activePortNotifier.value = null;
    statusMessageNotifier.value = 'Disconnected';
  }
}
