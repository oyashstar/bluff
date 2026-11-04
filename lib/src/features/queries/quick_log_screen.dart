import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/enums.dart';
import '../../core/formatting.dart';
import '../clients/client_providers.dart';
import '../modules/module.dart';
import 'query_providers.dart';
import 'query_repository.dart';

/// Clients the current user logged against recently, most-recent first. Held in
/// memory so the next query for the same client is one tap away — the screen is
/// judged on speed, not completeness.
final _recentClientIdsProvider = StateProvider<List<String>>((ref) => []);

/// THE make-or-break screen. Client, module, severity, one line, submit —
/// everything else is optional and editable later. If this takes a minute, the
/// tool dies, so it is intentionally one short column.
class QuickLogScreen extends ConsumerStatefulWidget {
  const QuickLogScreen({super.key});

  @override
  ConsumerState<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends ConsumerState<QuickLogScreen> {
  String? _clientId;
  String? _moduleId;
  QuerySeverity _severity = QuerySeverity.s3;
  QueryChannel _channel = QueryChannel.phone;
  final _subject = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_clientId == null || _subject.text.trim().isEmpty) {
      showSnack(context, 'Pick a client and type one line.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final q = await ref.read(queryRepositoryProvider).create(
            clientId: _clientId!,
            severity: _severity,
            subject: _subject.text.trim(),
            moduleId: _moduleId,
            channel: _channel,
          );
      // Bump recents and reset for the next one.
      final recents = [...ref.read(_recentClientIdsProvider)]
        ..remove(_clientId)
        ..insert(0, _clientId!);
      ref.read(_recentClientIdsProvider.notifier).state = recents.take(8).toList();
      ref.invalidate(queryListProvider);
      if (!mounted) return;
      _subject.clear();
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${q.ticketNo}'),
          action: SnackBarAction(label: 'Open', onPressed: () => context.go('/queries/${q.id}')),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not log: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientListProvider);
    final modules = ref.watch(modulesProvider);
    final recents = ref.watch(_recentClientIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick-log query')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              clients.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  // Recent clients first, then the rest alphabetically.
                  final byId = {for (final c in list) c.id: c};
                  final ordered = [
                    ...recents.where(byId.containsKey).map((id) => byId[id]!),
                    ...list.where((c) => !recents.contains(c.id)),
                  ];
                  return DropdownButtonFormField<String>(
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Client *', border: OutlineInputBorder()),
                    items: [
                      for (final c in ordered)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name}${recents.contains(c.id) ? '  ·  recent' : ''}'),
                        ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _clientId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Severity', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in QuerySeverity.values)
                    ChoiceChip(
                      label: Text(s.short),
                      selected: _severity == s,
                      selectedColor: severityColor(s.wire).withValues(alpha: 0.25),
                      onSelected: _busy ? null : (_) => setState(() => _severity = s),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_severity.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _subject,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'What happened? (one line) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              modules.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (mods) => DropdownButtonFormField<String>(
                  initialValue: _moduleId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Module (optional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final Module m in mods) DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _moduleId = v),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<QueryChannel>(
                initialValue: _channel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Channel', border: OutlineInputBorder()),
                items: [for (final c in QueryChannel.values) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: _busy ? null : (v) => setState(() => _channel = v ?? QueryChannel.phone),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Log query'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
