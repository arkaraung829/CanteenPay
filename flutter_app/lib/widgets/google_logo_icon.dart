/// Google Logo Icon Widget
/// 
/// Displays the official Google logo with proper brand colors
import 'package:flutter/material.dart';

/// Google Logo Icon Widget
/// 
/// Displays a recognizable Google logo using Google's official brand colors
/// Colors: Blue (#4285F4), Green (#34A853), Yellow (#FBBC05), Red (#EA4335)
class GoogleLogoIcon extends StatelessWidget {
  final double size;
  
  const GoogleLogoIcon({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

/// Custom painter for Google logo
/// 
/// Draws a simplified Google "G" logo with official brand colors
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h / 2;
    final radius = w * 0.4;
    
    // Google brand colors (official)
    const blue = Color(0xFF4285F4);
    const green = Color(0xFF34A853);
    const yellow = Color(0xFFFBBC05);
    const red = Color(0xFFEA4335);
    
    // Draw a simplified multi-colored "G" shape
    // Using arcs and rectangles to create recognizable Google logo
    
    // Red top-left arc (0-90 degrees)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      -1.57, // -90 degrees (top)
      1.57, // 90 degrees
      false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * 0.25,
    );
    
    // Yellow left arc (90-180 degrees)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      0, // 0 degrees (right)
      1.57, // 90 degrees
      false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * 0.25,
    );
    
    // Blue right arc (270-360/-90 degrees)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      1.57, // 90 degrees (bottom)
      1.57, // 90 degrees
      false,
      paint..style = PaintingStyle.stroke..strokeWidth = w * 0.25,
    );
    
    // Green horizontal bar (bottom-right extension of G)
    paint.color = green;
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(centerX + radius * 0.2, centerY - w * 0.1, w * 0.35, w * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

