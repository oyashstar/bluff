import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/async_value_widget.dart';
import 'dashboard_providers.dart';

/// Closed tickets by root cause over time. If "Training gap" dominates, the fix
/// is documentation, not code. Reads v_root_cause_mix.
class RootCauseMixScreen extends ConsumerWidget {
  const RootCauseMixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(rootCauseMixProvider);
    final monthFmt = DateFormat('MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Root-cause mix'),
      ),
      body: AsyncValueView(
        value: mix,
        onRetry: () => ref.invalidate(rootCauseMixProvider),
        data: (rows) {
          if (rows.isEmpty) return const EmptyState('No closed tickets with a root cause yet.');

          // Totals across all time, and per-month pivot.
          final totals = <String, int>{};
          final months = <DateTime>{};
          final byMonth = <DateTime, Map<String, int>>{};
          for (final r in rows) {
            totals[r.rootCause] = (totals[r.rootCause] ?? 0) + r.count;
            months.add(r.month);
            byMonth.putIfAbsent(r.month, () => {})[r.rootCause] = r.count;
          }
          final grandTotal = totals.values.fold(0, (a, b) => a + b);
          final causes = totals.keys.toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
          final sortedMonths = months.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('All-time share', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final cause in causes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 170, child: Text(cause)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: grandTotal == 0 ? 0 : totals[cause]! / grandTotal,
                          minHeight: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text('${totals[cause]} (${(100 * totals[cause]! / grandTotal).round()}%)',
                          textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ]),
                ),
              const Divider(height: 32),
              Text('By month', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Root cause')),
                    for (final m in sortedMonths) DataColumn(label: Text(monthFmt.format(m)), numeric: true),
                  ],
                  rows: [
                    for (final cause in causes)
                      DataRow(cells: [
                        DataCell(Text(cause)),
                        for (final m in sortedMonths) DataCell(Text('${byMonth[m]?[cause] ?? 0}')),
                      ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
