import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'project_model.dart';
import 'project_repository.dart';

/// The whole board (all projects). Dashboards and the project list read this.
final projectBoardProvider = FutureProvider<List<ProjectBoardRow>>((ref) async {
  return ref.watch(projectRepositoryProvider).board();
});

/// Board rows for one client (client detail / 360).
final clientProjectsProvider =
    FutureProvider.family<List<ProjectBoardRow>, String>((ref, clientId) async {
  return ref.watch(projectRepositoryProvider).board(clientId: clientId);
});

final projectProvider = FutureProvider.family<Project, String>((ref, id) async {
  return ref.watch(projectRepositoryProvider).getById(id);
});

final projectStagesProvider =
    FutureProvider.family<List<ProjectStage>, String>((ref, projectId) async {
  return ref.watch(projectRepositoryProvider).stages(projectId);
});

final projectModulesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  return ref.watch(projectRepositoryProvider).projectModules(projectId);
});

final stageTemplatesProvider = FutureProvider<List<StageTemplate>>((ref) async {
  return ref.watch(projectRepositoryProvider).templates();
});

/// Refresh helper: invalidate everything tied to a project after a mutation.
void invalidateProject(WidgetRef ref, String projectId) {
  ref.invalidate(projectProvider(projectId));
  ref.invalidate(projectStagesProvider(projectId));
  ref.invalidate(projectModulesProvider(projectId));
  ref.invalidate(projectBoardProvider);
}
