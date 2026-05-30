import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// A monthly calendar grid showing attendance status per day.
///
/// Days are colored:
/// - Green (AppTheme.success) = present
/// - Red (AppTheme.error) = absent
/// - Orange (Colors.orange) = late
/// - Grey (Colors.grey[200]) = no data / future
class AttendanceCalendar extends StatelessWidget {
  /// Map of date (year-month-day only) to status string.
  final Map<DateTime, String> attendanceMap;

  /// The month currently being displayed.
  final DateTime selectedMonth;

  /// Called when the user navigates to another month.
  final ValueChanged<DateTime> onMonthChanged;

  const AttendanceCalendar({
    super.key,
    required this.attendanceMap,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'late':
        return Colors.orange;
      default:
        return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = selectedMonth.year;
    final month = selectedMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon, 7=Sun
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Can't navigate past current month
    final isCurrentMonth = year == now.year && month == now.month;

    // Month label
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // -- Month header with arrows --
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: () => onMonthChanged(
                  DateTime(year, month - 1),
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous month',
              ),
              Text(
                '${months[month - 1]} $year',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                onPressed: isCurrentMonth
                    ? null
                    : () => onMonthChanged(
                          DateTime(year, month + 1),
                        ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Next month',
                color: isCurrentMonth ? Colors.grey[300] : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // -- Day-of-week labels --
          Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // -- Calendar grid --
          ...List.generate(_weekCount(firstWeekday, daysInMonth), (week) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: List.generate(7, (col) {
                  final dayIndex = week * 7 + col - (firstWeekday - 1) + 1;
                  if (dayIndex < 1 || dayIndex > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 36));
                  }

                  final date = DateTime(year, month, dayIndex);
                  final isFuture = date.isAfter(today);
                  final isToday = date == today;
                  final status = isFuture ? null : attendanceMap[date];
                  final color = isFuture ? Colors.grey[200]! : _statusColor(status);

                  return Expanded(
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dayIndex',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday ? AppTheme.primary : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  int _weekCount(int firstWeekday, int daysInMonth) {
    final totalSlots = (firstWeekday - 1) + daysInMonth;
    return (totalSlots / 7).ceil();
  }
}
