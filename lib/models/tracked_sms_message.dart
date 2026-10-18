import 'dart:convert';

import 'draft_transaction.dart';

/// Represents the review status of a tracked financial SMS message.
enum TrackedSmsStatus { pending, committed, dismissed, unparseable }

/// Represents an SMS message evaluated by the local SMS tracker.
class TrackedSmsMessage {
  final String id; // Hash or message identifier
  final String sender;
  final String rawBody;
  final String receivedAt; // ISO 8601 string or timestamp
  final TrackedSmsStatus status;
  final DraftTransaction? draft;
  final String? accountSuffix; // e.g., '1234'
  final String? merchant;

  TrackedSmsMessage({
    required this.id,
    required this.sender,
    required this.rawBody,
    required this.receivedAt,
    this.status = TrackedSmsStatus.pending,
    this.draft,
    this.accountSuffix,
    this.merchant,
  });

  bool get isPending => status == TrackedSmsStatus.pending;
  bool get isCommitted => status == TrackedSmsStatus.committed;
  bool get isDismissed => status == TrackedSmsStatus.dismissed;
  bool get isUnparseable => status == TrackedSmsStatus.unparseable;

  TrackedSmsMessage copyWith({
    String? id,
    String? sender,
    String? rawBody,
    String? receivedAt,
    TrackedSmsStatus? status,
    DraftTransaction? draft,
    String? accountSuffix,
    String? merchant,
  }) {
    return TrackedSmsMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      rawBody: rawBody ?? this.rawBody,
      receivedAt: receivedAt ?? this.receivedAt,
      status: status ?? this.status,
      draft: draft ?? this.draft,
      accountSuffix: accountSuffix ?? this.accountSuffix,
      merchant: merchant ?? this.merchant,
    );
  }

  factory TrackedSmsMessage.fromMap(Map<String, dynamic> map) {
    TrackedSmsStatus parsedStatus;
    switch (map['status']) {
      case 'committed':
        parsedStatus = TrackedSmsStatus.committed;
        break;
      case 'dismissed':
        parsedStatus = TrackedSmsStatus.dismissed;
        break;
      case 'unparseable':
        parsedStatus = TrackedSmsStatus.unparseable;
        break;
      case 'pending':
      default:
        parsedStatus = TrackedSmsStatus.pending;
        break;
    }

    DraftTransaction? parsedDraft;
    if (map['draft_json'] != null && map['draft_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['draft_json'] as String);
        if (decoded is Map<String, dynamic>) {
          parsedDraft = DraftTransaction.fromMap(decoded);
        }
      } catch (_) {
        parsedDraft = null;
      }
    }

    return TrackedSmsMessage(
      id: map['id'] as String,
      sender: map['sender'] as String? ?? '',
      rawBody: map['raw_body'] as String? ?? '',
      receivedAt: map['received_at'] as String? ?? '',
      status: parsedStatus,
      draft: parsedDraft,
      accountSuffix: map['account_suffix'] as String?,
      merchant: map['merchant'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'raw_body': rawBody,
      'received_at': receivedAt,
      'status': status.name,
      'draft_json': draft != null ? jsonEncode(draft!.toMap()) : null,
      'account_suffix': accountSuffix,
      'merchant': merchant,
    };
  }
}
