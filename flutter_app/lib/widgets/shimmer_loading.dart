import 'package:flutter/material.dart';

/// Reusable shimmer/skeleton loader widget with animated gradient sweep.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  /// Full-width card skeleton.
  static Widget card({double height = 120}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ShimmerLoading(
        width: double.infinity,
        height: height,
        borderRadius: 12,
      ),
    );
  }

  /// Circle + two lines (like a transaction row).
  static Widget listTile() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ShimmerLoading(width: 40, height: 40, borderRadius: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerLoading(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerLoading(width: 60, height: 14, borderRadius: 4),
        ],
      ),
    );
  }

  /// Large rectangle for balance display.
  static Widget balance() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ShimmerLoading(
        width: double.infinity,
        height: 100,
        borderRadius: 16,
      ),
    );
  }

  /// Square placeholder for QR code.
  static Widget qrCode({double size = 220}) {
    return Center(
      child: ShimmerLoading(
        width: size + 40,
        height: size + 60,
        borderRadius: 20,
      ),
    );
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
