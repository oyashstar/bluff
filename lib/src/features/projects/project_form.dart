import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/enums.dart';
import '../clients/client_providers.dart';
import 'project_model.dart';
import 'project_providers.dart';
import 'project_repository.dart';

/// Create a project. If [clientId] is given the client is fixed; otherwise the
/// user picks one. Optionally applies a stage template on create.
Future<void> showProjectForm(BuildContext context, WidgetRef ref, {String? clientId}) async {
  final created = await showDialog<String>(
    context: context,
    builder: (_) => _ProjectFormDialog(fixedClientId: clientId),
  );
  if (created != null) {
    ref.invalidate(projectBoardProvider);
    if (clientId != null) ref.invalidate(clientProjectsProvider(clientId));
    if (context.mounted) context.go('/projects/$created');
  }
}

class _ProjectFormDialog extends ConsumerStatefulWidget {
  const _ProjectFormDialog({this.fixedClientId});
  final String? fixedClientId;

  @override
  ConsumerState<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<_ProjectFormDialog> {
  final _title = TextEditingController();
  String? _clientId;
  ProjectType _type = ProjectType.newImplementation;
  String? _ownerId;
  String? _templateId;
  DateTime? _plannedGolive;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.fixedClientId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_clientId == null || _title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(projectRepositoryProvider);
      final project = await repo.create(
        clientId: _clientId!,
        title: _title.text.trim(),
        type: _type,
        ownerUserId: _ownerId,
        stageTemplateId: _templateId,
        plannedGolive: _plannedGolive,
      );
      if (_templateId != null) {
        await repo.applyTemplate(project.id, _templateId!);
      }
      if (mounted) Navigator.pop(context, project.id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not create project: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientListProvider);
    final users = ref.watch(activeUsersProvider);
    final templates = ref.watch(stageTemplatesProvider);

    return AlertDialog(
      title: const Text('New project'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.fixedClientId == null)
              clients.when(
                data: (list) => DropdownButtonFormField<String>(
                  value: _clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Client *'),
                  items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _clientId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title *')),
            DropdownButtonFormField<ProjectType>(
              value: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in ProjectType.values) DropdownMenuItem(value: t, child: Text(t.label))],
              onChanged: (v) => setState(() => _type = v ?? ProjectType.newImplementation),
            ),
            users.when(
              data: (list) => DropdownButtonFormField<String>(
                value: _ownerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Owner'),
                items: [for (final u in list) DropdownMenuItem(value: u.id, child: Text(u.displayName))],
                onChanged: (v) => setState(() => _ownerId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            templates.when(
              data: (list) => DropdownButtonFormField<String>(
                value: _templateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Stage template',
                  helperText: 'Applied on create — materialises the stage board.',
                ),
                items: [for (final t in list) DropdownMenuItem(value: t.id, child: Text(t.name))],
                onChanged: (v) => setState(() => _templateId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Planned go-live: ${_plannedGolive == null ? '—' : _plannedGolive!.toIso8601String().split('T').first}')),
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 3),
                  );
                  if (picked != null) setState(() => _plannedGolive = picked);
                },
                child: const Text('Pick'),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
