import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/locale_provider.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  List<String> _assignedGrades = [];
  List<String> _assignedClasses = [];
  String? _schoolName;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
  }

  Future<void> _loadTeacherInfo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final teacher = await Supabase.instance.client
          .from('teachers')
          .select('assigned_grades, assigned_classes, schools(name)')
          .eq('profile_id', userId)
          .maybeSingle();

      if (teacher != null && mounted) {
        setState(() {
          _assignedGrades = List<String>.from(teacher['assigned_grades'] ?? []);
          _assignedClasses = List<String>.from(teacher['assigned_classes'] ?? []);
          final schools = teacher['schools'];
          _schoolName = schools is Map ? schools['name'] as String? : null;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('TeacherProfile: failed to load: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

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

          // Contact info
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
                if (_schoolName != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: const Text('School'),
                    subtitle: Text(_schoolName!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assigned grades & classes
          if (_loaded && (_assignedGrades.isNotEmpty || _assignedClasses.isNotEmpty)) ...[
            const Text('Assigned Classes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_assignedGrades.isNotEmpty) ...[
                    Text('Grades', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _assignedGrades.map((g) => Chip(
                        label: Text(g, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],
                  if (_assignedGrades.isNotEmpty && _assignedClasses.isNotEmpty)
                    const SizedBox(height: 12),
                  if (_assignedClasses.isNotEmpty) ...[
                    Text('Classes', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _assignedClasses.map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Edit Profile
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

          // Sign out
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
