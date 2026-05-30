import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// Weekly spending bar chart (Mon-Fri) using fl_chart.
class SpendingChart extends StatelessWidget {
  /// Seven values for Mon through Sun.
  final List<double> weeklyData;
  /// 0 = this week, -1 = last week, etc.
  final int weekOffset;

  const SpendingChart({super.key, required this.weeklyData, this.weekOffset = 0});

  @override
  Widget build(BuildContext context) {
    final total = weeklyData.fold<double>(0, (sum, v) => sum + v);
    final maxVal = weeklyData.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 5000.0 : maxVal * 1.3;
    final todayIndex = weekOffset == 0 ? DateTime.now().weekday - 1 : -1; // only highlight today on current week

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Row(
          children: [
            _SummaryChip(
              label: 'This Week',
              value: CurrencyFormatter.formatMMK(total.toInt()),
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            _SummaryChip(
              label: 'Daily Avg',
              value: CurrencyFormatter.formatMMK(
                todayIndex > 0 ? (total / (todayIndex + 1)).toInt() : total.toInt(),
              ),
              color: Colors.grey[600]!,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      CurrencyFormatter.formatMMK(rod.toY.toInt()),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final idx = value.toInt();
                      if (idx < 0 || idx >= days.length) {
                        return const SizedBox.shrink();
                      }
                      final isToday = idx == todayIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          days[idx],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maxY / 3,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        _formatShort(value.toInt()),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(weeklyData.length, (i) {
                final isToday = i == todayIndex;
                final hasData = weeklyData[i] > 0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: weeklyData[i] == 0 ? 0 : weeklyData[i],
                      gradient: hasData
                          ? LinearGradient(
                              colors: isToday
                                  ? [AppTheme.primary, const Color(0xFF42A5F5)]
                                  : [const Color(0xFFEF5350), const Color(0xFFFF7043)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            )
                          : null,
                      color: hasData ? null : Colors.grey[200],
                      width: 24,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  String _formatShort(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
