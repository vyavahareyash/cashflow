import 'package:cashflow/services/platform_database.dart';
import 'package:cashflow/services/platform_security_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Platform Database Initialization', () {
    test(
      'configurePlatformDatabase initializes databaseFactory on desktop',
      () async {
        await configurePlatformDatabase();
        expect(databaseFactory, isNotNull);
      },
    );
  });

  group('Desktop Platform Security Behavior', () {
    test('Desktop platforms bypass native auth and allow access', () async {
      final service = PlatformSecurityService.instance;

      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(await service.canAuthenticate(), isFalse);
          expect(await service.authenticate(), isTrue);
          expect(
            () async => await service.setSecureFlag(true),
            returnsNormally,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });
  });

  group('Desktop Speech-to-Text Support Checks', () {
    test(
      'formats unsupported platform error messages accurately for desktop',
      () {
        final desktopError = NativePlatformSttEngine.formatSttErrorMessage(
          'speech_not_supported',
          isWeb: false,
        );
        expect(desktopError, contains('Speech recognition is not supported'));

        final webError = NativePlatformSttEngine.formatSttErrorMessage(
          'speech_not_supported',
          isWeb: true,
        );
        expect(
          webError,
          contains('Web Speech API is not supported in this browser'),
        );
      },
    );

    test('maps unsupported platform error to SttNotSupportedException', () {
      final ex = NativePlatformSttEngine.mapSttErrorToException(
        'error_speech_not_supported',
        isWeb: false,
      );
      expect(ex, isA<SttNotSupportedException>());
      expect(ex.toString(), contains('Speech recognition is not supported'));
    });
  });

  group('Desktop Navigation & Keyboard Shortcuts', () {
    testWidgets('CallbackShortcuts is present and has bindings', (
      tester,
    ) async {
      const activator = SingleActivator(LogicalKeyboardKey.digit1);
      bool shortcutFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallbackShortcuts(
              bindings: {activator: () => shortcutFired = true},
              child: const Focus(autofocus: true, child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Structural: CallbackShortcuts widget is mounted
      expect(find.byType(CallbackShortcuts), findsOneWidget);

      // The binding map contains the activator key
      final widget = tester.widget<CallbackShortcuts>(
        find.byType(CallbackShortcuts),
      );
      expect(widget.bindings.containsKey(activator), isTrue);

      // shortcutFired starts false (no dispatch yet)
      expect(shortcutFired, isFalse);
    });
  });
}
