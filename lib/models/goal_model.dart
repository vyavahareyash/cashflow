import 'package:intl/intl.dart';
import 'salary_cycle.dart';

class Goal {
  final int? id;
  final String name;
  final double totalTarget;
  final String targetDate;
  final double currentSaved;

  Goal({
    this.id,
    required this.name,
    required this.totalTarget,
    required this.targetDate,
    required this.currentSaved,
  });

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      name: map['name'],
      totalTarget: (map['total_target'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['target_date'] ?? '',
      currentSaved: (map['current_saved'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'total_target': totalTarget,
      'target_date': targetDate,
      'current_saved': currentSaved,
    };
  }

  Goal copyWith({
    int? id,
    String? name,
    double? totalTarget,
    String? targetDate,
    double? currentSaved,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      totalTarget: totalTarget ?? this.totalTarget,
      targetDate: targetDate ?? this.targetDate,
      currentSaved: currentSaved ?? this.currentSaved,
    );
  }

  DateTime? get parsedTargetDate => DateTime.tryParse(targetDate);

  bool get isCompleted => totalTarget > 0 && currentSaved >= totalTarget;

  double get remainingAmount =>
      (totalTarget - currentSaved).clamp(0.0, double.infinity);

  double get progress =>
      totalTarget > 0 ? (currentSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

  int? daysRemaining({DateTime? today}) {
    final target = parsedTargetDate;
    if (target == null) return null;
    final now = today ?? DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDateOnly = DateTime(target.year, target.month, target.day);
    return targetDateOnly.difference(nowDate).inDays;
  }

  bool isOverdue({DateTime? today}) {
    if (isCompleted) return false;
    final days = daysRemaining(today: today);
    if (days == null) return false;
    return days < 0;
  }

  int? paydaysRemaining({DateTime? today, required int salaryDay}) {
    if (isCompleted || remainingAmount <= 0) return 0;
    final target = parsedTargetDate;
    if (target == null) return null;
    final now = today ?? DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDateOnly = DateTime(target.year, target.month, target.day);
    if (!nowDate.isBefore(targetDateOnly)) return null;

    return SalaryCycle.countPaydaysBetween(
      from: nowDate,
      to: targetDateOnly,
      salaryDay: salaryDay,
    );
  }

  double? recommendedMonthlyPace({DateTime? today, int? salaryDay}) {
    if (isCompleted || remainingAmount <= 0) return 0.0;
    final days = daysRemaining(today: today);
    if (days == null || days <= 0) return null;

    if (salaryDay != null) {
      final paydays = paydaysRemaining(today: today, salaryDay: salaryDay);
      if (paydays == null) return null;
      if (paydays <= 0) {
        return remainingAmount;
      }
      return remainingAmount / paydays;
    }

    final months = days / 30.4375;
    if (months < 1.0) {
      return remainingAmount;
    }
    return remainingAmount / months;
  }

  String? pacingAdviceText({
    DateTime? today,
    int? salaryDay,
    String Function(double amount)? currencyFormatter,
  }) {
    if (isCompleted || remainingAmount <= 0) return null;
    final days = daysRemaining(today: today);
    if (days == null || days <= 0) return null;

    final pace = recommendedMonthlyPace(today: today, salaryDay: salaryDay);
    if (pace == null) return null;

    final fmt = currencyFormatter ?? (val) => '₹${val.toStringAsFixed(0)}';

    if (salaryDay != null) {
      final paydays = paydaysRemaining(today: today, salaryDay: salaryDay);
      if (paydays == null || paydays <= 0) {
        return 'Due in $days days (0 paydays left) • Fund from existing balance';
      } else if (paydays == 1) {
        return 'Save ~${fmt(pace)} from next paycheck (1 payday left)';
      } else {
        return 'Save ~${fmt(pace)} / paycheck ($paydays paydays left)';
      }
    }

    return 'Save ~${fmt(pace)}/mo to hit target on time';
  }

  String deadlineStatusText({DateTime? today}) {
    if (isCompleted) return 'Goal Reached';
    final days = daysRemaining(today: today);
    if (days == null) return 'No target date';
    if (days < 0) {
      final overdueDays = -days;
      return overdueDays == 1
          ? 'Overdue by 1 day'
          : 'Overdue by $overdueDays days';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    if (days < 30) return '$days days left';
    final months = (days / 30.4375).round();
    if (months <= 1) return '1 month left';
    return '$months months left';
  }

  String get formattedTargetDate {
    final parsed = parsedTargetDate;
    if (parsed == null) return targetDate;
    return DateFormat('MMM dd, yyyy').format(parsed);
  }

  String get shortTargetDate {
    final parsed = parsedTargetDate;
    if (parsed == null) return targetDate;
    return DateFormat('MMM yyyy').format(parsed);
  }
}
