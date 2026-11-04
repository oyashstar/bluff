import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_controller.dart';

/// Persistent chrome around every authenticated screen: a navigation rail on
/// wide layouts (office screens) and a bottom bar on phones (field). Kept plain
/// — restyled constantly, per the brief.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _destinations = <_Dest>[
    _Dest('/clients', Icons.business_outlined, Icons.business, 'Clients'),
    _Dest('/projects', Icons.dashboard_outlined, Icons.dashboard, 'Projects'),
    _Dest('/quick-log', Icons.bolt_outlined, Icons.bolt, 'Quick log'),
    _Dest('/queries', Icons.support_agent_outlined, Icons.support_agent, 'Queries'),
    _Dest('/dashboards', Icons.insights_outlined, Icons.insights, 'Dashboards'),
  ];

  int _indexFor(String loc) {
    final i = _destinations.lastIndexWhere((d) => loc.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  void _go(BuildContext context, int i) => context.go(_destinations[i].path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final index = _indexFor(location);
    final user = ref.watch(currentAppUserProvider).valueOrNull;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _go(context, i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    const Icon(Icons.track_changes, size: 28),
                    const SizedBox(height: 4),
                    Text('Finsys', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      tooltip: 'Sign out (${user?.displayName ?? ''})',
                      icon: const Icon(Icons.logout),
                      onPressed: () => ref.read(authControllerProvider).signOut(),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _go(context, i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Dest {
  const _Dest(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
