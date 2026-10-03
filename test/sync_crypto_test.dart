import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/services/sync/sync_crypto.dart';

void main() {
  group('SyncCrypto Tests', () {
    test('generateSessionToken produces unique non-empty tokens', () {
      final token1 = SyncCrypto.generateSessionToken();
      final token2 = SyncCrypto.generateSessionToken();

      expect(token1.isNotEmpty, isTrue);
      expect(token2.isNotEmpty, isTrue);
      expect(token1, isNot(equals(token2)));
    });

    test('generatePin produces 6-digit numeric string', () {
      final pin = SyncCrypto.generatePin();
      expect(pin.length, equals(6));
      expect(int.tryParse(pin), isNotNull);
      expect(int.parse(pin), inInclusiveRange(100000, 999999));
    });

    test('computeFingerprint generates consistent 8-character hex', () {
      final fp1 = SyncCrypto.computeFingerprint('sample-secret');
      final fp2 = SyncCrypto.computeFingerprint('sample-secret');
      final fp3 = SyncCrypto.computeFingerprint('different-secret');

      expect(fp1.length, equals(8));
      expect(fp1, equals(fp2));
      expect(fp1, isNot(equals(fp3)));
    });

    test('constantTimeEquals correctly validates matching strings', () {
      expect(SyncCrypto.constantTimeEquals('secret123', 'secret123'), isTrue);
      expect(SyncCrypto.constantTimeEquals('secret123', 'secret124'), isFalse);
      expect(SyncCrypto.constantTimeEquals('short', 'longer_string'), isFalse);
    });
  });
}
