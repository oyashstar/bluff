import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../core/formatting.dart';
import '../dashboards/dashboard_providers.dart';
import '../projects/project_providers.dart';
import '../queries/query_providers.dart';
import '../settings/settings_repository.dart';

/// At-a-glance home. Each tile is a count/figure derived from a view the tool
/// already serves, and taps through to the screen that acts on it. This is what
/// the Monday review meeting opens first.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final companyName = settings?[SettingKeys.companyName];

    return Scaffold(
      appBar: AppBar(
        title: Text(companyName == null || companyName.isEmpty ? 'Overview' : companyName),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshAll(ref),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshAll(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hello${user == null ? '' : ', ${user.displayName}'} 👋',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 200).floor().clamp(2, 4);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _ActiveProjectsTile(onTap: () => context.go('/projects')),
                  _OpenQueriesTile(onTap: () => context.go('/queries')),
                  _CriticalQueriesTile(onTap: () => context.go('/queries')),
                  _BreachedTile(onTap: () => context.go('/dashboards/sla')),
                  _StalledTile(onTap: () => context.go('/dashboards/stalled')),
                  _SilentTile(onTap: () => context.go('/dashboards/client360')),
                  _OutstandingTile(onTap: () => context.go('/dashboards/outstanding')),
                ],
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bolt),
                title: const Text('Quick-log a query'),
                subtitle: const Text('Client, severity, one line — under 20 seconds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/quick-log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(projectBoardProvider);
    ref.invalidate(queryListProvider);
    ref.invalidate(stalledProjectsProvider);
    ref.invalidate(silentClientsProvider);
    ref.invalidate(slaBoardProvider);
    ref.invalidate(outstandingProvider);
    ref.invalidate(appSettingsProvider);
  }
}

/// A KPI tile that renders a count or figure consistently.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.child,
    required this.onTap,
    this.color,
  });
  final String label;
  final IconData icon;
  final Widget child;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: color),
                child: child,
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _count(AsyncValue<int> v) => v.when(
      data: (n) => Text('$n'),
      loading: () => const Text('…'),
      error: (_, __) => const Text('!'),
    );

class _ActiveProjectsTile extends ConsumerWidget {
  const _ActiveProjectsTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(projectBoardProvider).whenData((l) => l.where((p) => p.status.isOpen).length);
    return _Tile(label: 'Active projects', icon: Icons.dashboard_outlined, onTap: onTap, child: _count(v));
  }
}

class _OpenQueriesTile extends ConsumerWidget {
  const _OpenQueriesTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse the open-only query list.
    final v = ref.watch(queryListProvider).whenData((l) => l.length);
    return _Tile(label: 'Open queries', icon: Icons.support_agent_outlined, onTap: onTap, child: _count(v));
  }
}

class _CriticalQueriesTile extends ConsumerWidget {
  const _CriticalQueriesTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(queryListProvider).whenData(
          (l) => l.where((q) => (q.severity.short == 'S1' || q.severity.short == 'S2') && q.status.isOpen).length,
        );
    return _Tile(label: 'Open S1/S2', icon: Icons.priority_high, color: const Color(0xFFC62828), onTap: onTap, child: _count(v));
  }
}

class _BreachedTile extends ConsumerWidget {
  const _BreachedTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(slaBoardProvider).whenData(
          (l) => l.where((r) => r.resolutionStatus == 'breached' || r.responseStatus == 'breached').length,
        );
    return _Tile(label: 'SLA breached', icon: Icons.timer_outlined, color: const Color(0xFFC62828), onTap: onTap, child: _count(v));
  }
}

class _StalledTile extends ConsumerWidget {
  const _StalledTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stalledProjectsProvider).whenData((l) => l.length);
    return _Tile(label: 'Stalled', icon: Icons.hourglass_empty, color: const Color(0xFFF9A825), onTap: onTap, child: _count(v));
  }
}

class _SilentTile extends ConsumerWidget {
  const _SilentTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(silentClientsProvider).whenData((l) => l.length);
    return _Tile(label: 'Silent clients', icon: Icons.volume_off_outlined, color: const Color(0xFFF9A825), onTap: onTap, child: _count(v));
  }
}

class _OutstandingTile extends ConsumerWidget {
  const _OutstandingTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(outstandingProvider).whenData(
          (l) => l.fold<num>(0, (a, r) => a + (r.totalOutstanding ?? 0)),
        );
    return _Tile(
      label: 'Outstanding',
      icon: Icons.account_balance_outlined,
      onTap: onTap,
      child: v.when(
        data: (total) => FittedBox(child: Text(total == 0 ? '—' : fmtMoney(total))),
        loading: () => const Text('…'),
        error: (_, __) => const Text('!'),
      ),
    );
  }
}
