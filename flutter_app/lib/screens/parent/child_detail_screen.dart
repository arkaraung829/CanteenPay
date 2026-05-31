import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../widgets/spending_chart.dart';
import '../../widgets/attendance_calendar.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Detail view for a single child.
class ChildDetailScreen extends StatefulWidget {
  final String childId;

  const ChildDetailScreen({super.key, required this.childId});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  String get childId => widget.childId;
  bool _hasRefreshed = false;
  int _weekOffset = 0; // 0 = this week, -1 = last week, etc.
  late DateTime _attendanceMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRefreshed) {
      _hasRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChildrenProvider>().refreshChildTransactions(childId);
      });
    }
  }

  String _weekLabel(int offset) {
    if (offset == 0) return 'This Week';
    if (offset == -1) return 'Last Week';
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1 + (-offset * 7)));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.day}/${monday.month} - ${sunday.day}/${sunday.month}';
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        ShimmerLoading.balance(),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLoading(width: 140, height: 20, borderRadius: 4),
        ),
        const SizedBox(height: 8),
        ShimmerLoading.card(height: 250),
        const SizedBox(height: 24),
        for (int i = 0; i < 3; i++) ShimmerLoading.listTile(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChildrenProvider>();
    final child = provider.children.firstWhere(
      (c) => c.id == childId,
      orElse: () => StudentModel(
        id: childId,
        profileId: '',
        schoolId: '',
        studentCode: '',
        fullName: 'Unknown',
      ),
    );
    final wallet = provider.walletForChild(childId);
    final transactions = provider.getChildTransactions(childId);
    final weeklySpending = provider.getWeeklySpending(childId);
    final attendanceRecords = provider.getAttendance(childId);

    // Build attendance map for calendar (date -> status)
    final attendanceMap = <DateTime, String>{};
    for (final record in attendanceRecords) {
      final key = DateTime(record.date.year, record.date.month, record.date.day);
      attendanceMap[key] = record.status;
    }

    // Current month attendance stats
    final currentMonthAttendance = attendanceRecords.where((r) {
      return r.date.year == _attendanceMonth.year &&
          r.date.month == _attendanceMonth.month;
    }).toList();
    final presentCount = currentMonthAttendance.where((r) => r.status == 'present').length;
    final absentCount = currentMonthAttendance.where((r) => r.status == 'absent').length;
    // final lateCount removed — only present/absent used
    final totalRecorded = currentMonthAttendance.length;
    final presentPercent = totalRecorded > 0 ? (presentCount * 100 / totalRecorded).round() : 0;

    // Today's transactions only (convert UTC to local for comparison)
    final now = DateTime.now();
    final todayTxns = transactions.where((tx) {
      if (tx.createdAt == null) return false;
      final local = tx.createdAt!.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }).toList();

    // Today's total spent
    final todaySpent = todayTxns
        .where((tx) => tx.isDebit)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    if (provider.isLoading && wallet == null) {
      return Scaffold(
        appBar: AppBar(title: Text(child.displayName)),
        body: _buildLoadingSkeleton(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(child.displayName),
      ),
      body: AnimatedFadeIn(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),

            // -- Balance Card --
            if (wallet != null) BalanceCard(wallet: wallet),
            const SizedBox(height: 16),

            // -- Quick Stats Row --
            Row(
              children: [
                _QuickStat(
                  icon: Icons.today,
                  label: "Today's Spent",
                  value: CurrencyFormatter.formatMMK(todaySpent),
                  color: todaySpent > 0 ? AppTheme.error : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  value: '${todayTxns.length} today',
                  color: AppTheme.primary,
                ),
                if (child.dailySpendingLimit != null) ...[
                  const SizedBox(width: 12),
                  _QuickStat(
                    icon: Icons.tune,
                    label: 'Daily Limit',
                    value: CurrencyFormatter.formatMMK(child.dailySpendingLimit!),
                    color: Colors.orange,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // -- Student Info --
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                            ? NetworkImage(child.photoUrl!) : null,
                        child: child.photoUrl == null || child.photoUrl!.isEmpty
                            ? Text(child.displayName[0],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(child.displayName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${child.gradeAndClass} · ${child.studentCode}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (child.schoolName != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        child.schoolName!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -- Weekly Spending Chart with navigation --
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Spending',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      onPressed: () => setState(() => _weekOffset--),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Previous week',
                    ),
                    GestureDetector(
                      onTap: _weekOffset != 0 ? () => setState(() => _weekOffset = 0) : null,
                      child: Text(
                        _weekLabel(_weekOffset),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _weekOffset == 0 ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      onPressed: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Next week',
                      color: _weekOffset < 0 ? null : Colors.grey[300],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SpendingChart(
                  weeklyData: provider.getWeeklySpending(childId, weekOffset: _weekOffset),
                  weekOffset: _weekOffset,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // -- Attendance Summary --
            const Text(
              'Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuickStat(
                  icon: Icons.check_circle_outline,
                  label: 'Present',
                  value: '$presentPercent%',
                  color: AppTheme.success,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  icon: Icons.cancel_outlined,
                  label: 'Absent',
                  value: '$absentCount',
                  color: AppTheme.error,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // -- Attendance Calendar --
            AttendanceCalendar(
              attendanceMap: attendanceMap,
              selectedMonth: _attendanceMonth,
              onMonthChanged: (month) => setState(() => _attendanceMonth = month),
            ),
            const SizedBox(height: 24),

            // -- Report Card Button --
            OutlinedButton.icon(
              onPressed: () => context.push('/parent/child/$childId/report-card'),
              icon: const Icon(Icons.assignment, size: 18),
              label: const Text('Report Card'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),

            // -- Today's Activity --
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Activity (${todayTxns.length})",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (transactions.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push('/parent/child/$childId/history'),
                    child: const Text('See All', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (todayTxns.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.textHint),
                      SizedBox(height: 8),
                      Text('No transactions today',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.shadowSm,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: todayTxns.map((tx) => TransactionTile(transaction: tx)).toList(),
                ),
              ),
            const SizedBox(height: 16),

            // -- Action Buttons --
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/parent/alerts'),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Daily Limit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/parent/child/$childId/history'),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Full History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // -- Unlink Child --
            OutlinedButton.icon(
              onPressed: () => _confirmUnlink(context, child, provider),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Unlink Child'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmUnlink(BuildContext context, StudentModel child, ChildrenProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Child'),
        content: Text(
          'Remove ${child.displayName} from your account? You can re-link later with the student code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) return;
                await Supabase.instance.client
                    .from('parent_student_links')
                    .delete()
                    .eq('parent_id', userId)
                    .eq('student_id', childId);
                if (context.mounted) {
                  await provider.loadChildren(userId);
                  context.go('/parent');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to unlink: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
