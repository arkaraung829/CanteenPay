import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:canteen_common/canteen_common.dart';

/// Teacher QR scanner — scans student QR to view student info.
class TeacherScanScreen extends StatefulWidget {
  const TeacherScanScreen({super.key});

  @override
  State<TeacherScanScreen> createState() => _TeacherScanScreenState();
}

class _TeacherScanScreenState extends State<TeacherScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;
  StudentModel? _student;
  WalletModel? _wallet;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned || _loading) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _hasScanned = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var qrData = barcode!.rawValue!.trim();
      const prefix = 'paynowmm://pay/';
      if (qrData.startsWith(prefix)) qrData = qrData.substring(prefix.length);

      final student = await SupabaseService.instance.getStudentByQr(qrData);
      if (student == null) {
        setState(() {
          _error = 'Student not found';
          _loading = false;
        });
        _hasScanned = false;
        return;
      }

      final wallet = await SupabaseService.instance.getWallet(student.id);

      setState(() {
        _student = student;
        _wallet = wallet;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to look up student';
        _loading = false;
      });
      _hasScanned = false;
    }
  }

  void _reset() {
    setState(() {
      _student = null;
      _wallet = null;
      _error = null;
      _hasScanned = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Student QR')),
      body: _student != null ? _buildStudentInfo() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.error.withValues(alpha: 0.1),
            child: Text(_error!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Point camera at student QR code',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfo() {
    final s = _student!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Student avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            backgroundImage: s.photoUrl != null && s.photoUrl!.isNotEmpty
                ? NetworkImage(s.photoUrl!) : null,
            child: s.photoUrl == null || s.photoUrl!.isEmpty
                ? Text(s.displayName[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary))
                : null,
          ),
          const SizedBox(height: 12),
          Text(s.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (s.fullNameMy != null)
            Text(s.fullNameMy!, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 20),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _row(Icons.badge_outlined, 'Student Code', s.studentCode),
                const Divider(height: 20),
                _row(Icons.school_outlined, 'Grade & Class', s.gradeAndClass),
                if (s.schoolName != null) ...[
                  const Divider(height: 20),
                  _row(Icons.location_city_outlined, 'School', s.schoolName!),
                ],
                const Divider(height: 20),
                _row(
                  Icons.account_balance_wallet_outlined,
                  'Balance',
                  _wallet?.formattedBalance ?? '0 MMK',
                  valueColor: AppTheme.primary,
                ),
                if (s.dailySpendingLimit != null) ...[
                  const Divider(height: 20),
                  _row(Icons.tune, 'Daily Limit', '${s.dailySpendingLimit} MMK'),
                ],
                if (s.pinCode != null) ...[
                  const Divider(height: 20),
                  _row(Icons.pin_outlined, 'PIN Code', s.pinCode!),
                ],
                const Divider(height: 20),
                _row(Icons.check_circle_outline, 'Status', s.isActive ? 'Active' : 'Inactive',
                    valueColor: s.isActive ? Colors.green : AppTheme.error),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Scan another
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan Another Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87),
              textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
      ],
    );
  }
}
