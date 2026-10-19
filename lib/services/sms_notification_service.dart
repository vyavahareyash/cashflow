import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tracked_sms_message.dart';
import 'sms_tracker_service.dart';

/// Manages in-app snackbars and native notifications for SMS draft events.
class SmsNotificationService with WidgetsBindingObserver {
  static final SmsNotificationService instance = SmsNotificationService._();
  SmsNotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'com.vyavahareyash.cashflow/sms',
  );

  /// Global key for showing snackbars from anywhere in the widget tree.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Set by Dashboard to allow deep navigation into the staging sheet.
  VoidCallback? onOpenDraftsSheet;

  StreamSubscription<TrackedSmsMessage>? _liveSub;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _liveSub = SmsTrackerService.instance.onLiveDraftCreated.listen(
      _onLiveDraft,
    );

    // Watch for startup catch-up count
    SmsTrackerService.instance.addListener(_onTrackerChanged);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_liveSub?.cancel());
    SmsTrackerService.instance.removeListener(_onTrackerChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  bool get _isInForeground => _lifecycleState == AppLifecycleState.resumed;

  /// Called when SmsTrackerService notifies (covers startupDraftCount changes).
  void _onTrackerChanged() {
    final count = SmsTrackerService.instance.startupDraftCount;
    if (count > 0) {
      SmsTrackerService.instance.consumeStartupDraftCount();
      _showBatchSnackbar(count);
    }
  }

  /// Batched snackbar for startup catch-up: "3 new SMS drafts created"
  void _showBatchSnackbar(int count) {
    // Small delay to let the UI settle after startup
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () {
        final messenger = scaffoldMessengerKey.currentState;
        if (messenger == null) return;

        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sms_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count new SMS draft${count > 1 ? 's' : ''} created',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Review',
              textColor: Colors.white,
              onPressed: () => onOpenDraftsSheet?.call(),
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }),
    );
  }

  /// Individual live SMS draft (foreground -> snackbar, background -> native notification).
  void _onLiveDraft(TrackedSmsMessage message) {
    final draft = message.draft;
    if (draft == null) return;

    final amount = draft.amount.toStringAsFixed(
      draft.amount == draft.amount.roundToDouble() ? 0 : 2,
    );
    final typeLabel = draft.isExpense
        ? 'Expense'
        : draft.isIncome
        ? 'Income'
        : 'Transfer';
    final title = '₹$amount $typeLabel detected';
    final body = draft.note.isNotEmpty
        ? draft.note
        : 'From SMS — tap to review';

    if (_isInForeground) {
      _showSingleSnackbar(title, body);
    } else {
      // Background: native notification with fixed ID (replaces previous)
      unawaited(_showNativeNotification(title, body));
    }
  }

  void _showSingleSnackbar(String title, String body) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sms_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(body, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Review',
          textColor: Colors.white,
          onPressed: () => onOpenDraftsSheet?.call(),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNativeNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('showDraftNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }
}
