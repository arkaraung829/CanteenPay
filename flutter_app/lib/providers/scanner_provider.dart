import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:canteen_common/canteen_common.dart';

/// Manages QR scan state for the seller terminal.
class ScannerProvider extends ChangeNotifier {
  String? _scanResult;
  StudentModel? _scannedStudent;
  WalletModel? _scannedWallet;
  bool _isProcessing = false;
  String? _error;

  String? get scanResult => _scanResult;
  StudentModel? get scannedStudent => _scannedStudent;
  WalletModel? get scannedWallet => _scannedWallet;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  /// Process a scanned QR code using real Supabase lookups.
  Future<void> processScan(String qrData) async {
    _isProcessing = true;
    _error = null;
    _scanResult = qrData;
    notifyListeners();

    try {
      // Clean QR data — trim whitespace/newlines
      final cleanQr = qrData.trim();
      debugPrint('ScannerProvider: looking up QR data: "$cleanQr"');

      // Look up student by QR data
      final student = await SupabaseService.instance.getStudentByQr(cleanQr);
      if (student == null) {
        _error = 'Student not found for this QR code';
        _isProcessing = false;
        notifyListeners();
        return;
      }

      if (!student.isActive) {
        _error = 'This student account is inactive';
        _isProcessing = false;
        notifyListeners();
        return;
      }

      _scannedStudent = student;

      // Get the student's wallet
      final wallet = await SupabaseService.instance.getWallet(student.id);
      if (wallet == null) {
        _error = 'No wallet found for this student';
        _isProcessing = false;
        notifyListeners();
        return;
      }

      if (wallet.isFrozen) {
        _error = 'This wallet is frozen';
        _isProcessing = false;
        notifyListeners();
        return;
      }

      _scannedWallet = wallet;
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to look up student: $e';
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Reset scan state for next scan.
  void reset() {
    _scanResult = null;
    _scannedStudent = null;
    _scannedWallet = null;
    _isProcessing = false;
    _error = null;
    notifyListeners();
  }
}
