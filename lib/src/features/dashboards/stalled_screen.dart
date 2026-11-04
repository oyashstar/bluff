import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/widgets.dart';
import 'dashboard_providers.dart';

/// The single most actionable screen: active projects with no touchpoint, stage
/// change or query activity for N+ days, worst first. Reads v_stalled_projects.
class StalledScreen extends ConsumerWidget {
  const StalledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stalled = ref.watch(stalledProjectsProvider);
    final n = ref.watch(stalledThresholdProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Stalled projects'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Text('Stalled ≥ $n days', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              for (final threshold in [7, 14, 30, 45])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$threshold'),
                    selected: n == threshold,
                    onSelected: (_) => ref.read(stalledThresholdProvider.notifier).state = threshold,
                  ),
                ),
            ]),
          ),
          Expanded(
            child: AsyncValueView(
              value: stalled,
              onRetry: () => ref.invalidate(stalledProjectsProvider),
              data: (list) {
                if (list.isEmpty) return EmptyState('Nothing stalled beyond $n days. 🎉');
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: HealthBadge(score: p.healthScore, breakdown: p.healthBreakdown),
                      title: Text('${p.clientName} — ${p.title}'),
                      subtitle: Text('${p.status.label} · ${p.currentStage ?? 'no stages'} · owner ${p.ownerName ?? '—'}'),
                      trailing: Text('${p.daysStalled ?? '—'}d',
                          style: Theme.of(context).textTheme.titleMedium),
                      onTap: () => context.go('/projects/${p.projectId}'),
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
