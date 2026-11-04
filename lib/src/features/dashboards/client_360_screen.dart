import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'dashboard_providers.dart';

/// One row per client: active projects, open/critical queries, last touchpoint,
/// outstanding (when the seam is live). Second tab flags the churn signal —
/// clients that went silent after go-live. Reads v_client_360 / v_silent_clients.
class Client360Screen extends ConsumerWidget {
  const Client360Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
          title: const Text('Client 360'),
          bottom: const TabBar(tabs: [Tab(text: 'All clients'), Tab(text: 'Silent (churn risk)')]),
        ),
        body: TabBarView(children: [_All(), _Silent()]),
      ),
    );
  }
}

class _All extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(client360Provider);
    return AsyncValueView(
      value: data,
      onRetry: () => ref.invalidate(client360Provider),
      data: (list) {
        if (list.isEmpty) return const EmptyState('No clients yet.');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = list[i];
            return ListTile(
              title: Text(c.name),
              subtitle: Wrap(spacing: 8, runSpacing: 4, children: [
                StatusChip('${c.activeProjects} projects'),
                if (c.openQueries > 0) StatusChip('${c.openQueries} open'),
                if (c.openCriticalQueries > 0)
                  StatusChip('${c.openCriticalQueries} critical', color: const Color(0xFFC62828)),
                StatusChip('touch ${fmtRelativeDays(c.lastTouchpointAt)}'),
                if (c.latestOutstanding != null) StatusChip('₹ ${fmtMoney(c.latestOutstanding)}'),
              ]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/clients/${c.clientId}'),
            );
          },
        );
      },
    );
  }
}

class _Silent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(silentClientsProvider);
    return AsyncValueView(
      value: data,
      onRetry: () => ref.invalidate(silentClientsProvider),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState('No silent clients — every live client is still raising queries.',
              icon: Icons.sentiment_satisfied_alt_outlined);
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Live clients with zero post-go-live queries. In an MSME ERP base '
                'this is rarely contentment — it usually means they reverted to Excel.',
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    leading: const Icon(Icons.volume_off_outlined),
                    title: Text(c.name),
                    subtitle: Text('Last query ${fmtRelativeDays(c.lastQueryAt)}'),
                    trailing: Text('${c.daysSilent ?? '—'}d silent'),
                    onTap: () => context.go('/clients/${c.clientId}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
