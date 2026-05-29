import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../widgets/animated_fade_in.dart';

/// Parent profile screen with real auth data.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final children = context.watch<ChildrenProvider>().children;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                    title: const Text('Email'),
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
                label: const Text('Edit Profile'),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: ListTile(
                    onTap: () => context.push('/parent/child/${child.id}'),
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
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              }),
            const SizedBox(height: AppTheme.spacingLg),

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
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppTheme.error),
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
}
