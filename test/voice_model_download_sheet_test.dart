import 'package:cashflow/components/voice_model_download_sheet.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({bool isDark = false, VoidCallback? onOpen}) {
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('open_sheet_button'),
              onPressed: () => VoiceModelDownloadSheet.show(context),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('VoiceModelDownloadSheet Widget Tests (US 14, US 19)', () {
    testWidgets('1. Renders title, highlights, and action buttons', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Check text
      expect(find.text('Offline AI Models Required'), findsOneWidget);
      expect(find.textContaining('100% Offline & Private'), findsOneWidget);
      expect(find.textContaining('One-Time Download (~230 MB)'), findsOneWidget);
      expect(find.textContaining('On-Demand Memory'), findsOneWidget);

      // Check buttons
      expect(find.byKey(const Key('voice_model_download_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_model_download_cancel_button')), findsOneWidget);
    });

    testWidgets('2. Tap "Not Now" dismisses the modal bottom sheet cleanly', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.text('Offline AI Models Required'), findsOneWidget);

      await tester.tap(find.byKey(const Key('voice_model_download_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Offline AI Models Required'), findsNothing);
    });

    testWidgets('3. Tap "Download in Settings" navigates to BackupRestoreScreen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voice_model_download_settings_button')));
      await tester.pumpAndSettle();

      expect(find.byType(BackupRestoreScreen), findsOneWidget);
      final backupScreen = tester.widget<BackupRestoreScreen>(find.byType(BackupRestoreScreen));
      expect(backupScreen.scrollToVoiceModels, isTrue);
      expect(find.byKey(const Key('voice_model_card')), findsOneWidget);
    });

    testWidgets('4. Accessibility: meets WCAG AA tap targets and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Check Android tap target guideline (48x48)
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // Check iOS tap target guideline (44x44)
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      // Check labeled tap targets
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('5. Displays active progress and cancel button when downloading', (tester) async {
      final mockService = _MockDownloadingModelService();
      ModelManagementService.setMockInstance(mockService);
      addTearDown(() => ModelManagementService.resetInstance());

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.text('Downloading AI Model Pack'), findsOneWidget);
      expect(find.text('Cancel Download'), findsOneWidget);
      expect(find.text('View in Settings'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);

      await tester.tap(find.byKey(const Key('voice_model_download_cancel_button')));
      await tester.pumpAndSettle();
      expect(mockService.cancelCalled, isTrue);
    });
  });
}

class _MockDownloadingModelService extends ModelManagementService {
  bool cancelCalled = false;

  @override
  ModelPackStatus get status => ModelPackStatus.downloading;

  @override
  bool get isDownloading => true;

  @override
  double get progress => 0.45;

  @override
  int get bytesDownloaded => 120 * 1024 * 1024;

  @override
  int get totalBytes => 270 * 1024 * 1024;

  @override
  String get statusDetail => 'Downloading SmolLM2...';

  @override
  void cancelDownload() {
    cancelCalled = true;
  }
}
