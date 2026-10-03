import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/services/sync/live_sync_service.dart';
import 'package:cashflow/services/sync/sync_models.dart';
import 'package:cashflow/services/sync/sync_crypto.dart';

void main() {
  group('LiveSyncService Tests', () {
    late LiveSyncService service;

    setUp(() {
      service = LiveSyncService.instance;
    });

    tearDown(() async {
      await service.disconnect();
    });

    test('initial state is disconnected', () {
      expect(service.statusNotifier.value, equals(SyncStatus.disconnected));
      expect(service.isConnected, isFalse);
    });

    test('disconnect resets notifiers cleanly', () async {
      await service.disconnect();

      expect(service.statusNotifier.value, equals(SyncStatus.disconnected));
      expect(service.roleNotifier.value, isNull);
      expect(service.peerDeviceNameNotifier.value, isNull);
      expect(service.activePinNotifier.value, isNull);
      expect(service.activeQrPayloadNotifier.value, isNull);
    });

    test('direct socket handshake authentication over loopback', () async {
      final token = SyncCrypto.generateSessionToken();

      // Bind a test server to an ephemeral port
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      bool authenticated = false;
      server.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final queryToken = request.uri.queryParameters['token'];
          if (queryToken != null &&
              SyncCrypto.constantTimeEquals(queryToken, token)) {
            authenticated = true;
          }
          final ws = await WebSocketTransformer.upgrade(request);
          ws.add(SyncMessage(type: 'auth_ok').toJson());
          await ws.close();
        }
      });

      // Connect test client
      final client = await WebSocket.connect(
        'ws://127.0.0.1:$port?token=$token',
      );
      final firstMsg = await client.first;
      final parsed = SyncMessage.fromJson(firstMsg.toString());

      expect(authenticated, isTrue);
      expect(parsed.type, equals('auth_ok'));

      await client.close();
      await server.close(force: true);
    });
  });
}
