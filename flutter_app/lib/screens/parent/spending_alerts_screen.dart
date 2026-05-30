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

        final text = controller.text.trim();
        final newLimit = text.isEmpty ? null : int.tryParse(text);
        final currentLimit = child.dailySpendingLimit;

        // Only update if changed
        if (newLimit != currentLimit) {
          await SupabaseService.instance.updateDailySpendingLimit(
            child.id,
            newLimit,
          );
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
            _limitControllers.putIfAbsent(
              child.id,
              () => TextEditingController(
                text: child.dailySpendingLimit?.toString() ?? '',
              ),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(child.gradeAndClass, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _limitControllers[child.id],
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        suffixText: 'MMK',
                        hintText: 'No limit',
                        labelText: 'Daily Limit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
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
