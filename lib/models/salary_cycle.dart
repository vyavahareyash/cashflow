import 'package:intl/intl.dart';

/// Represents a financial cycle anchored to a configurable salary / payday date.
class SalaryCycle {
  final int salaryDay;
  final DateTime cycleStart;
  final DateTime nextCycleStart;
  final DateTime cycleEnd;
  final int daysLeftInCycle;

  const SalaryCycle({
    required this.salaryDay,
    required this.cycleStart,
    required this.nextCycleStart,
    required this.cycleEnd,
    required this.daysLeftInCycle,
  });

  /// Returns the maximum day number for a given year and month.
  static int lastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Returns the effective payday DateTime for a given year and month,
  /// clamped to the maximum days available in that month.
  static DateTime paydayForMonth(int year, int month, int salaryDay) {
    final maxDay = lastDayOfMonth(year, month);
    final day = salaryDay > maxDay ? maxDay : salaryDay;
    return DateTime(year, month, day);
  }

  /// Constructs a [SalaryCycle] based on a configured [salaryDay] (1-31) and reference [today].
  factory SalaryCycle.resolve({required int salaryDay, DateTime? today}) {
    final clampedDay = salaryDay.clamp(1, 31);
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    final currentMonthPayday = paydayForMonth(now.year, now.month, clampedDay);

    DateTime cycleStart;
    DateTime nextCycleStart;

    if (!todayDate.isBefore(currentMonthPayday)) {
      // Today is on or after this month's payday
      cycleStart = currentMonthPayday;
      nextCycleStart = paydayForMonth(now.year, now.month + 1, clampedDay);
    } else {
      // Today is before this month's payday, cycle started last month
      cycleStart = paydayForMonth(now.year, now.month - 1, clampedDay);
      nextCycleStart = currentMonthPayday;
    }

    final cycleEnd = nextCycleStart.subtract(const Duration(days: 1));
    final daysLeft = nextCycleStart.difference(todayDate).inDays;

    return SalaryCycle(
      salaryDay: clampedDay,
      cycleStart: cycleStart,
      nextCycleStart: nextCycleStart,
      cycleEnd: cycleEnd,
      daysLeftInCycle: daysLeft > 0 ? daysLeft : 0,
    );
  }

  /// Counts paydays falling strictly in `[from, to)`.
  static int countPaydaysBetween({
    required DateTime from,
    required DateTime to,
    required int salaryDay,
  }) {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    if (!fromDate.isBefore(toDate)) return 0;

    final clampedDay = salaryDay.clamp(1, 31);
    int count = 0;

    // Start checking from the month of `fromDate`
    int curYear = fromDate.year;
    int curMonth = fromDate.month;

    final endYear = toDate.year;
    final endMonth = toDate.month;

    while (curYear < endYear || (curYear == endYear && curMonth <= endMonth)) {
      final payday = paydayForMonth(curYear, curMonth, clampedDay);
      if (!payday.isBefore(fromDate) && payday.isBefore(toDate)) {
        count++;
      }
      curMonth++;
      if (curMonth > 12) {
        curMonth = 1;
        curYear++;
      }
    }

    return count;
  }

  /// Formatted cycle range, e.g. "Sep 1 – Sep 30" or "Aug 25 – Sep 24".
  String get cycleLabel {
    final fmtStart = DateFormat('MMM d').format(cycleStart);
    final fmtEnd = DateFormat('MMM d').format(cycleEnd);
    return '$fmtStart – $fmtEnd';
  }

  /// Descriptive reset countdown, e.g. "Resets in 11 days (Sep 25)".
  String get resetCountdownText {
    final nextDateFmt = DateFormat('MMM d').format(nextCycleStart);
    if (daysLeftInCycle == 0) {
      return 'Resets today';
    } else if (daysLeftInCycle == 1) {
      return 'Resets tomorrow ($nextDateFmt)';
    } else {
      return 'Resets in $daysLeftInCycle days ($nextDateFmt)';
    }
  }
}
