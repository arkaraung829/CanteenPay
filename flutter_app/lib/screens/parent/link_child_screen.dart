import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/error_card.dart';
import '../../widgets/success_animation.dart';
import '../../widgets/validated_text_field.dart';

/// Screen for linking a new child via student code.
class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen> {
  final _codeController = TextEditingController();
  final _dobController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isSearching = false;
  bool _isLinking = false;
  bool _isLinked = false;
  StudentModel? _foundStudent;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _dobController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String? _validateStudentCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Student code is required';
    }
    if (value.trim().length < 3) {
      return 'Student code is too short';
    }
    return null;
  }

  Future<void> _searchStudent() async {
    final code = _codeController.text.trim();
    final validationError = _validateStudentCode(code);
    if (validationError != null) {
      setState(() => _error = validationError);
      HapticService.error();
      return;
    }

    HapticService.selection();
    setState(() {
      _isSearching = true;
      _error = null;
      _foundStudent = null;
    });

    try {
      // Search by student code via RPC (bypasses RLS)
      final response = await Supabase.instance.client
          .rpc('find_student_by_code', params: {'p_code': code});

      final result = Map<String, dynamic>.from(response as Map);
      if (result['found'] == true) {
        HapticService.success();
        setState(() {
          _foundStudent = StudentModel.fromJson(result);
        });
      } else {
        HapticService.error();
        setState(() {
          _error = 'No student found with code "$code"';
        });
      }
    } catch (e) {
      HapticService.error();
      setState(() {
        _error = 'Search failed: $e';
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _linkChild() async {
    if (_foundStudent == null) return;

    // Verify PIN code (required)
    final enteredPin = _pinController.text.trim();
    if (enteredPin.isEmpty) {
      HapticService.error();
      setState(() => _error = 'Please enter the student\'s 4-digit PIN code');
      return;
    }
    if (enteredPin != _foundStudent!.pinCode) {
      HapticService.error();
      setState(() => _error = 'Incorrect PIN code. Please check with the school.');
      return;
    }

    // Verify parent's phone or email matches what admin registered
    final authUser = Supabase.instance.client.auth.currentUser;
    final parentPhone = authUser?.phone;
    final parentEmail = authUser?.email;
    final studentParentPhone = _foundStudent!.parentPhone;
    final studentParentEmail = _foundStudent!.parentEmail;

    bool identityMatched = false;

    // Check phone match (normalize both)
    if (studentParentPhone != null && studentParentPhone.isNotEmpty && parentPhone != null) {
      final normalizedParent = parentPhone.replaceAll(RegExp(r'[^\d]'), '');
      final normalizedStudent = studentParentPhone.replaceAll(RegExp(r'[^\d]'), '');
      if (normalizedParent.endsWith(normalizedStudent) || normalizedStudent.endsWith(normalizedParent)) {
        identityMatched = true;
      }
    }

    // Check email match
    if (!identityMatched && studentParentEmail != null && studentParentEmail.isNotEmpty && parentEmail != null) {
      // Skip fake phone emails
      if (!parentEmail.contains('phone') && !parentEmail.contains('@canteenpay.com')) {
        if (parentEmail.toLowerCase() == studentParentEmail.toLowerCase()) {
          identityMatched = true;
        }
      }
    }

    // If admin didn't register any parent contact, reject — contact school
    if ((studentParentPhone == null || studentParentPhone.isEmpty) &&
        (studentParentEmail == null || studentParentEmail.isEmpty)) {
      HapticService.error();
      setState(() => _error = 'No parent contact registered for this student. Please contact the school.');
      return;
    }

    if (!identityMatched) {
      HapticService.error();
      setState(() => _error = 'Your phone number or email does not match the registered parent. Please contact the school.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final parentId = auth.user?.id;
    if (parentId == null) {
      setState(() => _error = 'Not logged in');
      return;
    }

    HapticService.selection();
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
        HapticService.error();
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

      HapticService.success();
      setState(() {
        _isLinked = true;
        _isLinking = false;
      });
    } catch (e) {
      HapticService.error();
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
    return SingleChildScrollView(
      child: Column(
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
        ValidatedTextField(
          controller: _codeController,
          label: 'Student Code',
          prefixIcon: Icons.badge_outlined,
          textCapitalization: TextCapitalization.characters,
          validator: _validateStudentCode,
        ),
        const SizedBox(height: 16),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ErrorCard(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
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
          // PIN verification field (always required)
          const SizedBox(height: 16),
          ValidatedTextField(
            controller: _pinController,
            label: 'Student PIN Code (4 digits)',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'PIN code is required';
              }
              if (value.trim().length != 4) {
                return 'PIN code must be 4 digits';
              }
              return null;
            },
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
    ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SuccessAnimation(size: 80),
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
