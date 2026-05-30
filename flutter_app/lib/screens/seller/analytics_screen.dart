import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:canteen_common/canteen_common.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seller analytics dashboard with sales trends, peak hours, and stats.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _Period { week, month }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.week;
  bool _loading = true;
  List<_DailySales> _dailySales = [];
  List<_HourlySales> _hourlySales = [];
  int _totalAmount = 0;
  int _totalCount = 0;
  int _avgPerTransaction = 0;
  int _bestDayAmount = 0;
  String _bestDayLabel = '';
  int _peakHour = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final days = _period == _Period.week ? 7 : 30;
    final since = DateTime.now().subtract(Duration(days: days));
    final sinceISO = since.toUtc().toIso8601String();

    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('amount, created_at')
          .eq('performed_by', userId)
          .eq('type', 'purchase')
          .gte('created_at', sinceISO)
          .order('created_at', ascending: true);

      final txns = response as List;

      // Aggregate daily
      final dailyMap = <String, _DailySales>{};
      final hourCounts = List<int>.filled(24, 0);
      final hourAmounts = List<int>.filled(24, 0);
      int total = 0;

      for (final tx in txns) {
        final amount = tx['amount'] as int;
        final created = DateTime.parse(tx['created_at'] as String).toLocal();
        final dayKey =
            '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';

        dailyMap.putIfAbsent(dayKey, () => _DailySales(dayKey, 0, 0));
        dailyMap[dayKey] = _DailySales(
          dayKey,
          dailyMap[dayKey]!.amount + amount,
          dailyMap[dayKey]!.count + 1,
        );

        hourCounts[created.hour]++;
        hourAmounts[created.hour] += amount;
        total += amount;
      }

      // Fill missing days
      final allDays = <_DailySales>[];
      for (int i = days - 1; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        allDays.add(dailyMap[key] ?? _DailySales(key, 0, 0));
      }

      // Find best day
      _DailySales best = allDays.first;
      for (final d in allDays) {
        if (d.amount > best.amount) best = d;
      }

      // Find peak hour (by count)
      int peakHour = 0;
      for (int h = 1; h < 24; h++) {
        if (hourCounts[h] > hourCounts[peakHour]) peakHour = h;
      }

      // Build hourly data (school hours only: 7am-5pm)
      final hourly = <_HourlySales>[];
      for (int h = 7; h <= 17; h++) {
        hourly.add(_HourlySales(h, hourAmounts[h], hourCounts[h]));
      }

      setState(() {
        _dailySales = allDays;
        _hourlySales = hourly;
        _totalAmount = total;
        _totalCount = txns.length;
        _avgPerTransaction = txns.isEmpty ? 0 : total ~/ txns.length;
        _bestDayAmount = best.amount;
        _bestDayLabel = _formatDayLabel(best.date);
        _peakHour = peakHour;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AnalyticsScreen: $e');
      setState(() => _loading = false);
    }
  }

  String _formatDayLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final date = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final date = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      if (_period == _Period.week) {
        return weekdays[date.weekday - 1];
      }
      return '${date.day}';
    } catch (_) {
      return '';
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12AM';
    if (hour < 12) return '${hour}AM';
    if (hour == 12) return '12PM';
    return '${hour - 12}PM';
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          // Period toggle
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.week, label: Text('7D')),
              ButtonSegment(value: _Period.month, label: Text('30D')),
            ],
            selected: {_period},
            onSelectionChanged: (v) {
              setState(() => _period = v.first);
              _loadData();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // -- Summary Cards --
                  _buildSummaryCards(),
                  const SizedBox(height: 24),

                  // -- Sales Trend Chart --
                  _buildSectionTitle('Sales Trend'),
                  const SizedBox(height: 8),
                  _buildSalesTrendChart(),
                  const SizedBox(height: 24),

                  // -- Peak Hours Chart --
                  _buildSectionTitle('Peak Hours'),
                  const SizedBox(height: 8),
                  _buildPeakHoursChart(),
                  const SizedBox(height: 24),

                  // -- Insights --
                  _buildInsightsCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Sales',
            value: '${_formatAmount(_totalAmount)} MMK',
            icon: Icons.payments_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Transactions',
            value: _totalCount.toString(),
            icon: Icons.receipt_long_outlined,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTrendChart() {
    if (_dailySales.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
    }

    final maxAmount = _dailySales.fold<int>(
        0, (max, d) => d.amount > max ? d.amount : max);
    final maxY = maxAmount == 0 ? 1000.0 : maxAmount * 1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = _dailySales[group.x.toInt()];
                return BarTooltipItem(
                  '${_formatDayLabel(day.date)}\n${day.amount.toLocaleString()} MMK',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatAmount(value.toInt()),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _dailySales.length) {
                    return const SizedBox.shrink();
                  }
                  // Show every label for week, every 5th for month
                  if (_period == _Period.month && idx % 5 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatShortDay(_dailySales[idx].date),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _dailySales.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.amount.toDouble(),
                  color: AppTheme.primary,
                  width: _period == _Period.week ? 28 : 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    if (_hourlySales.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No data')));
    }

    final maxCount = _hourlySales.fold<int>(
        0, (max, h) => h.count > max ? h.count : max);
    final maxY = maxCount == 0 ? 5.0 : maxCount * 1.3;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final h = _hourlySales[group.x.toInt()];
                return BarTooltipItem(
                  '${_formatHour(h.hour)}\n${h.count} txns · ${h.amount.toLocaleString()} MMK',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _hourlySales.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatHour(_hourlySales[idx].hour),
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _hourlySales.asMap().entries.map((entry) {
            final isPeak = entry.value.hour == _peakHour;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.count.toDouble(),
                  color: isPeak ? Colors.orange : AppTheme.primary.withValues(alpha: 0.6),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _InsightRow(
            icon: Icons.trending_up,
            color: Colors.green,
            label: 'Avg per transaction',
            value: '${_avgPerTransaction.toLocaleString()} MMK',
          ),
          const Divider(height: 20),
          _InsightRow(
            icon: Icons.star_outline,
            color: Colors.amber,
            label: 'Best day',
            value: _bestDayAmount > 0
                ? '$_bestDayLabel — ${_bestDayAmount.toLocaleString()} MMK'
                : 'No sales yet',
          ),
          const Divider(height: 20),
          _InsightRow(
            icon: Icons.schedule,
            color: Colors.orange,
            label: 'Peak hour',
            value: _totalCount > 0
                ? _formatHour(_peakHour)
                : 'No data yet',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _DailySales {
  final String date;
  final int amount;
  final int count;
  const _DailySales(this.date, this.amount, this.count);
}

class _HourlySales {
  final int hour;
  final int amount;
  final int count;
  const _HourlySales(this.hour, this.amount, this.count);
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InsightRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

extension _IntLocale on int {
  String toLocaleString() {
    final str = toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
