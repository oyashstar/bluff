import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_providers.dart';

DateTime? _ts(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

/// A logged interaction with a client (call, visit, email, meeting). Feeds the
/// health score's staleness signal and the stalled list, so logging one keeps a
/// project visibly alive.
class Touchpoint {
  const Touchpoint({
    required this.id,
    required this.clientId,
    this.projectId,
    this.type,
    required this.occurredOn,
    this.durationMin,
    this.summary,
    this.userName,
  });

  final String id;
  final String clientId;
  final String? projectId;
  final String? type;
  final DateTime occurredOn;
  final int? durationMin;
  final String? summary;
  final String? userName;

  static const types = ['Call', 'Visit', 'Email', 'Meeting', 'WhatsApp', 'Other'];

  factory Touchpoint.fromMap(Map<String, dynamic> m) {
    final u = (m['app_user'] as Map?)?.cast<String, dynamic>();
    return Touchpoint(
      id: m['id'] as String,
      clientId: m['client_id'] as String,
      projectId: m['project_id'] as String?,
      type: m['type'] as String?,
      occurredOn: _ts(m['occurred_on']) ?? DateTime.now(),
      durationMin: m['duration_min'] as int?,
      summary: m['summary'] as String?,
      userName: u?['name'] as String?,
    );
  }
}

class TouchpointRepository {
  TouchpointRepository(this._client);
  final SupabaseClient _client;

  Future<List<Touchpoint>> listForClient(String clientId) async {
    final rows = await _client
        .from('touchpoint')
        .select('*, app_user:user_id(name)')
        .eq('client_id', clientId)
        .order('occurred_on', ascending: false);
    return (rows as List).map((e) => Touchpoint.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({
    required String clientId,
    String? projectId,
    required String type,
    String? summary,
    int? durationMin,
    DateTime? occurredOn,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('touchpoint').insert({
      'client_id': clientId,
      'project_id': projectId,
      'user_id': uid,
      'type': type,
      'summary': summary,
      'duration_min': durationMin,
      'occurred_on': (occurredOn ?? DateTime.now()).toUtc().toIso8601String(),
    });
    // Recompute health for the client's active projects (staleness signal).
    final projects = await _client
        .from('project')
        .select('id')
        .eq('client_id', clientId)
        .not('status', 'in', '(Closed,Dropped)');
    for (final p in (projects as List)) {
      await _client.rpc('fn_recompute_health', params: {'p_project_id': p['id']});
    }
  }
}

final touchpointRepositoryProvider = Provider<TouchpointRepository>((ref) {
  return TouchpointRepository(ref.watch(supabaseClientProvider));
});

final clientTouchpointsProvider =
    FutureProvider.family<List<Touchpoint>, String>((ref, clientId) async {
  return ref.watch(touchpointRepositoryProvider).listForClient(clientId);
});
