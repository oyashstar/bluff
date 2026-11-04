import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import 'dashboard_providers.dart';

/// Module × severity, last 30 days — tells you which module is bleeding.
/// Reads v_query_heatmap.
class QueryHeatmapScreen extends ConsumerWidget {
  const QueryHeatmapScreen({super.key});

  static const _severities = ['S1', 'S2', 'S3', 'S4'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmap = ref.watch(heatmapProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Query heatmap'),
      ),
      body: AsyncValueView(
        value: heatmap,
        onRetry: () => ref.invalidate(heatmapProvider),
        data: (cells) {
          if (cells.isEmpty) return const EmptyState('No queries in the last 30 days.');

          // Pivot into module -> severity -> count.
          final modules = <String, String>{}; // id -> name
          final grid = <String, Map<String, int>>{};
          var maxCount = 1;
          for (final c in cells) {
            modules[c.moduleId] = c.moduleName;
            grid.putIfAbsent(c.moduleId, () => {})[c.severity] = c.count;
            if (c.count > maxCount) maxCount = c.count;
          }
          final moduleIds = modules.keys.toList()
            ..sort((a, b) => modules[a]!.compareTo(modules[b]!));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Module')),
                for (final s in _severities) DataColumn(label: Text(s), numeric: true),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: [
                for (final id in moduleIds)
                  DataRow(cells: [
                    DataCell(Text(modules[id]!)),
                    for (final s in _severities)
                      DataCell(_Cell(count: grid[id]?[s] ?? 0, max: maxCount, severity: s)),
                    DataCell(Text('${grid[id]!.values.fold(0, (a, b) => a + b)}',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.count, required this.max, required this.severity});
  final int count;
  final int max;
  final String severity;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Text('·');
    final base = switch (severity) {
      'S1' => const Color(0xFFC62828),
      'S2' => const Color(0xFFEF6C00),
      'S3' => const Color(0xFF1565C0),
      _ => const Color(0xFF616161),
    };
    final intensity = (count / max).clamp(0.15, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: intensity * 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$count',
          style: TextStyle(color: intensity > 0.5 ? Colors.white : base, fontWeight: FontWeight.w600)),
    );
  }
}
