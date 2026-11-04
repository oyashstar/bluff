import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/enums.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'dashboard_models.dart';
import 'dashboard_providers.dart';

/// Breached and at-risk tickets, grouped by assignee. Reads v_sla_board.
class SlaBoardScreen extends ConsumerWidget {
  const SlaBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(slaBoardProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('SLA board'),
      ),
      body: AsyncValueView(
        value: board,
        onRetry: () => ref.invalidate(slaBoardProvider),
        data: (rows) {
          // Only show rows that need attention (breached or at-risk).
          final flagged = rows
              .where((r) => r.resolutionStatus == 'breached' ||
                  r.resolutionStatus == 'at_risk' ||
                  r.responseStatus == 'breached')
              .toList();
          if (flagged.isEmpty) {
            return const EmptyState('No breached or at-risk tickets. 🎉',
                icon: Icons.verified_outlined);
          }
          // Group by assignee.
          final groups = <String, List<SlaBoardRow>>{};
          for (final r in flagged) {
            groups.putIfAbsent(r.assigneeName ?? 'Unassigned', () => []).add(r);
          }
          final names = groups.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final name in names) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Row(children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    CircleAvatar(radius: 11, child: Text('${groups[name]!.length}', style: const TextStyle(fontSize: 11))),
                  ]),
                ),
                for (final r in groups[name]!)
                  Card(
                    child: ListTile(
                      leading: SeverityChip(QuerySeverity.fromWire(r.severity)),
                      title: Text(r.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${r.ticketNo} · ${r.clientName} · due ${fmtDateTime(r.resolutionDue)}'),
                      trailing: _SlaChip(r),
                      onTap: () => context.go('/queries/${r.queryId}'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SlaChip extends StatelessWidget {
  const _SlaChip(this.row);
  final SlaBoardRow row;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.resolutionStatus) {
      'breached' => ('Breached', const Color(0xFFC62828)),
      'at_risk' => ('At risk', const Color(0xFFF9A825)),
      _ => row.responseStatus == 'breached'
          ? ('Response late', const Color(0xFFEF6C00))
          : ('OK', const Color(0xFF2E7D32)),
    };
    return StatusChip(label, color: color);
  }
}
