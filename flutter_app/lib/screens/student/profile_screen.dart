import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/student_provider.dart';
import '../../widgets/animated_fade_in.dart';

/// Student profile screen with real data from Supabase.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Consumer<StudentProvider>(
      builder: (context, provider, _) {
        final student = provider.currentStudent;
        final wallet = provider.wallet;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Profile')),
          body: AnimatedFadeIn(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                const SizedBox(height: AppTheme.spacingSm),

                // -- Avatar --
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      _initials(student?.displayName ?? auth.user?.displayName ?? '?'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // -- Name --
                Center(
                  child: Text(
                    student?.displayName ?? auth.user?.displayName ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Center(
                  child: Text(
                    student != null ? 'Grade ${student.gradeAndClass}' : '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // -- Info card with shadow --
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: AppTheme.shadowMd,
                  ),
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Student Code',
                        value: student?.studentCode ?? '-',
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.school_outlined,
                        label: 'Grade & Class',
                        value: student != null
                            ? 'Grade ${student.gradeAndClass}'
                            : '-',
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
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: auth.user?.email ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // -- Account Info --
                OutlinedButton.icon(
                  onPressed: () => context.go('/role-select'),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Account Info'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd - 4),

                // -- Sign out --
                OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

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
                const SizedBox(height: AppTheme.spacingMd),
              ],
            ),
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
