import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Teacher attendance screen — mark attendance for assigned classes.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _supabase = Supabase.instance.client;
  List<String> _assignedClasses = [];
  String? _selectedClass;
  List<_StudentAttendance> _students = [];
  bool _loading = true;
  bool _saving = false;
  String? _schoolId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
  }

  Future<void> _loadTeacherInfo() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final teacher = await _supabase
          .from('teachers')
          .select('assigned_classes, school_id')
          .eq('profile_id', userId)
          .maybeSingle();

      if (teacher != null && mounted) {
        final classes = List<String>.from(teacher['assigned_classes'] ?? []);
        setState(() {
          _assignedClasses = classes;
          _schoolId = teacher['school_id'];
          if (classes.isNotEmpty) {
            _selectedClass = classes.first;
          }
          _loading = false;
        });
        if (_selectedClass != null) _loadStudents();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Attendance: load teacher failed: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClass == null || _schoolId == null) return;
    setState(() => _loading = true);

    try {
      // Parse class name to get grade and section
      // Format: "Grade X-Section" or just the class_name
      final response = await _supabase
          .from('students')
          .select('id, full_name, full_name_my, student_code, class_name, grade, is_active')
          .eq('school_id', _schoolId!)
          .eq('class_name', _selectedClass!)
          .eq('is_active', true)
          .order('full_name');

      // Load existing attendance for selected date
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final studentIds = (response as List).map((s) => s['id'] as String).toList();

      Map<String, String> existingAttendance = {};
      if (studentIds.isNotEmpty) {
        final attData = await _supabase
            .from('attendance')
            .select('student_id, status')
            .eq('date', dateStr)
            .inFilter('student_id', studentIds);

        for (final a in (attData as List)) {
          existingAttendance[a['student_id']] = a['status'];
        }
      }

      setState(() {
        _students = (response).map((s) {
          final id = s['id'] as String;
          return _StudentAttendance(
            id: id,
            name: s['full_name'] ?? '',
            nameMy: s['full_name_my'],
            code: s['student_code'] ?? '',
            status: existingAttendance[id] ?? 'present',
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Attendance: load students failed: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty || _schoolId == null) return;
    setState(() => _saving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // Upsert attendance records
      final records = _students.map((s) => {
        'student_id': s.id,
        'school_id': _schoolId!,
        'date': dateStr,
        'status': s.status,
        'marked_by': userId,
      }).toList();

      await _supabase
          .from('attendance')
          .upsert(records, onConflict: 'student_id,date');

      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.error),
        );
      }
    }

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _students.where((s) => s.status == 'present').length;
    final absentCount = _students.where((s) => s.status != 'present').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          if (_students.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _saveAttendance,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading && _assignedClasses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Class selector + date
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClass,
                              isExpanded: true,
                              hint: const Text('Select class'),
                              items: _assignedClasses.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 14)),
                              )).toList(),
                              onChanged: (v) {
                                setState(() => _selectedClass = v);
                                _loadStudents();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _loadStudents();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary
                if (_students.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        _badge('$presentCount Present', Colors.green),
                        const SizedBox(width: 8),
                        _badge('$absentCount Absent', AppTheme.error),
                        const Spacer(),
                        Text('${_students.length} students', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),

                // Student list
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 8),
                                  Text('No students in this class', style: TextStyle(color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final s = _students[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: AppTheme.shadowSm,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                        child: Text(s.name.isNotEmpty ? s.name[0] : '?',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                            Text(s.code, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                          ],
                                        ),
                                      ),
                                      // Status buttons
                                      _statusButton(index, 'present', Icons.check_circle, Colors.green),
                                      const SizedBox(width: 8),
                                      _statusButton(index, 'absent', Icons.cancel, AppTheme.error),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _statusButton(int index, String status, IconData icon, Color color) {
    final isSelected = _students[index].status == status;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _students[index].status = status);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 1.5 : 1),
        ),
        child: Icon(icon, size: 20, color: isSelected ? color : Colors.grey[400]),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StudentAttendance {
  final String id;
  final String name;
  final String? nameMy;
  final String code;
  String status; // present, absent, late

  _StudentAttendance({
    required this.id,
    required this.name,
    this.nameMy,
    required this.code,
    this.status = 'present',
  });
}
