import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../router.dart';

/// Role selection screen for switching demo roles.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _selectRole(BuildContext context, String role) {
    DemoAuth.currentRole = role;
    context.go(DemoAuth.homePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch Role'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (DemoAuth.isLoggedIn) {
              context.go(DemoAuth.homePath);
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Select a Role',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Switch to a different role to explore the app',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _RoleCard(
              icon: Icons.school,
              label: 'Student',
              description: 'View QR code, balance, and transaction history',
              color: AppTheme.primary,
              isActive: DemoAuth.currentRole == 'student',
              onTap: () => _selectRole(context, 'student'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.family_restroom,
              label: 'Parent',
              description:
                  'Monitor children, spending alerts, and notifications',
              color: AppTheme.success,
              isActive: DemoAuth.currentRole == 'parent',
              onTap: () => _selectRole(context, 'parent'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.storefront,
              label: 'Seller',
              description: 'Scan QR codes and process canteen payments',
              color: AppTheme.secondary,
              isActive: DemoAuth.currentRole == 'seller',
              onTap: () => _selectRole(context, 'seller'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                DemoAuth.logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppTheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.grey[300]!,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
