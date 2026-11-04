import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../supabase/supabase_providers.dart';

/// Phase 0 landing shell. It proves the loop end to end — a provisioned user
/// signs in, lands here, and signs out — and lays out the screens to come in
/// build order. Each item is wired as its feature ships; none are faked.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _plannedScreens = <(_Phase, String, String)>[
    (_Phase.p1, 'Clients', 'Client list & detail'),
    (_Phase.p1, 'Projects', 'Project list & stage board'),
    (_Phase.p2, 'Quick-log query', 'The make-or-break screen: log in under 20s'),
    (_Phase.p2, 'Queries', 'List & detail, status machine via fn_transition_query'),
    (_Phase.p3, 'Implementation board', 'Kanban by stage, colour by health'),
    (_Phase.p3, 'Stalled list', 'No activity for N days, sorted by days stalled'),
    (_Phase.p3, 'Consultant load', 'Open projects & tickets per person'),
    (_Phase.p3, 'Query heatmap', 'Module × severity, last 30 days'),
    (_Phase.p3, 'Root-cause mix', 'Closed tickets by root cause over time'),
    (_Phase.p3, 'Client 360', 'One client: status, queries, touchpoints'),
    (_Phase.p3, 'SLA board', 'Breached & at-risk, grouped by assignee'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final email = session?.user.email ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finsys Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(email, style: const TextStyle(fontSize: 13))),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Phase 0 skeleton. Login, routing and RLS are live. '
              'Screens below ship phase by phase — see docs/DECISIONS.md.',
            ),
          ),
          const Divider(),
          for (final (phase, title, subtitle) in _plannedScreens)
            ListTile(
              enabled: false,
              leading: _PhaseChip(phase),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
      ),
    );
  }
}

enum _Phase { p1, p2, p3 }

class _PhaseChip extends StatelessWidget {
  const _PhaseChip(this.phase);
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      _Phase.p1 => 'P1',
      _Phase.p2 => 'P2',
      _Phase.p3 => 'P3',
    };
    return CircleAvatar(radius: 16, child: Text(label, style: const TextStyle(fontSize: 12)));
  }
}
