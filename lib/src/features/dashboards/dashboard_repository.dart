import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/supabase_providers.dart';
import '../projects/project_model.dart';
import 'dashboard_models.dart';

/// Reads the dashboard SQL views. Every method is one view read — no
/// aggregation in Dart.
class DashboardRepository {
  DashboardRepository(this._client);
  final SupabaseClient _client;

  Future<List<ProjectBoardRow>> stalled({int minDays = 14}) async {
    final rows = await _client
        .from('v_stalled_projects')
        .select()
        .gte('days_stalled', minDays)
        .order('days_stalled', ascending: false);
    return (rows as List)
        .map((e) => ProjectBoardRow.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ConsultantLoad>> consultantLoad() async {
    final rows = await _client.from('v_consultant_load').select();
    final list = (rows as List)
        .map((e) => ConsultantLoad.fromMap(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Future<List<HeatmapCell>> heatmap() async {
    final rows = await _client.from('v_query_heatmap').select();
    return (rows as List).map((e) => HeatmapCell.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<RootCauseMonth>> rootCauseMix() async {
    final rows = await _client.from('v_root_cause_mix').select().order('month');
    return (rows as List)
        .map((e) => RootCauseMonth.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Client360>> client360() async {
    final rows = await _client.from('v_client_360').select().order('name');
    return (rows as List).map((e) => Client360.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Client360?> client360For(String clientId) async {
    final row =
        await _client.from('v_client_360').select().eq('client_id', clientId).maybeSingle();
    return row == null ? null : Client360.fromMap(row);
  }

  Future<List<SlaBoardRow>> slaBoard() async {
    final rows = await _client.from('v_sla_board').select();
    return (rows as List).map((e) => SlaBoardRow.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<SilentClient>> silentClients() async {
    final rows =
        await _client.from('v_silent_clients').select().order('days_silent', ascending: false);
    return (rows as List).map((e) => SilentClient.fromMap(e as Map<String, dynamic>)).toList();
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});
