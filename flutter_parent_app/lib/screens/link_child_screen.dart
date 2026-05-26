import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// Screen for linking a new child via student code.
class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isLinked = false;
  StudentModel? _linkedChild;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _linkChild() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // Simulate network call
    await Future<void>.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _isLinked = true;
      _linkedChild = StudentModel(
        id: 'child-new',
        profileId: 'profile-new',
        schoolId: 'school-001',
        studentCode: _codeController.text.trim(),
        fullName: 'New Student',
        grade: 'Grade 4',
        className: 'C',
        isActive: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Child')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLinked ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.qr_code_scanner,
          size: 64,
          color: AppTheme.primary,
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter Student Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'You can find the student code printed on your child\'s canteen card.',
          style: TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Student Code',
            hintText: 'e.g. STU-2025-003',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _linkChild,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Link Child'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 80, color: AppTheme.success),
        const SizedBox(height: 16),
        const Text(
          'Child Linked Successfully!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    _linkedChild?.displayName[0] ?? '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _linkedChild?.displayName ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _linkedChild?.gradeAndClass ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: ${_linkedChild?.studentCode ?? ''}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
