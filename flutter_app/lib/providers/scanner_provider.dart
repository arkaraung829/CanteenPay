import 'package:flutter/foundation.dart';
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

  /// Process a scanned QR code.
  ///
  /// For the prototype, this simulates looking up a student from QR data
  /// and creating demo models.
  Future<void> processScan(String qrData) async {
    _isProcessing = true;
    _error = null;
    _scanResult = qrData;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 600));

      // Demo: create a simulated student from QR data
      _scannedStudent = StudentModel(
        id: 'student-001',
        profileId: 'profile-001',
        schoolId: 'school-001',
        studentCode: 'STU-2024-001',
        qrData: qrData,
        fullName: 'Aung Kyaw Moe',
        className: 'Grade 8',
        grade: 'Section A',
        enrollmentYear: 2024,
        isActive: true,
        dailySpendingLimit: 10000,
      );

      _scannedWallet = WalletModel(
        id: 'wallet-001',
        studentId: 'student-001',
        balance: 15000,
        currency: 'MMK',
        isFrozen: false,
        updatedAt: DateTime.now(),
      );

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
