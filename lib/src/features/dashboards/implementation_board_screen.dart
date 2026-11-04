import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../projects/project_model.dart';
import '../projects/project_providers.dart';

/// Kanban: one column per lifecycle stage (by seq), one card per project,
/// card colour from health. Reads v_project_board.
class ImplementationBoardScreen extends ConsumerWidget {
  const ImplementationBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(projectBoardProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Implementation board'),
      ),
      body: AsyncValueView(
        value: board,
        onRetry: () => ref.invalidate(projectBoardProvider),
        data: (rows) {
          final open = rows.where((r) => r.status.isOpen).toList();
          if (open.isEmpty) return const EmptyState('No active implementations.');

          // Group by current stage, ordered by the stage seq we have on each row.
          final columns = <String, List<ProjectBoardRow>>{};
          final seqOf = <String, int>{};
          for (final r in open) {
            final key = r.currentStage ?? 'No stages';
            columns.putIfAbsent(key, () => []).add(r);
            seqOf[key] = r.currentStageSeq ?? 9999;
          }
          final orderedKeys = columns.keys.toList()
            ..sort((a, b) => (seqOf[a] ?? 9999).compareTo(seqOf[b] ?? 9999));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final key in orderedKeys)
                  _Column(title: key, items: columns[key]!),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.items});
  final String title;
  final List<ProjectBoardRow> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              CircleAvatar(radius: 12, child: Text('${items.length}', style: const TextStyle(fontSize: 11))),
            ]),
          ),
          for (final r in items) _Card(row: r),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.row});
  final ProjectBoardRow row;

  @override
  Widget build(BuildContext context) {
    final color = healthColor(row.healthScore, Theme.of(context).colorScheme);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: InkWell(
        onTap: () => context.go('/projects/${row.projectId}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.clientName, style: Theme.of(context).textTheme.titleSmall),
              Text(row.title, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                HealthBadge(score: row.healthScore, breakdown: row.healthBreakdown),
                const Spacer(),
                if (row.daysInStage != null)
                  Text('${row.daysInStage}d', style: Theme.of(context).textTheme.labelSmall),
              ]),
              if (row.ownerName != null)
                Text(row.ownerName!, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
