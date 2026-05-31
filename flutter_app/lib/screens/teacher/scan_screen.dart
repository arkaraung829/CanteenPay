import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';
import 'package:audioplayers/audioplayers.dart';

/// Teacher QR scanner — continuous scan, mark attendance on each scan.
class TeacherScanScreen extends StatefulWidget {
  const TeacherScanScreen({super.key});

  @override
  State<TeacherScanScreen> createState() => _TeacherScanScreenState();
}

class _TeacherScanScreenState extends State<TeacherScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _processing = false;
  final List<_ScannedStudent> _scannedList = [];
  String? _error;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    _loadSchoolId();
  }

  Future<void> _loadSchoolId() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('school_id')
        .eq('id', userId)
        .maybeSingle();
    _schoolId = profile?['school_id'];
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    var qrData = barcode!.rawValue!.trim();
    const prefix = 'paynowmm://pay/';
    if (qrData.startsWith(prefix)) qrData = qrData.substring(prefix.length);

    // Skip if already scanned
    if (_scannedList.any((s) => s.qrData == qrData)) return;

    _processing = true;
    setState(() => _error = null);

    try {
      final student = await SupabaseService.instance.getStudentByQr(qrData);
      if (student == null) {
        HapticFeedback.vibrate();
        setState(() => _error = 'Student not found');
        _processing = false;
        return;
      }

      // Mark attendance as present
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      try {
        await Supabase.instance.client.from('attendance').upsert({
          'student_id': student.id,
          'school_id': _schoolId,
          'date': dateStr,
          'status': 'present',
          'marked_by': userId,
        }, onConflict: 'student_id,date');
      } catch (e) {
        debugPrint('Attendance upsert failed: $e');
      }

      // Success feedback
      HapticFeedback.heavyImpact();
      // Play beep sound (works even in silent mode)
      try {
        await _audioPlayer.play(AssetSource('sounds/beep.wav'));
      } catch (_) {}

      setState(() {
        _scannedList.insert(0, _ScannedStudent(
          qrData: qrData,
          name: student.displayName,
          nameMy: student.fullNameMy,
          code: student.studentCode,
          gradeClass: student.gradeAndClass,
          time: DateTime.now(),
        ));
      });
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() => _error = 'Error: $e');
    }

    _processing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        actions: [
          if (_scannedList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_scannedList.length} scanned',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera scanner — always visible
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                if (_processing)
                  const Center(child: CircularProgressIndicator(color: Colors.white)),
                // Scan frame overlay
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.error.withValues(alpha: 0.1),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13), textAlign: TextAlign.center),
            ),

          // Instruction or latest scan
          if (_scannedList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Scan student QR to mark present',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  Text('ကျောင်းသား QR စကန်ဖတ်ပြီး ကျောင်းတက်မှတ်ပါ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),

          // Scanned students list
          if (_scannedList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('Marked Present', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_scannedList.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _scannedList.length,
              itemBuilder: (context, index) {
                final s = _scannedList[index];
                final timeStr = '${s.time.hour.toString().padLeft(2, '0')}:${s.time.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('${s.gradeClass} · ${s.code}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500)),
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
}

class _ScannedStudent {
  final String qrData;
  final String name;
  final String? nameMy;
  final String code;
  final String gradeClass;
  final DateTime time;

  _ScannedStudent({
    required this.qrData,
    required this.name,
    this.nameMy,
    required this.code,
    required this.gradeClass,
    required this.time,
  });
}
