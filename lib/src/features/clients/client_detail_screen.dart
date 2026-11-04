import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/async_value_widget.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../../finance/stub_financial_provider.dart';
import '../projects/project_form.dart';
import '../projects/project_providers.dart';
import '../queries/query_providers.dart';
import '../touchpoints/touchpoint.dart';
import 'client_form.dart';
import 'client_model.dart';
import 'client_providers.dart';
import 'client_repository.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider(clientId));
    return DefaultTabController(
      length: 5,
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/clients')),
        title: Text(client.valueOrNull?.name ?? 'Client'),
        actions: [
          if (ref.watch(currentRoleProvider).canEditDelivery)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final c = client.valueOrNull;
                if (c != null) showClientForm(context, ref, existing: c);
              },
            ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Projects'),
            Tab(text: 'Queries'),
            Tab(text: 'Touchpoints'),
            Tab(text: 'Contacts'),
          ],
        ),
      ),
      body: AsyncValueView(
        value: client,
        onRetry: () => ref.invalidate(clientProvider(clientId)),
        data: (c) => TabBarView(children: [
          _Overview(client: c),
          _Projects(clientId: clientId),
          _Queries(clientId: clientId),
          _Touchpoints(clientId: clientId),
          _Contacts(clientId: clientId),
        ]),
      ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(title: 'Client', rows: {
          'Code': client.code,
          'Segment': client.segment ?? '—',
          'City': client.city ?? '—',
          'State': client.state ?? '—',
          'ERP version': client.erpVersion ?? '—',
          'AMC status': client.amcStatus ?? '—',
          'AMC expiry': fmtDateOnly(client.amcExpiry),
          'Onboarded': fmtDateOnly(client.onboardedOn),
          'ERP client code': client.erpClientCode ?? '— (not linked)',
        }),
        const SizedBox(height: 16),
        _FinancialCard(clientId: client.id),
      ],
    );
  }
}

/// The ERP seam, surfaced honestly. With the stub this always shows "not
/// linked"; when the seam is live it shows the latest synced snapshot.
class _FinancialCard extends ConsumerWidget {
  const _FinancialCard({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(clientFinancialProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_balance_outlined, size: 20),
              const SizedBox(width: 8),
              Text('Outstanding', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            FutureBuilder(
              future: provider.latestFor(clientId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
                }
                final f = snap.data;
                if (f == null || f.isUnavailable) {
                  return Text(
                    financialSeamLive
                        ? 'No snapshot synced yet for this client.'
                        : 'Not linked. The ERP seam is stubbed in this build.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtMoney(f.totalOutstanding), style: Theme.of(context).textTheme.headlineSmall),
                    Text('Overdue 90+: ${fmtMoney(f.overdue90Plus)}'),
                    Text('As of ${fmtDate(f.asOf)}', style: Theme.of(context).textTheme.bodySmall),
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

class _Projects extends ConsumerWidget {
  const _Projects({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(clientProjectsProvider(clientId));
    final canEdit = ref.watch(currentRoleProvider).canEditDelivery;
    return Stack(children: [
      AsyncValueView(
        value: projects,
        onRetry: () => ref.invalidate(clientProjectsProvider(clientId)),
        data: (list) {
          if (list.isEmpty) return const EmptyState('No projects for this client yet.');
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                leading: HealthBadge(score: p.healthScore, breakdown: p.healthBreakdown),
                title: Text(p.title),
                subtitle: Text('${p.type.label} · ${p.status.label} · ${p.currentStage ?? 'no stages'}'),
                onTap: () => context.go('/projects/${p.projectId}'),
              );
            },
          );
        },
      ),
      if (canEdit)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-project',
            onPressed: () => showProjectForm(context, ref, clientId: clientId),
            icon: const Icon(Icons.add),
            label: const Text('New project'),
          ),
        ),
    ]);
  }
}

class _Queries extends ConsumerWidget {
  const _Queries({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queries = ref.watch(clientQueriesProvider(clientId));
    return AsyncValueView(
      value: queries,
      onRetry: () => ref.invalidate(clientQueriesProvider(clientId)),
      data: (list) {
        if (list.isEmpty) return const EmptyState('No queries logged for this client.');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final q = list[i];
            return ListTile(
              leading: SeverityChip(q.severity),
              title: Text(q.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${q.ticketNo} · ${q.status.label}'),
              trailing: Text(fmtRelativeDays(q.createdAt), style: Theme.of(context).textTheme.bodySmall),
              onTap: () => context.go('/queries/${q.id}'),
            );
          },
        );
      },
    );
  }
}

class _Contacts extends ConsumerWidget {
  const _Contacts({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(clientContactsProvider(clientId));
    final canEdit = ref.watch(currentRoleProvider).canEditDelivery;
    return Stack(children: [
      AsyncValueView(
        value: contacts,
        onRetry: () => ref.invalidate(clientContactsProvider(clientId)),
        data: (list) {
          if (list.isEmpty) return const EmptyState('No contacts yet.');
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = list[i];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Row(children: [
                  Flexible(child: Text(c.name)),
                  if (c.isPrimary) const Padding(padding: EdgeInsets.only(left: 8), child: StatusChip('Primary')),
                  if (c.isChampion) const Padding(padding: EdgeInsets.only(left: 6), child: StatusChip('Champion')),
                ]),
                subtitle: Text([c.role, c.phone, c.email].whereType<String>().join(' · ')),
              );
            },
          );
        },
      ),
      if (canEdit)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-contact',
            onPressed: () => _showContactForm(context, ref, clientId),
            icon: const Icon(Icons.add),
            label: const Text('Add contact'),
          ),
        ),
    ]);
  }
}

Future<void> _showContactForm(BuildContext context, WidgetRef ref, String clientId) async {
  final name = TextEditingController();
  final role = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  var isPrimary = false;
  var isChampion = false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add contact'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: role, decoration: const InputDecoration(labelText: 'Role')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPrimary,
                  onChanged: (v) => setState(() => isPrimary = v ?? false),
                  title: const Text('Primary'),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isChampion,
                  onChanged: (v) => setState(() => isChampion = v ?? false),
                  title: const Text('Champion'),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await ref.read(clientRepositoryProvider).addContact(
                    clientId: clientId,
                    name: name.text.trim(),
                    role: role.text.trim().isEmpty ? null : role.text.trim(),
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    email: email.text.trim().isEmpty ? null : email.text.trim(),
                    isPrimary: isPrimary,
                    isChampion: isChampion,
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) ref.invalidate(clientContactsProvider(clientId));
}

class _Touchpoints extends ConsumerWidget {
  const _Touchpoints({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final touchpoints = ref.watch(clientTouchpointsProvider(clientId));
    final canEdit = ref.watch(currentRoleProvider).canEditSupport;
    return Stack(children: [
      AsyncValueView(
        value: touchpoints,
        onRetry: () => ref.invalidate(clientTouchpointsProvider(clientId)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState('No touchpoints logged. Logging calls and visits keeps health scores honest.');
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = list[i];
              return ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text([t.type ?? 'Touchpoint', if (t.summary != null) t.summary].whereType<String>().join(' — ')),
                subtitle: Text([
                  fmtDateTime(t.occurredOn),
                  if (t.userName != null) t.userName,
                  if (t.durationMin != null) '${t.durationMin} min',
                ].whereType<String>().join(' · ')),
              );
            },
          );
        },
      ),
      if (canEdit)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-touchpoint',
            onPressed: () => _showTouchpointForm(context, ref, clientId),
            icon: const Icon(Icons.add),
            label: const Text('Log touchpoint'),
          ),
        ),
    ]);
  }
}

Future<void> _showTouchpointForm(BuildContext context, WidgetRef ref, String clientId) async {
  var type = Touchpoint.types.first;
  final summary = TextEditingController();
  final duration = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Log touchpoint'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in Touchpoint.types) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Summary')),
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (min, optional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(touchpointRepositoryProvider).create(
                    clientId: clientId,
                    type: type,
                    summary: summary.text.trim().isEmpty ? null : summary.text.trim(),
                    durationMin: int.tryParse(duration.text.trim()),
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    ref.invalidate(clientTouchpointsProvider(clientId));
    ref.invalidate(clientProjectsProvider(clientId)); // health may have changed
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final e in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 140, child: Text(e.key, style: Theme.of(context).textTheme.bodySmall)),
                  Expanded(child: Text(e.value)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
