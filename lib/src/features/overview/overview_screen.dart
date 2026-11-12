import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../auth/app_user.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../dashboards/dashboard_providers.dart';
import '../projects/project_providers.dart';
import '../queries/query_providers.dart';
import '../settings/settings_repository.dart';

/// At-a-glance home. Each tile is a count/figure derived from a view the tool
/// already serves, and taps through to the screen that acts on it.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final companyName = settings?[SettingKeys.companyName];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
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
            _HeaderCard(user: user?.displayName, company: companyName),
            const SizedBox(height: 20),
            const SectionHeader('Today at a glance'),
            LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 190).floor().clamp(2, 4);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
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
            const SizedBox(height: 20),
            const SectionHeader('Shortcuts'),
            _Shortcut(
              icon: Icons.bolt,
              color: const Color(0xFFF08C00),
              title: 'Quick-log a query',
              subtitle: 'Client, severity, one line — under 20 seconds',
              onTap: () => context.go('/quick-log'),
            ),
            const SizedBox(height: 8),
            _Shortcut(
              icon: Icons.insights_outlined,
              title: 'Open the dashboards',
              subtitle: 'Board, stalled, load, heatmap, root-cause, SLA, outstanding',
              onTap: () => context.go('/dashboards'),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.user, this.company});
  final String? user;
  final String? company;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.track_changes, color: Colors.white),
            const SizedBox(width: 8),
            Text(company == null || company!.isEmpty ? 'Finsys Tracker' : company!,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Text('$greeting${user == null ? '' : ', ${user!.split(' ').first}'} 👋',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}


class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.12), child: Icon(icon, color: c)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

Widget _count(BuildContext context, AsyncValue<int> v) => v.when(
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
    return StatTile(label: 'Active projects', icon: Icons.dashboard_outlined, onTap: onTap, value: _count(context, v));
  }
}

class _OpenQueriesTile extends ConsumerWidget {
  const _OpenQueriesTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(queryListProvider).whenData((l) => l.length);
    return StatTile(label: 'Open queries', icon: Icons.support_agent_outlined, onTap: onTap, value: _count(context, v));
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
    return StatTile(label: 'Open S1/S2', icon: Icons.priority_high, color: const Color(0xFFE03131), onTap: onTap, value: _count(context, v));
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
    return StatTile(label: 'SLA breached', icon: Icons.timer_outlined, color: const Color(0xFFE03131), onTap: onTap, value: _count(context, v));
  }
}

class _StalledTile extends ConsumerWidget {
  const _StalledTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stalledProjectsProvider).whenData((l) => l.length);
    return StatTile(label: 'Stalled', icon: Icons.hourglass_empty, color: const Color(0xFFF08C00), onTap: onTap, value: _count(context, v));
  }
}

class _SilentTile extends ConsumerWidget {
  const _SilentTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(silentClientsProvider).whenData((l) => l.length);
    return StatTile(label: 'Silent clients', icon: Icons.volume_off_outlined, color: const Color(0xFFF08C00), onTap: onTap, value: _count(context, v));
  }
}

class _OutstandingTile extends ConsumerWidget {
  const _OutstandingTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(outstandingProvider).whenData((l) => l.fold<num>(0, (a, r) => a + (r.totalOutstanding ?? 0)));
    return StatTile(
      label: 'Outstanding',
      icon: Icons.account_balance_outlined,
      onTap: onTap,
      value: v.when(
        data: (total) => FittedBox(child: Text(total == 0 ? '—' : fmtMoney(total))),
        loading: () => const Text('…'),
        error: (_, __) => const Text('!'),
      ),
    );
  }
}
