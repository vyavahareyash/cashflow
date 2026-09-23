import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps the native Android security MethodChannel.
/// On non-Android platforms, all operations are no-ops.
class PlatformSecurityService {
  PlatformSecurityService._();
  static final PlatformSecurityService instance = PlatformSecurityService._();

  static const _channel = MethodChannel('com.vyavahareyash.cashflow/security');

  /// Whether the device supports biometric or device-credential auth.
  Future<bool> canAuthenticate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('canAuthenticate');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the native biometric / PIN / pattern prompt.
  /// Returns `true` if authentication succeeded.
  Future<bool> authenticate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod<bool>('authenticate');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enables or disables FLAG_SECURE (blocks screenshots / recent-apps preview).
  Future<void> setSecureFlag(bool enable) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setSecureFlag', {'enable': enable});
    } catch (_) {
      // Ignore on unsupported platforms
    }
  }
}
