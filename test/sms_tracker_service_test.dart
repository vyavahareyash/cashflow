import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/tracked_sms_message.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/sms_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));

    // Seed account & category
    final db = DatabaseHelper.instance;
    await db.createAccount(
      Account(
        name: 'HDFC Bank',
        type: 'Bank',
        balance: 25000.0,
        accountNumberSuffix: '1234',
      ),
    );
    await db.createCategory(Category(name: 'Food & Dining', type: 'expense'));

    await SmsTrackerService.instance.initialize();
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('SmsTrackerService Live Incoming SMS Tests', () {
    test('processIncomingSms creates a draft for valid bank SMS', () async {
      final service = SmsTrackerService.instance;
      const sender = 'AX-HDFCBK';
      const body =
          'Rs 450.00 debited from HDFC Bank A/c XX1234 at SWIGGY on 19-10-26.';
      final ts = DateTime.now().millisecondsSinceEpoch.toString();

      final added = await service.processIncomingSms(
        sender: sender,
        body: body,
        timestamp: ts,
      );

      expect(added, isTrue);
      expect(service.unreviewedDraftCount, 1);
      final pending = service.pendingSmsMessages.first;
      expect(pending.draft, isNotNull);
      expect(pending.draft!.amount, 450.0);
      expect(pending.draft!.type, 'expense');
      expect(pending.accountSuffix, '1234');
    });

    test('processIncomingSms skips OTP and promo messages', () async {
      final service = SmsTrackerService.instance;
      const sender = 'AX-HDFCBK';
      const otpBody =
          '123456 is your secret OTP for transaction at Swiggy. Do not share.';
      final ts = DateTime.now().millisecondsSinceEpoch.toString();

      final added = await service.processIncomingSms(
        sender: sender,
        body: otpBody,
        timestamp: ts,
      );

      expect(added, isFalse);
      expect(service.unreviewedDraftCount, 0);
    });

    test('processIncomingSms deduplicates identical SMS messages', () async {
      final service = SmsTrackerService.instance;
      const sender = 'AX-HDFCBK';
      const body =
          'Rs 200.00 debited from HDFC Bank A/c XX1234 at CAFE on 19-10-26.';
      const ts = '1697720000000';

      final first = await service.processIncomingSms(
        sender: sender,
        body: body,
        timestamp: ts,
      );
      expect(first, isTrue);
      expect(service.unreviewedDraftCount, 1);

      final second = await service.processIncomingSms(
        sender: sender,
        body: body,
        timestamp: ts,
      );
      expect(second, isFalse);
      expect(service.unreviewedDraftCount, 1);
    });

    test('onLiveDraftCreated emits when valid bank SMS is received via channel', () async {
      final service = SmsTrackerService.instance;
      const sender = 'AX-HDFCBK';
      const body =
          'Rs 750.00 debited from HDFC Bank A/c XX1234 at ZOMATO on 19-10-26.';
      final ts = DateTime.now().millisecondsSinceEpoch.toString();

      TrackedSmsMessage? emittedMessage;
      final sub = service.onLiveDraftCreated.listen((msg) {
        emittedMessage = msg;
      });

      // Simulate native calling onSmsReceived on MethodChannel
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final callData = const StandardMethodCodec().encodeMethodCall(
        MethodCall('onSmsReceived', {
          'sender': sender,
          'body': body,
          'timestamp': ts,
        }),
      );

      await messenger.handlePlatformMessage(
        'com.vyavahareyash.cashflow/sms',
        callData,
        (data) {},
      );

      // Allow microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emittedMessage, isNotNull);
      expect(emittedMessage!.draft?.amount, 750.0);
      expect(emittedMessage!.sender, sender);

      await sub.cancel();
    });

    test(
      'onOpenDraftsRequested emits when openSmsDrafts is called via channel',
      () async {
        final service = SmsTrackerService.instance;
        bool requested = false;
        final sub = service.onOpenDraftsRequested.listen((_) {
          requested = true;
        });

        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final callData = const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openSmsDrafts', null),
        );

        await messenger.handlePlatformMessage(
          'com.vyavahareyash.cashflow/sms',
          callData,
          (data) {},
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(requested, isTrue);
        await sub.cancel();
      },
    );

    test('startupDraftCount can be tracked and consumed', () {
      final service = SmsTrackerService.instance;
      expect(service.startupDraftCount, 0);

      service.consumeStartupDraftCount();
      expect(service.startupDraftCount, 0);
    });

    test('dismissed draft does not reappear on subsequent incoming scan', () async {
      final service = SmsTrackerService.instance;
      const sender = 'AX-HDFCBK';
      const body =
          'Rs 300.00 debited from HDFC Bank A/c XX1234 at PHARMACY on 19-10-26.';
      const ts = '1697730000000';

      final added = await service.processIncomingSms(
        sender: sender,
        body: body,
        timestamp: ts,
      );
      expect(added, isTrue);
      expect(service.unreviewedDraftCount, 1);

      final msgId = service.pendingSmsMessages.first.id;

      // Discard / dismiss the draft
      await service.dismissMessage(msgId);
      expect(service.unreviewedDraftCount, 0);

      // Re-scan same message (e.g. startup catch-up scan)
      final readded = await service.processIncomingSms(
        sender: sender,
        body: body,
        timestamp: ts,
      );
      expect(readded, isFalse);
      expect(service.unreviewedDraftCount, 0);
    });
  });
}
