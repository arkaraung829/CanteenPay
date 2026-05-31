import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/locale_provider.dart';

class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final locale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.school, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(user?.displayName ?? 'Teacher',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('TEACHER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
            ),
          ),
          const SizedBox(height: 20),

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
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => context.push('/edit-profile'),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
          ),
          const SizedBox(height: 12),

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

          OutlinedButton.icon(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
          ),
        ],
      ),
    );
  }
}
