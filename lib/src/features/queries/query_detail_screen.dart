import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/enums.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'query_model.dart';
import 'query_providers.dart';
import 'query_repository.dart';

class QueryDetailScreen extends ConsumerWidget {
  const QueryDetailScreen({super.key, required this.queryId});
  final String queryId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(queryProvider(queryId));
    ref.invalidate(queryListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(queryProvider(queryId));
    final canEdit = ref.watch(currentRoleProvider).canEditSupport;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/queries')),
        title: Text(query.valueOrNull?.ticketNo ?? 'Query'),
      ),
      body: AsyncValueView(
        value: query,
        onRetry: () => _refresh(ref),
        data: (q) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(query: q),
            if (canEdit) ...[
              const SizedBox(height: 12),
              _Actions(query: q, onChanged: () => _refresh(ref)),
            ],
            const SizedBox(height: 16),
            _SlaCard(query: q),
            const SizedBox(height: 16),
            _Comments(queryId: queryId, canEdit: canEdit),
            const SizedBox(height: 16),
            _Attachments(queryId: queryId, canEdit: canEdit),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.query});
  final Query query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SeverityChip(query.severity),
              const SizedBox(width: 8),
              StatusChip(query.status.label, color: queryStatusColor(query.status, scheme)),
              const Spacer(),
              Text(query.ticketNo, style: Theme.of(context).textTheme.labelLarge),
            ]),
            const SizedBox(height: 12),
            Text(query.subject, style: Theme.of(context).textTheme.titleMedium),
            if (query.description != null && query.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(query.description!),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip('Client: ${query.clientName ?? '—'}'),
              if (query.moduleName != null) StatusChip('Module: ${query.moduleName}'),
              StatusChip('Channel: ${query.channel.label}'),
              StatusChip('Assignee: ${query.assigneeName ?? 'Unassigned'}'),
              if (query.rootCause != null) StatusChip('Root cause: ${query.rootCause!.label}'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.query, required this.onChanged});
  final Query query;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = query.status.allowedNext;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final to in next)
                OutlinedButton(
                  onPressed: () => _transition(context, ref, to),
                  child: Text('→ ${to.label}'),
                ),
              TextButton.icon(
                onPressed: () => _reassign(context, ref),
                icon: const Icon(Icons.person_outline),
                label: const Text('Reassign'),
              ),
              TextButton.icon(
                onPressed: () => _changeSeverity(context, ref),
                icon: const Icon(Icons.priority_high),
                label: const Text('Severity'),
              ),
            ]),
            if (next.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('This query is ${query.status.label.toLowerCase()} — no further transitions.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _transition(BuildContext context, WidgetRef ref, QueryStatus to) async {
    RootCause? rootCause;
    String? notes;
    if (to == QueryStatus.resolved || to == QueryStatus.closed) {
      final result = await _promptResolution(context, existing: query.rootCause);
      if (result == null) return; // cancelled
      rootCause = result.$1;
      notes = result.$2;
    }
    try {
      await ref.read(queryRepositoryProvider).transition(query.id, to, rootCause: rootCause, resolutionNotes: notes);
      onChanged();
      if (context.mounted) showSnack(context, 'Moved to ${to.label}');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Transition rejected: $e', error: true);
    }
  }

  Future<(RootCause, String?)?> _promptResolution(BuildContext context, {RootCause? existing}) {
    RootCause? rc = existing;
    final notes = TextEditingController(text: query.resolutionNotes ?? '');
    return showDialog<(RootCause, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Resolve / close'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<RootCause>(
                initialValue: rc,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Root cause * (mandatory)'),
                items: [for (final r in RootCause.values) DropdownMenuItem(value: r, child: Text(r.label))],
                onChanged: (v) => setState(() => rc = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Resolution notes')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (rc == null) return; // root cause required
                Navigator.pop(ctx, (rc!, notes.text.trim().isEmpty ? null : notes.text.trim()));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(activeUsersProvider.future);
    if (!context.mounted) return;
    final picked = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Assign to'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, null), child: const Text('Unassigned')),
          for (final u in users)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, u.id), child: Text(u.displayName)),
        ],
      ),
    );
    await ref.read(queryRepositoryProvider).reassign(query.id, picked);
    onChanged();
  }

  Future<void> _changeSeverity(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<QuerySeverity>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Severity'),
        children: [
          for (final s in QuerySeverity.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text(s.label)),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(queryRepositoryProvider).setSeverity(query.id, picked);
      onChanged();
    }
  }
}

class _SlaCard extends StatelessWidget {
  const _SlaCard({required this.query});
  final Query query;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SLA & timeline', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Logged', fmtDateTime(query.createdAt)),
          _row('Acknowledged', fmtDateTime(query.acknowledgedAt)),
          _row('Response due', fmtDateTime(query.slaResponseDue)),
          _row('Resolution due', fmtDateTime(query.slaResolutionDue)),
          _row('Resolved', fmtDateTime(query.resolvedAt)),
          _row('Closed', fmtDateTime(query.closedAt)),
          _row('Paused (business min)', '${query.slaPausedMinutes}'),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 180, child: Text(k)),
          Expanded(child: Text(v)),
        ]),
      );
}

class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.queryId, required this.canEdit});
  final String queryId;
  final bool canEdit;

  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final _controller = TextEditingController();
  bool _internal = true;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(queryRepositoryProvider).addComment(
            queryId: widget.queryId,
            body: _controller.text.trim(),
            isInternal: _internal,
          );
      _controller.clear();
      ref.invalidate(queryCommentsProvider(widget.queryId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(queryCommentsProvider(widget.queryId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            comments.when(
              loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) return const Text('No comments yet.');
                return Column(
                  children: [
                    for (final c in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(c.isInternal ? Icons.lock_outline : Icons.public, size: 18),
                        title: Text(c.body),
                        subtitle: Text('${c.authorName ?? 'Someone'} · ${fmtDateTime(c.createdAt)}'),
                      ),
                  ],
                );
              },
            ),
            if (widget.canEdit) ...[
              const Divider(),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Add a comment', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(children: [
                FilterChip(
                  label: const Text('Internal'),
                  selected: _internal,
                  onSelected: (v) => setState(() => _internal = v),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _add,
                  child: const Text('Post'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Attachments extends ConsumerWidget {
  const _Attachments({required this.queryId, required this.canEdit});
  final String queryId;
  final bool canEdit;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) showSnack(context, 'Could not read file bytes.', error: true);
      return;
    }
    try {
      await ref.read(queryRepositoryProvider).uploadAttachment(
            queryId: queryId,
            filename: file.name,
            bytes: bytes,
          );
      ref.invalidate(queryAttachmentsProvider(queryId));
      if (context.mounted) showSnack(context, 'Uploaded ${file.name}');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Upload failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(queryAttachmentsProvider(queryId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Attachments', style: Theme.of(context).textTheme.titleMedium)),
              if (canEdit)
                TextButton.icon(
                  onPressed: () => _upload(context, ref),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                ),
            ]),
            attachments.when(
              loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) return const Text('No attachments.');
                return Column(
                  children: [
                    for (final a in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file),
                        title: Text((a['storage_path'] as String).split('/').last),
                        subtitle: Text(fmtDateTime(DateTime.tryParse('${a['uploaded_at']}'))),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            final url = await ref.read(queryRepositoryProvider).signedUrl(a['storage_path'] as String);
                            if (context.mounted) showSnack(context, 'Signed URL ready (10 min): $url');
                          },
                        ),
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
