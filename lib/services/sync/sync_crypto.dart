import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';

class SyncCrypto {
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure URL-safe session token
  static String generateSessionToken([int length = 32]) {
    final values = List<int>.generate(
      length,
      (i) => _secureRandom.nextInt(256),
    );
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Generates a human-friendly 6-digit PIN
  static String generatePin() {
    final pinNumber = _secureRandom.nextInt(900000) + 100000;
    return pinNumber.toString();
  }

  /// Computes a fast SHA-256 fingerprint from a string
  static String computeFingerprint(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// Validates constant-time string equality to prevent timing attacks
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
