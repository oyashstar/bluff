import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_providers.dart';
import 'client_model.dart';

/// All client / contact data access. Talks to Supabase directly; RLS authorises.
class ClientRepository {
  ClientRepository(this._client);
  final SupabaseClient _client;

  Future<List<Client>> list({String? search}) async {
    var query = _client.from('client').select();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      query = query.or('name.ilike.%$s%,code.ilike.%$s%');
    }
    final rows = await query.order('name');
    return (rows as List).map((e) => Client.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Client> getById(String id) async {
    final row = await _client.from('client').select().eq('id', id).single();
    return Client.fromMap(row);
  }

  Future<Client> create(Client c) async {
    final row = await _client.from('client').insert(c.toInsert()).select().single();
    return Client.fromMap(row);
  }

  Future<Client> update(String id, Client c) async {
    final row =
        await _client.from('client').update(c.toInsert()).eq('id', id).select().single();
    return Client.fromMap(row);
  }

  Future<List<ClientContact>> contactsFor(String clientId) async {
    final rows = await _client
        .from('client_contact')
        .select()
        .eq('client_id', clientId)
        .order('is_primary', ascending: false)
        .order('name');
    return (rows as List)
        .map((e) => ClientContact.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addContact({
    required String clientId,
    required String name,
    String? role,
    String? phone,
    String? email,
    bool isPrimary = false,
    bool isChampion = false,
  }) async {
    await _client.from('client_contact').insert({
      'client_id': clientId,
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'is_primary': isPrimary,
      'is_champion': isChampion,
    });
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(supabaseClientProvider));
});
