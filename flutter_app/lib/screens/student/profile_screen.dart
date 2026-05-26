import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/student_provider.dart';
import '../../router.dart';

/// Student profile screen.
///
/// Shows student details, linked parent info, balance, and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(
      builder: (context, provider, _) {
        final student = provider.currentStudent;
        final wallet = provider.wallet;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),

              // -- Avatar --
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    _initials(student?.displayName ?? '?'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // -- Name --
              Center(
                child: Text(
                  student?.displayName ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Grade ${student?.gradeAndClass ?? ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // -- Info card --
              Card(
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Student Code',
                      value: student?.studentCode ?? '',
                    ),
                    const Divider(height: 1),
                    _InfoTile(
                      icon: Icons.school_outlined,
                      label: 'Grade & Class',
                      value: 'Grade ${student?.gradeAndClass ?? ''}',
                    ),
                    const Divider(height: 1),
                    _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Enrollment Year',
                      value: student?.enrollmentYear?.toString() ?? '-',
                    ),
                    const Divider(height: 1),
                    _InfoTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Balance',
                      value: wallet?.formattedBalance ?? '0 MMK',
                      valueColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -- Parent info --
              const Card(
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.family_restroom,
                      label: 'Linked Parent',
                      value: 'U Kyaw Soe',
                    ),
                    Divider(height: 1),
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Parent Phone',
                      value: '09-xxxxxxxx',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // -- Switch Role (Demo) --
              OutlinedButton.icon(
                onPressed: () => context.go('/role-select'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch Role (Demo)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // -- Sign out --
              OutlinedButton.icon(
                onPressed: () {
                  DemoAuth.logout();
                  context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // -- Version --
              const Center(
                child: Text(
                  'CanteenPay v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: valueColor ?? AppTheme.textPrimary,
        ),
      ),
    );
  }
}
