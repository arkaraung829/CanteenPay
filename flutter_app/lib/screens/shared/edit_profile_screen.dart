import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../services/haptic_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    _nameController.text = user?.fullName ?? supabaseUser?.userMetadata?['full_name'] ?? '';
    _phoneController.text = user?.phone ?? supabaseUser?.phone ?? '';
    _emailController.text = user?.email ?? supabaseUser?.email ?? '';

    _nameController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
  }

  void _onChanged() {
    final user = context.read<AuthProvider>().user;
    final changed = _nameController.text.trim() != (user?.fullName ?? '') ||
        _phoneController.text.trim() != (user?.phone ?? '');
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _saving = true);
    HapticService.selection();

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('profiles').update({
        'full_name': name,
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      }).eq('id', userId);

      // Update auth metadata too
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );

      if (mounted) {
        HapticService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        HapticService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: (_saving || !_hasChanges) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _hasChanges ? AppTheme.primary : AppTheme.textHint,
                      ),
                    ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      (user?.fullName ?? 'U').isNotEmpty ? (user?.fullName ?? 'U')[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (user?.role ?? 'user').toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 1),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingXl),

            // Name
            const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(Icons.person_rounded),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Phone
            const Text('Phone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _hasChanges ? _save() : null,
              decoration: _inputDecoration(Icons.phone_rounded),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Email (read-only)
            const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              readOnly: true,
              style: TextStyle(color: AppTheme.textHint),
              decoration: _inputDecoration(Icons.email_rounded).copyWith(
                fillColor: Colors.grey[100],
                suffixIcon: const Tooltip(
                  message: 'Email cannot be changed',
                  child: Icon(Icons.lock_rounded, size: 18, color: AppTheme.textHint),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Role (read-only)
            const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: user?.role ?? '-'),
              readOnly: true,
              style: TextStyle(color: AppTheme.textHint),
              decoration: _inputDecoration(Icons.badge_rounded).copyWith(
                fillColor: Colors.grey[100],
                suffixIcon: const Tooltip(
                  message: 'Contact admin to change role',
                  child: Icon(Icons.lock_rounded, size: 18, color: AppTheme.textHint),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingXl),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Email and role can only be changed by the school admin.',
                      style: TextStyle(fontSize: 12, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    );
  }
}
