import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardsHubScreen extends ConsumerWidget {
  const DashboardsHubScreen({super.key});

  static const _cards = <_DashCard>[
    _DashCard('board', Icons.view_kanban, 'Implementation board', 'Kanban by stage, colour by health'),
    _DashCard('stalled', Icons.hourglass_empty, 'Stalled list', 'No activity for N days'),
    _DashCard('load', Icons.groups_outlined, 'Consultant load', 'Open projects & tickets per person'),
    _DashCard('heatmap', Icons.grid_on, 'Query heatmap', 'Module × severity, last 30 days'),
    _DashCard('root-cause', Icons.pie_chart_outline, 'Root-cause mix', 'Closed tickets by root cause'),
    _DashCard('client360', Icons.person_search, 'Client 360', 'One row per client'),
    _DashCard('sla', Icons.timer_outlined, 'SLA board', 'Breached & at-risk by assignee'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboards')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = (constraints.maxWidth / 280).floor().clamp(1, 4);
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: cols,
            childAspectRatio: 1.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final c in _cards)
                Card(
                  child: InkWell(
                    onTap: () => context.go('/dashboards/${c.path}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(c.icon, size: 28, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(c.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DashCard {
  const _DashCard(this.path, this.icon, this.title, this.subtitle);
  final String path;
  final IconData icon;
  final String title;
  final String subtitle;
}
