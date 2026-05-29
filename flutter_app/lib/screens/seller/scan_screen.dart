import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../providers/sales_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/error_card.dart';

/// Main scan screen with camera QR scanner.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _cameraController;
  bool _hasScanned = false;
  bool _hasLoadedSales = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedSales) {
      _hasLoadedSales = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated) {
          context.read<SalesProvider>().loadTodaySales(auth.user!.id);
        }
      });
    }
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

    HapticService.medium();
    _processScannedData(barcode!.rawValue!);
  }

  Future<void> _processScannedData(String qrData) async {
    if (_hasScanned) return;
    _hasScanned = true;

    final scanner = context.read<ScannerProvider>();
    await scanner.processScan(qrData);

    if (mounted) {
      if (scanner.scannedStudent != null) {
        HapticService.success();
        setState(() => _scanError = null);
        await context.push('/seller/pin-verify');
        // Returned from payment — reset for next scan
        _hasScanned = false;
      } else if (scanner.error != null) {
        HapticService.error();
        setState(() => _scanError = scanner.error);
        scanner.reset();
        _hasScanned = false; // Allow retry on error
      }
    }
  }

  /// Reset scan lock — called when returning from payment screen
  void _resetScanLock() {
    _hasScanned = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
                        'Paynow MM Seller',
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

              // Scan error displayed as ErrorCard
              if (_scanError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ErrorCard(
                    message: _scanError!,
                    onDismiss: () => setState(() => _scanError = null),
                    onRetry: () => setState(() => _scanError = null),
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

          // Today's sales summary card
          Positioned(
            bottom: 88,
            left: 24,
            right: 24,
            child: Consumer<SalesProvider>(
              builder: (context, sales, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: AppTheme.shadowMd,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: AppTheme.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Today's Sales",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatMMK(sales.totalAmount),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${sales.transactionCount} sales',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildCameraError() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off,
              color: Colors.white54,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Camera not available',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Please allow camera access in Settings',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
