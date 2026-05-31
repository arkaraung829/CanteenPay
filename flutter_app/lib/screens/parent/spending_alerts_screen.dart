import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';

/// Alert & spending limit settings.
class SpendingAlertsScreen extends StatefulWidget {
  const SpendingAlertsScreen({super.key});

  @override
  State<SpendingAlertsScreen> createState() => _SpendingAlertsScreenState();
}

class _SpendingAlertsScreenState extends State<SpendingAlertsScreen> {
  bool _notifyEveryPurchase = true;
  bool _dailySummary = true;
  final Map<String, TextEditingController> _limitControllers = {};
  final Map<String, bool> _limitEnabled = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _limitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final children = context.read<ChildrenProvider>().children;

      for (final child in children) {
        final controller = _limitControllers[child.id];
        if (controller == null) continue;

        final isEnabled = _limitEnabled[child.id] ?? false;
        final text = controller.text.trim();
        final newLimit = isEnabled && text.isNotEmpty ? int.tryParse(text) : null;
        final currentLimit = child.dailySpendingLimit;

        // Only update if changed
        if (newLimit != currentLimit) {
          await Supabase.instance.client.rpc('set_daily_spending_limit', params: {
            'p_student_id': child.id,
            'p_limit': newLimit,
          });
        }
      }

      if (mounted) {
        // Refresh children data to reflect updated limits
        final provider = context.read<ChildrenProvider>();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await provider.loadChildren(userId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ChildrenProvider>().children;

    return Scaffold(
      appBar: AppBar(title: const Text('Spending Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Global toggles
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Notify on every purchase'),
                  subtitle: const Text(
                      'Get alerted each time your child makes a purchase'),
                  value: _notifyEveryPurchase,
                  onChanged: (v) =>
                      setState(() => _notifyEveryPurchase = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Daily spending summary'),
                  subtitle: const Text(
                      'Receive a summary of daily spending at 6 PM'),
                  value: _dailySummary,
                  onChanged: (v) => setState(() => _dailySummary = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Per-child daily limits
          const Text(
            'Daily Spending Limit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty for no limit',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ...children.map((child) {
            final currentLimit = child.dailySpendingLimit;
            final currentLimitStr = currentLimit?.toString() ?? '';
            final hasLimit = currentLimit != null && currentLimit > 0;
            if (!_limitControllers.containsKey(child.id)) {
              _limitControllers[child.id] = TextEditingController(text: currentLimitStr);
            }
            // Track enabled state per child
            _limitEnabled.putIfAbsent(child.id, () => hasLimit);
            final isEnabled = _limitEnabled[child.id] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(child.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(child.gradeAndClass, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        // Current limit badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasLimit
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasLimit ? '${CurrencyFormatter.formatMMK(currentLimit)}/day' : 'No limit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasLimit ? AppTheme.primary : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Enable/disable toggle
                    Row(
                      children: [
                        Switch(
                          value: isEnabled,
                          activeColor: AppTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _limitEnabled[child.id] = val;
                              if (!val) {
                                _limitControllers[child.id]?.text = '';
                              } else if (_limitControllers[child.id]?.text.isEmpty ?? true) {
                                _limitControllers[child.id]?.text = currentLimitStr.isNotEmpty ? currentLimitStr : '5000';
                              }
                            });
                          },
                        ),
                        Text(
                          isEnabled ? 'Daily limit enabled' : 'No daily limit (unlimited)',
                          style: TextStyle(
                            fontSize: 14,
                            color: isEnabled ? AppTheme.textPrimary : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if (isEnabled) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _limitControllers[child.id],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          suffixText: 'MMK',
                          hintText: 'e.g. 5000',
                          labelText: 'Daily Limit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Quick amount chips
                      Wrap(
                        spacing: 8,
                        children: [3000, 5000, 10000, 20000].map((amt) {
                          final isSelected = _limitControllers[child.id]?.text == amt.toString();
                          return ActionChip(
                            label: Text(
                              CurrencyFormatter.formatMMK(amt),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.primary,
                              ),
                            ),
                            backgroundColor: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.08),
                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                            onPressed: () {
                              setState(() {
                                _limitControllers[child.id]?.text = amt.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
