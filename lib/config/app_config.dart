import 'package:flutter/foundation.dart';

/// Global application configuration resolved at compile-time.
///
/// Compile-time flags are configured via `--dart-define`:
/// - `ENABLE_EXTERNAL_DONATIONS`: Set to true for GitHub/F-Droid release builds.
///   Defaults to `false` for Google Play compliance.
/// - `BUY_ME_A_COFFEE_URL`: Target URL for Buy Me a Coffee support page.
class AppConfig {
  AppConfig._();

  static const bool _hasEnvDonations =
      bool.hasEnvironment('ENABLE_EXTERNAL_DONATIONS');
  static const bool _envEnableDonations = bool.fromEnvironment(
    'ENABLE_EXTERNAL_DONATIONS',
    defaultValue: false,
  );

  static const String _envBuyMeACoffeeUrl = String.fromEnvironment(
    'BUY_ME_A_COFFEE_URL',
    defaultValue: 'https://buymeacoffee.com/vyavahareyash',
  );

  /// Visible-for-testing override for external donations visibility.
  static bool? _overrideEnableExternalDonations;

  /// Whether external donation/support links should be rendered in UI.
  /// Automatically active in debug mode (local emulators) for easy previewing.
  /// Strictly requires explicit flag in release builds.
  static bool get enableExternalDonations {
    if (_overrideEnableExternalDonations != null) {
      return _overrideEnableExternalDonations!;
    }
    if (_hasEnvDonations) {
      return _envEnableDonations;
    }
    return kDebugMode;
  }

  /// Target URL to open when user taps the Buy Me a Coffee button.
  static String get buyMeACoffeeUrl => _envBuyMeACoffeeUrl;

  /// Sets an override for [enableExternalDonations] during testing.
  static void setOverrideEnableExternalDonations(bool? value) {
    _overrideEnableExternalDonations = value;
  }
}
