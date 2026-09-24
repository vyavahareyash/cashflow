import 'package:flutter/foundation.dart';

/// Global application configuration resolved at compile-time.
///
/// Compile-time flags are configured via `--dart-define`:
/// - `ENABLE_EXTERNAL_DONATIONS`: Set to true for GitHub/F-Droid release builds.
///   Defaults to `false` for Google Play compliance.
/// - `BUY_ME_A_COFFEE_URL`: Target URL for Buy Me a Coffee support page.
/// - `ENABLE_PLAY_STORE_TIPS`: Set to true for Google Play Store builds.
/// - `GITHUB_URL`: Target URL for source code repository.
/// - `LINKEDIN_URL`: Target URL for developer LinkedIn profile.
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

  static const bool _hasEnvPlayStoreTips =
      bool.hasEnvironment('ENABLE_PLAY_STORE_TIPS');
  static const bool _envEnablePlayStoreTips = bool.fromEnvironment(
    'ENABLE_PLAY_STORE_TIPS',
    defaultValue: true,
  );

  static const String _envGitHubUrl = String.fromEnvironment(
    'GITHUB_URL',
    defaultValue: 'https://github.com/vyavahareyash/cashflow',
  );

  static const String _envLinkedInUrl = String.fromEnvironment(
    'LINKEDIN_URL',
    defaultValue: 'https://www.linkedin.com/in/vyavahareyash',
  );

  /// Visible-for-testing override for external donations visibility.
  static bool? _overrideEnableExternalDonations;

  /// Visible-for-testing override for Play Store tips visibility.
  static bool? _overrideEnablePlayStoreTips;

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

  /// Whether Google Play Store In-App Purchases (tip jar) should be active.
  /// When external donation links are active (e.g. GitHub/F-Droid builds),
  /// Play Store IAP is disabled by default to avoid duplicate support mechanisms.
  static bool get enablePlayStoreTips {
    if (_overrideEnablePlayStoreTips != null) {
      return _overrideEnablePlayStoreTips!;
    }
    if (_hasEnvPlayStoreTips) {
      return _envEnablePlayStoreTips;
    }
    return !enableExternalDonations;
  }

  /// Target URL to open when user taps the Buy Me a Coffee button.
  static String get buyMeACoffeeUrl => _envBuyMeACoffeeUrl;

  /// Target URL for project source code repository.
  static String get gitHubUrl => _envGitHubUrl;

  /// Target URL for developer LinkedIn profile.
  static String get linkedInUrl => _envLinkedInUrl;

  /// Developer name for attribution.
  static const String developerName = 'Yash Vyavahare';

  /// Sets an override for [enableExternalDonations] during testing.
  static void setOverrideEnableExternalDonations(bool? value) {
    _overrideEnableExternalDonations = value;
  }

  /// Sets an override for [enablePlayStoreTips] during testing.
  static void setOverrideEnablePlayStoreTips(bool? value) {
    _overrideEnablePlayStoreTips = value;
  }
}
