import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Reusable QR code display card.
///
/// Renders the student's QR data inside a styled white card with
/// shadow, rounded corners, and optional school name.
class QrCard extends StatelessWidget {
  final String qrData;
  final double size;
  final String? schoolName;

  const QrCard({
    super.key,
    required this.qrData,
    this.size = 240,
    this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: size,
            gapless: true,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1565C0),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: Color(0xFF212121),
            ),
          ),
          if (schoolName != null) ...[
            const SizedBox(height: 12),
            Text(
              schoolName!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
