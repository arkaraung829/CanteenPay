import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../router.dart';

/// Parent profile screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ChildrenProvider>().children;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // Parent info
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Parent User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.email_outlined),
                  title: Text('Email'),
                  subtitle: Text('parent@example.com'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.phone_outlined),
                  title: Text('Phone'),
                  subtitle: Text('+95 9 123 456 789'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Linked children
          const Text(
            'Linked Children',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...children.map((child) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
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
          const SizedBox(height: 24),

          // Switch Role (Demo)
          OutlinedButton.icon(
            onPressed: () => context.go('/role-select'),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Switch Role (Demo)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Sign out
          OutlinedButton.icon(
            onPressed: () {
              DemoAuth.logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
