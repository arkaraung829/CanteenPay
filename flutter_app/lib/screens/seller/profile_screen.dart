import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/locale_provider.dart';
import '../../widgets/animated_fade_in.dart';

/// Simple seller profile screen with real auth data.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final l10n = CanteenLocalizations.of(context)!;
    final locale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
      ),
      body: AnimatedFadeIn(
        child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // Seller avatar and name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.storefront,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'Seller',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Info cards
          _buildInfoCard(
            icon: Icons.person,
            title: 'Name',
            subtitle: user?.displayName ?? '-',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.email,
            title: 'Email',
            subtitle: user?.email ?? '-',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.badge,
            title: 'Role',
            subtitle: user?.role ?? '-',
          ),

          const SizedBox(height: 32),

          // Edit Profile
          ElevatedButton.icon(
            onPressed: () => context.push('/edit-profile'),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(l10n.editProfile),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
          ),
          const SizedBox(height: 12),

          // Refund requests
          OutlinedButton.icon(
            onPressed: () => context.push('/seller/refunds'),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Refund Requests'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
          ),
          const SizedBox(height: 12),

          // Language toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.shadowSm,
            ),
            child: ListTile(
              leading: const Icon(Icons.language, color: AppTheme.primary),
              title: Text(locale.languageCode == 'my' ? 'Myanmar' : 'English'),
              trailing: Switch(
                value: locale.languageCode == 'my',
                onChanged: (val) {
                  context.read<LocaleProvider>().setLocale(val ? const Locale('my') : const Locale('en'));
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Account Info
          OutlinedButton.icon(
            onPressed: () => context.go('/role-select'),
            icon: const Icon(Icons.info_outline),
            label: const Text('Account Info'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Sign Out button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: Text(
                l10n.signOut,
                style: const TextStyle(color: AppTheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // App version
          const Center(
            child: Text(
              'Paynow MM v1.0.0',
              style: TextStyle(
                color: AppTheme.textHint,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
