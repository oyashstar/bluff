import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import 'query_model.dart';
import 'query_repository.dart';

/// Filters for the query list screen. Immutable; the screen builds a fresh one
/// on each change so toggling one facet never clobbers another.
class QueryFilter {
  const QueryFilter({this.openOnly = true, this.severity, this.assigneeUserId});
  final bool openOnly;
  final QuerySeverity? severity;
  final String? assigneeUserId;
}

final queryFilterProvider = StateProvider<QueryFilter>((ref) => const QueryFilter());

final queryListProvider = FutureProvider<List<Query>>((ref) async {
  final f = ref.watch(queryFilterProvider);
  return ref.watch(queryRepositoryProvider).list(
        openOnly: f.openOnly,
        severity: f.severity,
        assigneeUserId: f.assigneeUserId,
      );
});

final clientQueriesProvider =
    FutureProvider.family<List<Query>, String>((ref, clientId) async {
  return ref.watch(queryRepositoryProvider).list(clientId: clientId);
});

final queryProvider = FutureProvider.family<Query, String>((ref, id) async {
  return ref.watch(queryRepositoryProvider).getById(id);
});

final queryCommentsProvider =
    FutureProvider.family<List<QueryComment>, String>((ref, queryId) async {
  return ref.watch(queryRepositoryProvider).comments(queryId);
});

final queryAttachmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, queryId) async {
  return ref.watch(queryRepositoryProvider).attachments(queryId);
});
