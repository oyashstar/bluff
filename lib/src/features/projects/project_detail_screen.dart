import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/enums.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../modules/module.dart';
import 'project_model.dart';
import 'project_providers.dart';
import 'project_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final canEdit = ref.watch(currentRoleProvider).canEditDelivery;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/projects')),
        title: Text(project.valueOrNull?.title ?? 'Project'),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) => _onAction(context, ref, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'status', child: Text('Change status')),
                PopupMenuItem(value: 'revise', child: Text('Revise planned go-live')),
                PopupMenuItem(value: 'actual', child: Text('Set actual go-live')),
                PopupMenuItem(value: 'recompute', child: Text('Recompute health')),
              ],
            ),
        ],
      ),
      body: AsyncValueView(
        value: project,
        onRetry: () => ref.invalidate(projectProvider(projectId)),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(project: p),
            const SizedBox(height: 16),
            _Modules(projectId: projectId, canEdit: canEdit),
            const SizedBox(height: 16),
            _StageBoard(project: p, canEdit: canEdit),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(projectRepositoryProvider);
    switch (action) {
      case 'status':
        final s = await _pickStatus(context);
        if (s != null) {
          await repo.update(projectId, status: s);
          invalidateProject(ref, projectId);
        }
      case 'revise':
        final d = await _pickDate(context);
        if (d != null) {
          await repo.update(projectId, plannedGolive: d, bumpGoliveRevision: true);
          invalidateProject(ref, projectId);
          if (context.mounted) showSnack(context, 'Planned go-live revised (counts toward health).');
        }
      case 'actual':
        final d = await _pickDate(context);
        if (d != null) {
          await repo.update(projectId, actualGolive: d, status: ProjectStatus.hypercare);
          invalidateProject(ref, projectId);
        }
      case 'recompute':
        await repo.recomputeHealth(projectId);
        invalidateProject(ref, projectId);
        if (context.mounted) showSnack(context, 'Health recomputed.');
    }
  }

  Future<ProjectStatus?> _pickStatus(BuildContext context) {
    return showDialog<ProjectStatus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Project status'),
        children: [
          for (final s in ProjectStatus.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text(s.label)),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(project.title, style: Theme.of(context).textTheme.titleLarge)),
              HealthBadge(score: project.healthScore, breakdown: project.healthBreakdown),
            ]),
            const SizedBox(height: 4),
            Text('${healthLabel(project.healthScore)} · ${project.type.label}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(project.status.label),
              StatusChip('Planned: ${fmtDateOnly(project.plannedGolive)}'),
              if (project.actualGolive != null) StatusChip('Live: ${fmtDateOnly(project.actualGolive)}'),
              if (project.goliveRevisions > 0) StatusChip('Revised ×${project.goliveRevisions}'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Modules extends ConsumerWidget {
  const _Modules({required this.projectId, required this.canEdit});
  final String projectId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider);
    final projectModules = ref.watch(projectModulesProvider(projectId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modules in scope', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            modules.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (mods) {
                final inScope = <String, bool>{};
                for (final pm in projectModules.valueOrNull ?? const <Map<String, dynamic>>[]) {
                  inScope[pm['module_id'] as String] = (pm['in_scope'] as bool?) ?? false;
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final Module m in mods)
                      FilterChip(
                        label: Text(m.name),
                        selected: inScope[m.id] ?? false,
                        onSelected: canEdit
                            ? (sel) async {
                                await ref.read(projectRepositoryProvider).setModuleInScope(
                                      projectId: projectId,
                                      moduleId: m.id,
                                      inScope: sel,
                                    );
                                ref.invalidate(projectModulesProvider(projectId));
                              }
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StageBoard extends ConsumerWidget {
  const _StageBoard({required this.project, required this.canEdit});
  final Project project;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(projectStagesProvider(project.id));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Stage board', style: Theme.of(context).textTheme.titleMedium)),
              if (canEdit && (stages.valueOrNull?.isEmpty ?? false) && project.stageTemplateId != null)
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(projectRepositoryProvider).applyTemplate(project.id, project.stageTemplateId!);
                    invalidateProject(ref, project.id);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Apply template'),
                ),
            ]),
            const SizedBox(height: 8),
            AsyncValueView(
              value: stages,
              onRetry: () => ref.invalidate(projectStagesProvider(project.id)),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No stages yet. Apply a stage template to materialise the lifecycle.'),
                  );
                }
                return Column(
                  children: [
                    for (final ProjectStage s in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: stageStatusColor(s.status, scheme),
                          child: Text('${s.seq}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        title: Row(children: [
                          Flexible(child: Text(s.stageName)),
                          if (s.requiresSignoff)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Tooltip(message: 'Sign-off gate', child: Icon(Icons.verified_outlined, size: 16)),
                            ),
                        ]),
                        subtitle: Text([
                          s.status.label,
                          if (s.actualStart != null) 'start ${fmtDateOnly(s.actualStart)}',
                          if (s.actualEnd != null) 'end ${fmtDateOnly(s.actualEnd)}',
                          if (s.status == StageStatus.blocked && s.blockedReason != null) 'blocked: ${s.blockedReason}',
                        ].join(' · ')),
                        trailing: canEdit
                            ? PopupMenuButton<StageStatus>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (st) => _changeStage(context, ref, s, st),
                                itemBuilder: (_) => [
                                  for (final st in StageStatus.values)
                                    PopupMenuItem(value: st, child: Text(st.label)),
                                ],
                              )
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStage(BuildContext context, WidgetRef ref, ProjectStage s, StageStatus to) async {
    String? reason;
    if (to == StageStatus.blocked) {
      reason = await _promptReason(context);
      if (reason == null) return; // cancelled
    }
    await ref.read(projectRepositoryProvider).setStageStatus(
          stageId: s.id,
          projectId: s.projectId,
          status: to,
          blockedReason: reason,
        );
    invalidateProject(ref, s.projectId);
  }

  Future<String?> _promptReason(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why is this blocked?'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Block')),
        ],
      ),
    );
  }
}
