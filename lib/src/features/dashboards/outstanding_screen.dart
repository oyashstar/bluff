import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/csv_export.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../../finance/stub_financial_provider.dart';
import 'dashboard_providers.dart';

/// Outstanding (AR) per client, from the ERP seam. Shows figures once the
/// sync-financials Edge Function is populating client_financial_snapshot for
/// the configured Finsys ERP company code; until then it renders "not linked"
/// honestly and still lists which clients have an ERP client code mapped.
class OutstandingScreen extends ConsumerWidget {
  const OutstandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(outstandingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Outstanding'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              final list = data.valueOrNull ?? [];
              showExportDialog(
                context,
                title: 'Outstanding',
                headers: ['Client', 'Code', 'ERP code', 'Outstanding', 'Overdue 90+', 'As of'],
                rows: [
                  for (final r in list)
                    [r.name, r.code, r.erpClientCode, r.totalOutstanding, r.overdue90Plus, fmtDateOnly(r.asOf)],
                ],
              );
            },
          ),
        ],
      ),
      body: AsyncValueView(
        value: data,
        onRetry: () => ref.invalidate(outstandingProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyState('No clients yet.');
          final withFigures = list.where((r) => r.hasFigure).toList();
          final total = withFigures.fold<num>(0, (a, r) => a + (r.totalOutstanding ?? 0));
          final overdue = withFigures.fold<num>(0, (a, r) => a + (r.overdue90Plus ?? 0));
          final linked = list.where((r) => r.isLinked).length;

          return Column(
            children: [
              if (!financialSeamLive)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3E0),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'ERP seam is stubbed — figures are blank until it is live. '
                    '$linked of ${list.length} clients have an ERP client code mapped. '
                    'Set the company code in Settings and deploy sync-financials.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  _Kpi(label: 'Total outstanding', value: fmtMoney(total)),
                  const SizedBox(width: 12),
                  _Kpi(label: 'Overdue 90+', value: fmtMoney(overdue), emphasis: true),
                  const SizedBox(width: 12),
                  _Kpi(label: 'Clients with figures', value: '${withFigures.length}'),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return ListTile(
                      title: Text(r.name),
                      subtitle: Text([
                        r.code,
                        if (r.isLinked) 'ERP ${r.erpClientCode}' else 'not linked',
                        if (r.asOf != null) 'as of ${fmtDateOnly(r.asOf)}',
                      ].join(' · ')),
                      trailing: r.hasFigure
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fmtMoney(r.totalOutstanding),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                if ((r.overdue90Plus ?? 0) > 0)
                                  Text('90+: ${fmtMoney(r.overdue90Plus)}',
                                      style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
                              ],
                            )
                          : const StatusChip('—'),
                      onTap: () => context.go('/clients/${r.clientId}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: emphasis ? const Color(0xFFC62828) : null,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
