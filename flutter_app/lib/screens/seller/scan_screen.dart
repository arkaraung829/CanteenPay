import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../providers/sales_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/error_card.dart';

/// Main scan screen with camera QR scanner.
class ScanScreen extends StatefulWidget {
  /// Set to true to auto-start scanner (e.g. after "Scan Next")
  static bool autoStartScanner = false;

  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _cameraController;
  bool _hasScanned = false;
  bool _hasLoadedSales = false;
  bool _scannerActive = false;
  String? _scanError;
  int _pendingRefundCount = 0;

  @override
  void initState() {
    super.initState();
    if (ScanScreen.autoStartScanner) {
      ScanScreen.autoStartScanner = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedSales) {
      _hasLoadedSales = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated && auth.user != null) {
          context.read<SalesProvider>().loadTodaySales(auth.user!.id);
          _loadPendingRefundCount();
        }
      });
    }
  }

  Future<void> _loadPendingRefundCount() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final seller = await supabase
          .from('canteen_sellers')
          .select('id')
          .eq('profile_id', userId)
          .maybeSingle();

      if (seller == null) return;

      final data = await supabase
          .from('refund_requests')
          .select('id')
          .eq('seller_id', seller['id'])
          .eq('status', 'pending');

      if (mounted) {
        setState(() => _pendingRefundCount = (data as List).length);
      }
    } catch (e) {
      debugPrint('ScanScreen: failed to load refund count: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _startScanner() {
    _cameraController?.dispose();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _scannerActive = true;
      _hasScanned = false;
      _scanError = null;
    });
  }

  void _stopScanner() {
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _scannerActive = false;
      _hasScanned = false;
      _scanError = null;
    });
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
        await context.push('/seller/payment-confirm');
        // Returned from payment — reset for next scan
        if (mounted) {
          setState(() {
            _hasScanned = false;
          });
        }
      } else if (scanner.error != null) {
        HapticService.error();
        setState(() {
          _scanError = scanner.error;
          _hasScanned = false;
        });
        scanner.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CanteenLocalizations.of(context)!;

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
                    Expanded(
                      child: Text(
                        '${l10n.appTitle} ${l10n.seller}',
                        style: const TextStyle(
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
                    const SizedBox(width: 8),
                    // Refund requests badge
                    GestureDetector(
                      onTap: () async {
                        await context.push('/seller/refunds');
                        if (mounted) _loadPendingRefundCount();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 24),
                          if (_pendingRefundCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  '$_pendingRefundCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/seller/notifications'),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
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
                    onRetry: () => setState(() {
                      _scanError = null;
                      _hasScanned = false;
                    }),
                  ),
                ),

              // Scanner area or button
              Expanded(
                child: _scannerActive
                    ? _buildScannerView()
                    : _buildScanButton(),
              ),
            ],
          ),

          // Today's sales summary card — only show when scanner is active (not covering the scan button)
          if (_scannerActive) Positioned(
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
                            Text(
                              l10n.todaySales,
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

  Widget _buildScanButton() {
    final l10n = CanteenLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 56,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.readyToScan,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapToScan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _startScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.scanStudentQr),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    final l10n = CanteenLocalizations.of(context)!;
    return Stack(
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
            l10n.pointCameraAtQr,
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

        // Stop scanning button
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _stopScanner,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      l10n.stopScanning,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
