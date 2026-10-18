import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/draft_transaction.dart';
import '../models/tracked_sms_message.dart';
import 'database_helper.dart';
import 'model_management_service.dart';
import 'slm_inference_service.dart';
import 'sms_extraction_service.dart';

/// Coordinator service managing Android SMS scanning, permissions,
/// deduplication, and staging of DraftTransactions.
class SmsTrackerService extends ChangeNotifier {
  static final SmsTrackerService instance = SmsTrackerService._init();

  static const MethodChannel _channel = MethodChannel(
    'com.vyavahareyash.cashflow/sms',
  );

  bool _isTrackingEnabled = false;
  bool get isTrackingEnabled => _isTrackingEnabled;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _useSlm = true;
  bool get useSlm => _useSlm;

  SlmInferenceService? _slmInferenceService;

  @visibleForTesting
  void setSlmServiceForTesting(SlmInferenceService? service) {
    _slmInferenceService = service;
  }

  SlmInferenceService get slmInferenceService => _slmInferenceService ??=
      SlmInferenceService(modelService: ModelManagementService.instance);

  bool get isSlmDownloaded =>
      ModelManagementService.instance.status == ModelPackStatus.installed;

  bool get isSlmActive => _useSlm && isSlmDownloaded;

  List<TrackedSmsMessage> _pendingSmsMessages = [];
  List<TrackedSmsMessage> get pendingSmsMessages => _pendingSmsMessages;

  int get unreviewedDraftCount =>
      _pendingSmsMessages.where((m) => m.draft != null).length;

  SmsTrackerService._init() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// Initializes settings and loads pending messages from the local SQLite database.
  Future<void> initialize() async {
    final enabledSetting = await DatabaseHelper.instance.getSetting(
      'sms_tracking_enabled',
    );
    _isTrackingEnabled = enabledSetting == '1';
    final slmSetting = await DatabaseHelper.instance.getSmsUseSlm();
    _useSlm = slmSetting;
    await refreshPendingMessages();
  }

  /// Toggles whether SLM is used for SMS extraction when downloaded.
  Future<void> setUseSlm(bool enabled) async {
    _useSlm = enabled;
    await DatabaseHelper.instance.setSmsUseSlm(enabled);
    notifyListeners();
  }

  /// Refreshes in-memory pending tracked SMS messages from SQLite.
  Future<void> refreshPendingMessages() async {
    _pendingSmsMessages = await DatabaseHelper.instance
        .readPendingTrackedSmsMessages();
    notifyListeners();
  }

  /// Toggles whether SMS tracking is enabled.
  Future<void> setTrackingEnabled(bool enabled) async {
    _isTrackingEnabled = enabled;
    await DatabaseHelper.instance.setSetting(
      'sms_tracking_enabled',
      enabled ? '1' : '0',
    );
    notifyListeners();
  }

  /// Handles incoming calls from native Android (e.g. BroadcastReceiver trigger).
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null) {
        final sender = args['sender']?.toString() ?? '';
        final body = args['body']?.toString() ?? '';
        final timestamp =
            args['timestamp']?.toString() ?? DateTime.now().toIso8601String();
        await processIncomingSms(
          sender: sender,
          body: body,
          timestamp: timestamp,
        );
      }
    }
    return null;
  }

  /// Requests SMS permissions on Android.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if SMS permissions are granted.
  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasPermissions');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Scans the Android SMS inbox for the last [days] days, or within [startDate] and [endDate].
  Future<int> scanInbox({
    int days = 14,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kIsWeb) return 0;
    _isScanning = true;
    notifyListeners();

    int newlyAdded = 0;
    try {
      final params = <String, dynamic>{'days': days};
      if (startDate != null) {
        params['startTimestamp'] = startDate.millisecondsSinceEpoch;
      }
      if (endDate != null) {
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        // Only constrain upper bound if end date is strictly in the past
        if (endDate.isBefore(startOfToday)) {
          final endOfDay = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
            999,
          );
          params['endTimestamp'] = endOfDay.millisecondsSinceEpoch;
        }
      }

      final messages = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'readInboxMessages',
        params,
      );

      if (messages != null) {
        for (final m in messages) {
          final sender = m['sender']?.toString() ?? '';
          final body = m['body']?.toString() ?? '';
          final timestamp =
              m['timestamp']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString();

          final added = await processIncomingSms(
            sender: sender,
            body: body,
            timestamp: timestamp,
          );
          if (added) newlyAdded++;
        }
      }
    } catch (_) {
      // Platform channels not supported on this platform/desktop test harness
    } finally {
      _isScanning = false;
      await refreshPendingMessages();
    }

    return newlyAdded;
  }

  /// Processes an individual SMS message offline, hashes it for deduplication,
  /// parses financial data, generates a DraftTransaction, and stores it in SQLite.
  Future<bool> processIncomingSms({
    required String sender,
    required String body,
    required String timestamp,
  }) async {
    if (!SmsExtractionService.isLikelyBankSender(sender)) {
      return false;
    }

    final id = SmsExtractionService.computeSmsHash(sender, body, timestamp);

    // 1. Check deduplication store - only deduplicate against committed (approved) or pending transactions
    final existing = await DatabaseHelper.instance.readTrackedSmsMessage(id);
    if (existing != null) {
      if (existing.status == TrackedSmsStatus.committed ||
          existing.status == TrackedSmsStatus.pending) {
        return false;
      }
      // If previously dismissed, delete stale record so it can be re-scanned and drafted
      await DatabaseHelper.instance.deleteTrackedSmsMessage(id);
    }

    // Resolve fallback date from SMS arrival timestamp
    DateTime? fallbackDate;
    final epochMs = int.tryParse(timestamp);
    if (epochMs != null) {
      fallbackDate = DateTime.fromMillisecondsSinceEpoch(epochMs);
    } else {
      fallbackDate = DateTime.tryParse(timestamp);
    }
    final effectiveAnchor = fallbackDate ?? DateTime.now();

    // Query active accounts & categories
    final accounts = await DatabaseHelper.instance.readAllAccounts();
    final categories = await DatabaseHelper.instance.readAllCategories();

    DraftTransaction? draft;
    ParsedSmsEntity? entity;
    bool isFinancial = true;

    // 2. Use SLM path if SLM is downloaded and enabled
    if (isSlmActive) {
      try {
        final slmResult = await SmsExtractionService.parseSmsWithSlm(
          smsBody: body,
          sender: sender,
          anchorDate: effectiveAnchor,
          accounts: accounts,
          categories: categories,
          slmService: slmInferenceService,
        );
        if (slmResult != null) {
          if (!slmResult.isFinancial) {
            isFinancial = false;
          } else {
            draft = slmResult.draft;
            entity = slmResult.entity;
          }
        }
      } catch (e) {
        debugPrint('SLM SMS parsing error, falling back to raw rules: $e');
        draft = null;
        entity = null;
      }
    }

    // 3. Fallback to raw regex rules if SLM was not active, returned null, or encountered error
    if (draft == null && isFinancial) {
      entity = SmsExtractionService.parseSmsText(
        body,
        fallbackDate: fallbackDate,
      );
      if (!entity.isFinancial) {
        isFinancial = false;
      } else {
        draft = SmsExtractionService.buildDraftTransaction(
          entity: entity,
          accounts: accounts,
          categories: categories,
          rawSms: body,
        );
      }
    }

    if (!isFinancial || draft == null || entity == null) {
      final unparseableMsg = TrackedSmsMessage(
        id: id,
        sender: sender,
        rawBody: body,
        receivedAt: timestamp,
        status: TrackedSmsStatus.unparseable,
      );
      await DatabaseHelper.instance.insertTrackedSmsMessage(unparseableMsg);
      return false;
    }

    // 4. Check for self-transfer pairing across pending messages
    if (entity.referenceNumber != null && entity.referenceNumber!.isNotEmpty) {
      TrackedSmsMessage? matchingPair;
      for (final pending in _pendingSmsMessages) {
        if (pending.draft != null &&
            pending.draft!.amount == entity.amount &&
            pending.rawBody.contains(entity.referenceNumber!)) {
          final isOpposite =
              (pending.draft!.isExpense && entity.type == 'income') ||
              (pending.draft!.isIncome && entity.type == 'expense');
          if (isOpposite) {
            matchingPair = pending;
            break;
          }
        }
      }

      if (matchingPair != null && matchingPair.draft != null) {
        final existingDraft = matchingPair.draft!;
        int? sourceAccountId;
        int? destAccountId;

        if (existingDraft.isExpense && entity.type == 'income') {
          sourceAccountId = existingDraft.accountId;
          destAccountId = draft.accountId;
        } else if (existingDraft.isIncome && entity.type == 'expense') {
          sourceAccountId = draft.accountId;
          destAccountId = existingDraft.accountId;
        }

        if (sourceAccountId != null &&
            destAccountId != null &&
            sourceAccountId != destAccountId) {
          final mergedDraft = existingDraft.copyWith(
            type: 'transfer',
            accountId: sourceAccountId,
            destinationAccountId: destAccountId,
            categoryId: null,
            note: 'Transfer between accounts (Ref ${entity.referenceNumber})',
            hasUnassignedAccount: false,
            hasUnassignedCategory: false,
          );

          await DatabaseHelper.instance.updateTrackedSmsDraft(
            matchingPair.id,
            mergedDraft,
          );

          final companionMsg = TrackedSmsMessage(
            id: id,
            sender: sender,
            rawBody: body,
            receivedAt: timestamp,
            status: TrackedSmsStatus.dismissed,
            accountSuffix: entity.accountSuffix,
            merchant: entity.merchant,
          );
          await DatabaseHelper.instance.insertTrackedSmsMessage(companionMsg);
          await refreshPendingMessages();
          return true;
        }
      }
    }

    // 5. Save to local SQLite deduplication & staging table
    final trackedMsg = TrackedSmsMessage(
      id: id,
      sender: sender,
      rawBody: body,
      receivedAt: timestamp,
      status: TrackedSmsStatus.pending,
      draft: draft,
      accountSuffix: entity.accountSuffix,
      merchant: entity.merchant,
    );

    await DatabaseHelper.instance.insertTrackedSmsMessage(trackedMsg);
    await refreshPendingMessages();
    return true;
  }

  /// Approves and commits an SMS draft to the official database.
  Future<void> commitDraft(
    TrackedSmsMessage message,
    DraftTransaction editedDraft,
  ) async {
    if (!editedDraft.isValid) return;

    final txModel = editedDraft.toTransactionModel();
    await DatabaseHelper.instance.createTransaction(txModel);
    await DatabaseHelper.instance.updateTrackedSmsStatus(
      message.id,
      TrackedSmsStatus.committed,
    );
    await refreshPendingMessages();
  }

  /// Dismisses an SMS draft so it is removed from pending, allowing re-scanning later if requested.
  Future<void> dismissMessage(String id) async {
    await DatabaseHelper.instance.deleteTrackedSmsMessage(id);
    await refreshPendingMessages();
  }
}
