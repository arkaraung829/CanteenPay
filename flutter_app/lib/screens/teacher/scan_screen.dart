import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';
import 'package:audioplayers/audioplayers.dart';

/// Teacher QR scanner + attendance list.
/// Scan marks student present automatically.
/// Teacher can also manually mark present/absent.
class TeacherScanScreen extends StatefulWidget {
  const TeacherScanScreen({super.key});

  @override
  State<TeacherScanScreen> createState() => _TeacherScanScreenState();
}

class _TeacherScanScreenState extends State<TeacherScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _processing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _schoolId;
  List<_StudentItem> _students = [];
  final Set<String> _scannedIds = {};

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final teacher = await _supabase
          .from('teachers')
          .select('assigned_grades, assigned_classes, school_id')
          .eq('profile_id', userId)
          .maybeSingle();

      if (teacher == null) {
        setState(() => _loading = false);
        return;
      }

      _schoolId = teacher['school_id'];
      final grades = List<String>.from(teacher['assigned_grades'] ?? []);

      // Load students for assigned grades
      var query = _supabase
          .from('students')
          .select('id, full_name, full_name_my, student_code, class_name, grade, qr_data')
          .eq('school_id', _schoolId!)
          .eq('is_active', true);

      if (grades.isNotEmpty) {
        query = query.inFilter('grade', grades);
      }

      final response = await query.order('full_name');

      // Load today's existing attendance
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
        _students = response.map<_StudentItem>((s) {
          final id = s['id'] as String;
          final existing = existingAttendance[id] ?? '';
          if (existing == 'present') _scannedIds.add(id);
          return _StudentItem(
            id: id,
            name: s['full_name'] ?? '',
            code: s['student_code'] ?? '',
            gradeClass: s['class_name'] ?? '',
            qrData: s['qr_data'] ?? '',
            status: existing,
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('ScanScreen: load failed: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    var qrData = barcode!.rawValue!.trim();
    const prefix = 'paynowmm://pay/';
    if (qrData.startsWith(prefix)) qrData = qrData.substring(prefix.length);

    // Find student in list
    final index = _students.indexWhere((s) => s.qrData == qrData);
    if (index < 0) {
      // Student not in assigned classes — try lookup
      if (_scannedIds.contains(qrData)) return; // already handled
      setState(() => _error = 'Student not in your assigned classes');
      HapticFeedback.vibrate();
      return;
    }

    // Already scanned
    if (_scannedIds.contains(_students[index].id)) return;

    _processing = true;
    setState(() => _error = null);

    // Mark present
    _scannedIds.add(_students[index].id);
    setState(() => _students[index].status = 'present');

    // Save to DB
    final userId = _supabase.auth.currentUser?.id;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await _supabase.from('attendance').upsert({
        'student_id': _students[index].id,
        'school_id': _schoolId,
        'date': dateStr,
        'status': 'present',
        'marked_by': userId,
      }, onConflict: 'student_id,date');
    } catch (e) {
      debugPrint('Attendance upsert failed: $e');
    }

    // Beep + haptic
    HapticFeedback.heavyImpact();
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.wav'));
    } catch (_) {}

    _processing = false;
  }

  void _toggleStatus(int index, String status) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _students[index].status;
      _students[index].status = current == status ? '' : status;
    });
  }

  Future<void> _saveAll() async {
    final marked = _students.where((s) => s.status.isNotEmpty).toList();
    if (marked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students marked'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    final userId = _supabase.auth.currentUser?.id;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final records = marked.map((s) => {
        'student_id': s.id,
        'school_id': _schoolId!,
        'date': dateStr,
        'status': s.status,
        'marked_by': userId,
      }).toList();

      await _supabase.from('attendance').upsert(records, onConflict: 'student_id,date');

      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${marked.length} records'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _students.where((s) => s.status == 'present').length;
    final absentCount = _students.where((s) => s.status == 'absent').length;
    final unmarkedCount = _students.where((s) => s.status.isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        actions: [
          if (_students.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _saveAll,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Camera
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      MobileScanner(controller: _controller, onDetect: _onDetect),
                      if (_processing)
                        const Center(child: CircularProgressIndicator(color: Colors.white)),
                      Center(
                        child: Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Error
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppTheme.error.withValues(alpha: 0.1),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12), textAlign: TextAlign.center),
                  ),

                // Summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      _badge('$presentCount', Colors.green, Icons.check_circle),
                      const SizedBox(width: 8),
                      _badge('$absentCount', AppTheme.error, Icons.cancel),
                      const SizedBox(width: 8),
                      if (unmarkedCount > 0)
                        _badge('$unmarkedCount', Colors.grey, Icons.remove_circle_outline),
                      const Spacer(),
                      Text('${_students.length} students', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final s = _students[index];
                      final isMarked = s.status.isNotEmpty;
                      final isPresent = s.status == 'present';
                      final isAbsent = s.status == 'absent';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMarked ? Colors.white : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPresent ? Colors.green.withValues(alpha: 0.4)
                                : isAbsent ? AppTheme.error.withValues(alpha: 0.4)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Status indicator
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green.withValues(alpha: 0.1)
                                    : isAbsent ? AppTheme.error.withValues(alpha: 0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                isPresent ? Icons.check : isAbsent ? Icons.close : Icons.remove,
                                size: 16,
                                color: isPresent ? Colors.green : isAbsent ? AppTheme.error : Colors.grey[350],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isMarked ? Colors.black87 : Colors.grey[500],
                                  )),
                                  Text('${s.gradeClass} · ${s.code}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                            // Present button
                            GestureDetector(
                              onTap: () => _toggleStatus(index, 'present'),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isPresent ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isPresent ? Colors.green : Colors.grey[isMarked ? 300 : 200]!, width: isPresent ? 1.5 : 1),
                                ),
                                child: Icon(Icons.check_circle, size: 18, color: isPresent ? Colors.green : Colors.grey[isMarked ? 400 : 300]),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Absent button
                            GestureDetector(
                              onTap: () => _toggleStatus(index, 'absent'),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isAbsent ? AppTheme.error.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isAbsent ? AppTheme.error : Colors.grey[isMarked ? 300 : 200]!, width: isAbsent ? 1.5 : 1),
                                ),
                                child: Icon(Icons.cancel, size: 18, color: isAbsent ? AppTheme.error : Colors.grey[isMarked ? 400 : 300]),
                              ),
                            ),
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

  Widget _badge(String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _StudentItem {
  final String id;
  final String name;
  final String code;
  final String gradeClass;
  final String qrData;
  String status; // '', 'present', 'absent'

  _StudentItem({
    required this.id,
    required this.name,
    required this.code,
    required this.gradeClass,
    required this.qrData,
    this.status = '',
  });
}
