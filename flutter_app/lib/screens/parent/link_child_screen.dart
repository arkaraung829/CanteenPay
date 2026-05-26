import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';

/// Screen for linking a new child via student code.
class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final _codeController = TextEditingController();
  bool _isSearching = false;
  bool _isLinking = false;
  bool _isLinked = false;
  StudentModel? _foundStudent;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchStudent() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _foundStudent = null;
    });

    try {
      // Search by student code
      final response = await Supabase.instance.client
          .from('students')
          .select()
          .eq('student_code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _foundStudent = StudentModel.fromJson(response);
        });
      } else {
        setState(() {
          _error = 'No student found with code "$code"';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _linkChild() async {
    if (_foundStudent == null) return;

    final auth = context.read<AuthProvider>();
    final parentId = auth.user?.id;
    if (parentId == null) {
      setState(() => _error = 'Not logged in');
      return;
    }

    setState(() {
      _isLinking = true;
      _error = null;
    });

    try {
      // Check if already linked
      final existing = await Supabase.instance.client
          .from('parent_student_links')
          .select()
          .eq('parent_id', parentId)
          .eq('student_id', _foundStudent!.id)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          _error = 'This child is already linked to your account';
          _isLinking = false;
        });
        return;
      }

      // Insert the link
      await Supabase.instance.client.from('parent_student_links').insert({
        'parent_id': parentId,
        'student_id': _foundStudent!.id,
      });

      // Reload children in the provider
      if (mounted) {
        await context.read<ChildrenProvider>().loadChildren(parentId);
      }

      setState(() {
        _isLinked = true;
        _isLinking = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to link child: $e';
        _isLinking = false;
      });
    }
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
        const SizedBox(height: 16),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

        // Search button
        if (_foundStudent == null)
          ElevatedButton(
            onPressed: _isSearching ? null : _searchStudent,
            child: _isSearching
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Search'),
          ),

        // Found student card
        if (_foundStudent != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      _foundStudent!.displayName[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foundStudent!.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _foundStudent!.gradeAndClass,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppTheme.success),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLinking ? null : _linkChild,
            child: _isLinking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Link This Child'),
          ),
        ],
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
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    _foundStudent?.displayName[0] ?? '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _foundStudent?.displayName ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _foundStudent?.gradeAndClass ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: ${_foundStudent?.studentCode ?? ''}',
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
