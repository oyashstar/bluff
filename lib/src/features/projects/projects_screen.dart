import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/csv_export.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'project_form.dart';
import 'project_providers.dart';

/// A straightforward project list (the kanban board is the dedicated
/// Implementation board dashboard). Reads v_project_board.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(projectBoardProvider);
    final canEdit = ref.watch(currentRoleProvider).canEditDelivery;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            tooltip: 'Open board',
            icon: const Icon(Icons.view_kanban_outlined),
            onPressed: () => context.go('/dashboards/board'),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              final list = board.valueOrNull ?? [];
              showExportDialog(
                context,
                title: 'Projects',
                headers: ['Client', 'Project', 'Type', 'Status', 'Stage', 'Days in stage', 'Health', 'Planned go-live'],
                rows: [
                  for (final p in list)
                    [p.clientName, p.title, p.type.label, p.status.label, p.currentStage, p.daysInStage, p.healthScore, fmtDateOnly(p.plannedGolive)],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => showProjectForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            )
          : null,
      body: AsyncValueView(
        value: board,
        onRetry: () => ref.invalidate(projectBoardProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyState('No projects yet.');
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                leading: HealthBadge(score: p.healthScore, breakdown: p.healthBreakdown),
                title: Text('${p.clientName} — ${p.title}'),
                subtitle: Text([
                  p.status.label,
                  if (p.currentStage != null) 'Stage: ${p.currentStage}',
                  if (p.daysInStage != null) '${p.daysInStage}d in stage',
                  if (p.ownerName != null) 'Owner: ${p.ownerName}',
                ].join(' · ')),
                trailing: p.isOverrunning
                    ? const Tooltip(message: 'Over template duration', child: Icon(Icons.warning_amber, color: Color(0xFFF9A825)))
                    : null,
                onTap: () => context.go('/projects/${p.projectId}'),
              );
            },
          );
        },
      ),
    );
  }
}
