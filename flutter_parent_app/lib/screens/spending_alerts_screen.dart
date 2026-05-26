import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/children_provider.dart';

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
  final _thresholdController = TextEditingController(text: '2000');

  @override
  void dispose() {
    for (final c in _limitControllers.values) {
      c.dispose();
    }
    _thresholdController.dispose();
    super.dispose();
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
          const SizedBox(height: 8),
          ...children.map((child) {
            _limitControllers.putIfAbsent(
              child.id,
              () => TextEditingController(
                text: (child.dailySpendingLimit ?? 5000).toString(),
              ),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(child.displayName),
                subtitle: Text(child.gradeAndClass),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _limitControllers[child.id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'MMK',
                      isDense: true,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // Low balance threshold
          const Text(
            'Low Balance Threshold',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Warn when balance below',
                  suffixText: 'MMK',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved')),
              );
              Navigator.of(context).pop();
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
