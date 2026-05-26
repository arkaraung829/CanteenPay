import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/student_provider.dart';
import '../../widgets/qr_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Home screen -- the hero of the student app.
///
/// Focused on one thing: showing the QR code prominently so the
/// student can present it at the canteen counter.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        final studentProvider = context.read<StudentProvider>();
        if (auth.isAuthenticated && studentProvider.currentStudent == null) {
          studentProvider.loadStudent(auth.user!.id);
        }
      });
    }
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const ShimmerLoading(width: 180, height: 24, borderRadius: 6),
          const SizedBox(height: 8),
          const ShimmerLoading(width: 120, height: 16, borderRadius: 4),
          const SizedBox(height: 28),
          ShimmerLoading.qrCode(),
          const SizedBox(height: 20),
          const ShimmerLoading(width: 140, height: 32, borderRadius: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(
      builder: (context, provider, _) {
        final student = provider.currentStudent;
        final wallet = provider.wallet;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: provider.isLoading && student == null
                ? _buildLoadingSkeleton()
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: provider.refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedFadeIn(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),

                            // Error state
                            if (provider.error != null && student == null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                    border: Border.all(
                                      color:
                                          AppTheme.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppTheme.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          provider.error!,
                                          style: const TextStyle(
                                            color: AppTheme.error,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // -- Student info --
                            if (student != null) ...[
                              Text(
                                student.displayName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Grade ${student.gradeAndClass}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.studentCode,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.7),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),

                            // -- QR Code with shadow --
                            if (student?.qrData != null)
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppTheme.shadowLg,
                                ),
                                child: QrCard(
                                  qrData: student!.qrData!,
                                  size: 220,
                                  schoolName: 'CanteenPay',
                                ),
                              ),

                            const SizedBox(height: 20),

                            // -- Balance --
                            if (wallet != null)
                              Text(
                                wallet.formattedBalance,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),

                            const SizedBox(height: 8),

                            // -- Instruction --
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Show this QR at the canteen',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
