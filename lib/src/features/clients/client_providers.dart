import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_model.dart';
import 'client_repository.dart';

/// Search text for the client list (debounced by the UI).
final clientSearchProvider = StateProvider<String>((ref) => '');

final clientListProvider = FutureProvider<List<Client>>((ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  final search = ref.watch(clientSearchProvider);
  return repo.list(search: search);
});

final clientProvider = FutureProvider.family<Client, String>((ref, id) async {
  return ref.watch(clientRepositoryProvider).getById(id);
});

final clientContactsProvider =
    FutureProvider.family<List<ClientContact>, String>((ref, clientId) async {
  return ref.watch(clientRepositoryProvider).contactsFor(clientId);
});

/// Clients seen most recently first — used by the quick-log screen so the
/// consultant's likely client is one tap away.
final recentClientsProvider = FutureProvider<List<Client>>((ref) async {
  // Small data: reuse the full list (already name-sorted). The quick-log UI
  // re-sorts by the consultant's own recent picks held in memory.
  return ref.watch(clientListProvider.future);
});
