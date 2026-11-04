import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../projects/project_model.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

/// Stalled-days threshold (the "N days" in the brief). Adjustable in the UI.
final stalledThresholdProvider = StateProvider<int>((ref) => 14);

final stalledProjectsProvider = FutureProvider<List<ProjectBoardRow>>((ref) async {
  final n = ref.watch(stalledThresholdProvider);
  return ref.watch(dashboardRepositoryProvider).stalled(minDays: n);
});

final consultantLoadProvider = FutureProvider<List<ConsultantLoad>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).consultantLoad();
});

final heatmapProvider = FutureProvider<List<HeatmapCell>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).heatmap();
});

final rootCauseMixProvider = FutureProvider<List<RootCauseMonth>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).rootCauseMix();
});

final client360Provider = FutureProvider<List<Client360>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).client360();
});

final client360ForProvider =
    FutureProvider.family<Client360?, String>((ref, clientId) async {
  return ref.watch(dashboardRepositoryProvider).client360For(clientId);
});

final slaBoardProvider = FutureProvider<List<SlaBoardRow>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).slaBoard();
});

final silentClientsProvider = FutureProvider<List<SilentClient>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).silentClients();
});

final outstandingProvider = FutureProvider<List<ClientOutstanding>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).outstanding();
});
