import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/app_user.dart';
import '../../auth/auth_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Persistent chrome around every authenticated screen: a branded top bar
/// (Finsys logo + signed-in user), a navigation rail on wide layouts (office
/// screens) and a bottom bar on phones (field).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _destinations = <_Dest>[
    _Dest('/overview', Icons.home_outlined, Icons.home, 'Overview'),
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

    final content = wide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (i) => _go(context, i),
                labelType: NavigationRailLabelType.all,
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
          )
        : child;

    return Scaffold(
      body: Column(
        children: [
          _BrandBar(wide: wide),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
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

/// Branded top bar: Finsys logo on the left, signed-in user + theme + sign-out
/// on the right (mirrors the Finsys ERP top bar).
class _BrandBar extends ConsumerWidget {
  const _BrandBar({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentAppUserProvider).valueOrNull;

    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            const FinsysLogo(height: 30),
            const SizedBox(width: 12),
            Container(width: 1, height: 22, color: scheme.outlineVariant),
            const SizedBox(width: 12),
            Text('Tracker',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
            const Spacer(),
            const _ThemeMenu(),
            const SizedBox(width: 4),
            if (user != null) _UserChip(user: user, wide: wide),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.user, required this.wide});
  final AppUser user;
  final bool wide;

  String get _initials {
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: finsysBlue.withValues(alpha: 0.15),
            child: Text(_initials,
                style: const TextStyle(
                    color: finsysBlue, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          if (wide) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(user.role.label,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeMenu extends ConsumerWidget {
  const _ThemeMenu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final icon = switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(icon),
      initialValue: mode,
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (_) => const [
        PopupMenuItem(value: ThemeMode.system, child: Text('System')),
        PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
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
