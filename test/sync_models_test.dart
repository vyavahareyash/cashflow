import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/services/sync/sync_models.dart';

void main() {
  group('SyncModels Tests', () {
    test('SyncMessage serialization and deserialization', () {
      final msg = SyncMessage(
        type: 'auth',
        token: 'test-token-123',
        deviceName: 'Pixel 8',
        payload: {'status': 'ok'},
      );

      final jsonStr = msg.toJson();
      final restored = SyncMessage.fromJson(jsonStr);

      expect(restored.type, equals('auth'));
      expect(restored.token, equals('test-token-123'));
      expect(restored.deviceName, equals('Pixel 8'));
      expect((restored.payload as Map)['status'], equals('ok'));
    });

    test('SyncConnectionInfo QR serialization and roundtrip', () {
      const info = SyncConnectionInfo(
        host: '192.168.43.1',
        port: 48921,
        token: 'auth-token-xyz',
        pin: '592810',
        deviceName: 'MacBook Air',
      );

      final qrString = info.toQrString();
      final parsed = SyncConnectionInfo.fromQrString(qrString);

      expect(parsed, isNotNull);
      expect(parsed!.host, equals('192.168.43.1'));
      expect(parsed.port, equals(48921));
      expect(parsed.token, equals('auth-token-xyz'));
      expect(parsed.pin, equals('592810'));
      expect(parsed.deviceName, equals('MacBook Air'));
    });

    test('SyncConnectionInfo handles invalid QR string gracefully', () {
      expect(SyncConnectionInfo.fromQrString('not-valid-json'), isNull);
      expect(SyncConnectionInfo.fromQrString('{"v":1}'), isNull);
    });
  });
}
