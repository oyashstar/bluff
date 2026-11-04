import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_value_widget.dart';
import 'dashboard_providers.dart';

/// Open projects and open tickets per person — catches the one consultant
/// quietly carrying eleven go-lives. Reads v_consultant_load.
class ConsultantLoadScreen extends ConsumerWidget {
  const ConsultantLoadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(consultantLoadProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboards')),
        title: const Text('Consultant load'),
      ),
      body: AsyncValueView(
        value: load,
        onRetry: () => ref.invalidate(consultantLoadProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyState('No active users.');
          final maxTotal = list.fold<int>(1, (m, e) => e.total > m ? e.total : m);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
                        Text(c.role, style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      const SizedBox(height: 8),
                      _Bar(label: 'Projects', value: c.openProjects, max: maxTotal, color: const Color(0xFF1565C0)),
                      const SizedBox(height: 4),
                      _Bar(label: 'Queries', value: c.openQueries, max: maxTotal, color: const Color(0xFFEF6C00)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max, required this.color});
  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 72, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : value / max,
            minHeight: 14,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.end)),
    ]);
  }
}
