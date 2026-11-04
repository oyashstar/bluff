import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/csv_export.dart';
import '../../core/enums.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'query_providers.dart';

class QueriesScreen extends ConsumerWidget {
  const QueriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queries = ref.watch(queryListProvider);
    final filter = ref.watch(queryFilterProvider);
    final myId = ref.watch(currentAppUserProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queries'),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              final list = queries.valueOrNull ?? [];
              showExportDialog(
                context,
                title: 'Queries',
                headers: ['Ticket', 'Client', 'Severity', 'Subject', 'Status', 'Module', 'Assignee', 'Created'],
                rows: [
                  for (final q in list)
                    [q.ticketNo, q.clientName, q.severity.short, q.subject, q.status.label, q.moduleName, q.assigneeName, fmtDateTime(q.createdAt)],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/quick-log'),
        icon: const Icon(Icons.bolt),
        label: const Text('Quick log'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                FilterChip(
                  label: const Text('Open only'),
                  selected: filter.openOnly,
                  onSelected: (v) => ref.read(queryFilterProvider.notifier).state =
                      QueryFilter(openOnly: v, severity: filter.severity, assigneeUserId: filter.assigneeUserId),
                ),
                const SizedBox(width: 8),
                if (myId != null) ...[
                  FilterChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: const Text('My queue'),
                    selected: filter.assigneeUserId == myId,
                    onSelected: (v) => ref.read(queryFilterProvider.notifier).state = QueryFilter(
                      openOnly: filter.openOnly,
                      severity: filter.severity,
                      assigneeUserId: v ? myId : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final s in QuerySeverity.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(s.short),
                      selected: filter.severity == s,
                      onSelected: (v) => ref.read(queryFilterProvider.notifier).state = QueryFilter(
                        openOnly: filter.openOnly,
                        severity: v ? s : null,
                        assigneeUserId: filter.assigneeUserId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: queries,
              onRetry: () => ref.invalidate(queryListProvider),
              data: (list) {
                if (list.isEmpty) return const EmptyState('No queries match this filter.');
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final q = list[i];
                    final scheme = Theme.of(context).colorScheme;
                    final sla = slaChip(
                      open: q.status.isOpen,
                      paused: q.status.pausesClock,
                      resolutionDue: q.slaResolutionDue,
                    );
                    return ListTile(
                      leading: SeverityChip(q.severity),
                      title: Text(q.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text([q.ticketNo, q.clientName, q.moduleName, q.assigneeName]
                          .whereType<String>()
                          .join(' · ')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(q.status.label, color: queryStatusColor(q.status, scheme)),
                          if (sla != null) ...[const SizedBox(height: 4), sla],
                        ],
                      ),
                      onTap: () => context.go('/queries/${q.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
