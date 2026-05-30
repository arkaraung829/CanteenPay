import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/animated_fade_in.dart';

/// Parent profile screen with real auth data.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final children = context.watch<ChildrenProvider>().children;
    final l10n = CanteenLocalizations.of(context)!;
    final locale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: AnimatedFadeIn(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            const SizedBox(height: AppTheme.spacingSm),
            // Parent info
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary,
                child:
                    const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Center(
              child: Text(
                user?.displayName ?? 'Parent',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(l10n.email),
                    subtitle: Text(user?.email ?? '-'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Phone'),
                    subtitle: Text(user?.phone ?? '-'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Edit Profile button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/edit-profile'),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(l10n.editProfile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Linked children
            const Text(
              'Linked Children',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            if (children.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: const Text(
                  'No children linked yet. Use "Link Child" to add one.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...children.map((child) {
                final wallet = context.watch<ChildrenProvider>().walletForChild(child.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: ListTile(
                    onTap: () => _showChildInfo(context, child, wallet),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        child.displayName[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    title: Text(child.displayName),
                    subtitle: Text(child.gradeAndClass),
                    trailing: Text(
                      wallet?.formattedBalance ?? '0 MMK',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppTheme.spacingLg),

            // Chat with school
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/parent/chat'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat with School'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

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
            const SizedBox(height: AppTheme.spacingMd),

            // Account Info
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

            // Sign out
            OutlinedButton.icon(
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChildInfo(BuildContext context, StudentModel child, WalletModel? wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Avatar + name
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                  ? NetworkImage(child.photoUrl!) : null,
              child: child.photoUrl == null || child.photoUrl!.isEmpty
                  ? Text(child.displayName[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(child.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (child.fullNameMy != null && child.fullNameMy!.isNotEmpty)
              Text(child.fullNameMy!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 20),

            // Info rows
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.badge_outlined, 'Student Code', child.studentCode),
                  const Divider(height: 20),
                  _infoRow(Icons.school_outlined, 'Grade & Class', child.gradeAndClass),
                  if (child.schoolName != null) ...[
                    const Divider(height: 20),
                    _infoRow(Icons.location_city_outlined, 'School', child.schoolName!),
                  ],
                  const Divider(height: 20),
                  _infoRow(
                    Icons.account_balance_wallet_outlined,
                    'Balance',
                    wallet?.formattedBalance ?? '0 MMK',
                    valueColor: AppTheme.primary,
                  ),
                  if (child.dailySpendingLimit != null) ...[
                    const Divider(height: 20),
                    _infoRow(Icons.tune, 'Daily Limit', '${child.dailySpendingLimit} MMK'),
                  ],
                  if (child.pinCode != null) ...[
                    const Divider(height: 20),
                    _infoRow(Icons.pin_outlined, 'PIN Code', child.pinCode!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // View details button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/parent/child/${child.id}');
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details & History'),
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
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
