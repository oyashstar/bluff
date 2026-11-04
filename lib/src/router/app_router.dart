import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/dashboards/client_360_screen.dart';
import '../features/dashboards/consultant_load_screen.dart';
import '../features/dashboards/dashboards_hub_screen.dart';
import '../features/dashboards/implementation_board_screen.dart';
import '../features/dashboards/outstanding_screen.dart';
import '../features/dashboards/query_heatmap_screen.dart';
import '../features/dashboards/root_cause_mix_screen.dart';
import '../features/dashboards/sla_board_screen.dart';
import '../features/dashboards/stalled_screen.dart';
import '../features/overview/overview_screen.dart';
import '../features/projects/project_detail_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/queries/queries_screen.dart';
import '../features/queries/query_detail_screen.dart';
import '../features/queries/quick_log_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../supabase/supabase_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/overview',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loggingIn = state.matchedLocation == '/login';
      if (session == null) return loggingIn ? null : '/login';
      if (loggingIn) return '/overview';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/overview', builder: (c, s) => const OverviewScreen()),
          GoRoute(path: '/search', builder: (c, s) => const SearchScreen()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          GoRoute(path: '/clients', builder: (c, s) => const ClientsScreen(), routes: [
            GoRoute(
              path: ':id',
              builder: (c, s) => ClientDetailScreen(clientId: s.pathParameters['id']!),
            ),
          ]),
          GoRoute(path: '/projects', builder: (c, s) => const ProjectsScreen(), routes: [
            GoRoute(
              path: ':id',
              builder: (c, s) => ProjectDetailScreen(projectId: s.pathParameters['id']!),
            ),
          ]),
          GoRoute(path: '/quick-log', builder: (c, s) => const QuickLogScreen()),
          GoRoute(path: '/queries', builder: (c, s) => const QueriesScreen(), routes: [
            GoRoute(
              path: ':id',
              builder: (c, s) => QueryDetailScreen(queryId: s.pathParameters['id']!),
            ),
          ]),
          GoRoute(path: '/dashboards', builder: (c, s) => const DashboardsHubScreen(), routes: [
            GoRoute(path: 'board', builder: (c, s) => const ImplementationBoardScreen()),
            GoRoute(path: 'stalled', builder: (c, s) => const StalledScreen()),
            GoRoute(path: 'load', builder: (c, s) => const ConsultantLoadScreen()),
            GoRoute(path: 'heatmap', builder: (c, s) => const QueryHeatmapScreen()),
            GoRoute(path: 'root-cause', builder: (c, s) => const RootCauseMixScreen()),
            GoRoute(path: 'client360', builder: (c, s) => const Client360Screen()),
            GoRoute(path: 'sla', builder: (c, s) => const SlaBoardScreen()),
            GoRoute(path: 'outstanding', builder: (c, s) => const OutstandingScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}
