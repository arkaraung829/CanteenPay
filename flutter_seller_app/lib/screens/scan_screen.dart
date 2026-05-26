import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../providers/scanner_provider.dart';
import '../providers/sales_provider.dart';

/// Main scan screen with camera QR scanner and bottom navigation.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  int _currentNavIndex = 0;
  MobileScannerController? _cameraController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _hasScanned = true;
    _processScannedData(barcode!.rawValue!);
  }

  Future<void> _processScannedData(String qrData) async {
    final scanner = context.read<ScannerProvider>();
    await scanner.processScan(qrData);

    if (mounted && scanner.scannedStudent != null) {
      context.push('/payment-confirm');
    }

    // Reset scan lock after navigation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _hasScanned = false);
      }
    });
  }

  void _simulateDemoScan() {
    _processScannedData('CANTEEN-STU-2024-001');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            context.push('/sales');
          } else if (index == 2) {
            context.push('/profile');
          } else {
            setState(() => _currentNavIndex = 0);
          }
        },
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        // Camera preview
        Column(
          children: [
            // App bar area
            Container(
              color: AppTheme.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 12,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'CanteenPay Seller',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Today's sales summary chip
                  Consumer<SalesProvider>(
                    builder: (context, sales, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sales.transactionCount} sales',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scanner area
            Expanded(
              child: Stack(
                children: [
                  // Camera
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: _onBarcodeDetected,
                    errorBuilder: (context, error, child) {
                      return _buildCameraError();
                    },
                  ),

                  // Scanner overlay
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Instruction text
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Point camera at student QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Demo scan button (for simulator testing)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Consumer<ScannerProvider>(
              builder: (context, scanner, _) {
                return ElevatedButton.icon(
                  onPressed: scanner.isProcessing ? null : _simulateDemoScan,
                  icon: scanner.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bug_report),
                  label: Text(
                    scanner.isProcessing ? 'Processing...' : 'Demo Scan',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraError() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera not available',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the Demo Scan button below',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _simulateDemoScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Demo Scan'),
            ),
          ],
        ),
      ),
    );
  }
}
