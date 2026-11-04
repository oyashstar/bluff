import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../supabase/supabase_providers.dart';
import 'project_model.dart';

/// Project / stage data access. Dashboards read the board view; mutations go
/// through tables and the DB functions (fn_apply_stage_template,
/// fn_recompute_health). No client-side aggregation.
class ProjectRepository {
  ProjectRepository(this._client);
  final SupabaseClient _client;

  Future<List<ProjectBoardRow>> board({String? clientId}) async {
    var q = _client.from('v_project_board').select();
    if (clientId != null) q = q.eq('client_id', clientId);
    final rows = await q.order('current_stage_seq', ascending: true);
    return (rows as List)
        .map((e) => ProjectBoardRow.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Project> getById(String id) async {
    final row = await _client.from('project').select().eq('id', id).single();
    return Project.fromMap(row);
  }

  Future<Project> create({
    required String clientId,
    required String title,
    required ProjectType type,
    String? ownerUserId,
    String? stageTemplateId,
    DateTime? plannedGolive,
  }) async {
    final row = await _client
        .from('project')
        .insert({
          'client_id': clientId,
          'title': title,
          'type': type.wire,
          'owner_user_id': ownerUserId,
          'stage_template_id': stageTemplateId,
          'planned_golive': plannedGolive?.toIso8601String(),
          'status': ProjectStatus.notStarted.wire,
        })
        .select()
        .single();
    return Project.fromMap(row);
  }

  /// Update status and/or owner. Planned-go-live changes bump golive_revisions
  /// (the health score counts revisions) — done here rather than in a trigger
  /// so the "revision" concept stays an app-level decision.
  Future<void> update(
    String id, {
    ProjectStatus? status,
    String? ownerUserId,
    DateTime? plannedGolive,
    bool bumpGoliveRevision = false,
    DateTime? actualGolive,
  }) async {
    final patch = <String, dynamic>{};
    if (status != null) patch['status'] = status.wire;
    if (ownerUserId != null) patch['owner_user_id'] = ownerUserId;
    if (plannedGolive != null) patch['planned_golive'] = plannedGolive.toIso8601String();
    if (actualGolive != null) patch['actual_golive'] = actualGolive.toIso8601String();
    if (bumpGoliveRevision) {
      final current = await getById(id);
      patch['golive_revisions'] = current.goliveRevisions + 1;
    }
    if (patch.isEmpty) return;
    await _client.from('project').update(patch).eq('id', id);
    await recomputeHealth(id);
  }

  Future<List<StageTemplate>> templates() async {
    final rows = await _client
        .from('stage_template')
        .select()
        .eq('is_active', true)
        .order('name');
    return (rows as List)
        .map((e) => StageTemplate.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Materialise project_stage rows from a template via the DB function.
  Future<void> applyTemplate(String projectId, String templateId) async {
    await _client.rpc('fn_apply_stage_template', params: {
      'p_project_id': projectId,
      'p_template_id': templateId,
    });
    await recomputeHealth(projectId);
  }

  Future<List<ProjectStage>> stages(String projectId) async {
    final rows = await _client
        .from('project_stage')
        .select('*, stage_template_item(name, seq, requires_signoff, default_duration_days), signoff(signed_on)')
        .eq('project_id', projectId);
    final list = (rows as List)
        .map((e) => ProjectStage.fromMap(e as Map<String, dynamic>))
        .toList();
    // Order by template seq in Dart (robust across PostgREST embed-order syntax).
    list.sort((a, b) => a.seq.compareTo(b.seq));
    return list;
  }

  /// Move a stage to a new status, stamping actual dates. Starting a stage sets
  /// actual_start if unset; completing sets actual_end.
  Future<void> setStageStatus({
    required String stageId,
    required String projectId,
    required StageStatus status,
    String? blockedReason,
  }) async {
    final today = DateTime.now().toUtc().toIso8601String();
    final patch = <String, dynamic>{'status': status.wire};
    if (status == StageStatus.inProgress) {
      patch['actual_start'] = _coalesceDate(await _stageField(stageId, 'actual_start'), today);
    }
    if (status == StageStatus.done) {
      patch['actual_start'] = _coalesceDate(await _stageField(stageId, 'actual_start'), today);
      patch['actual_end'] = today;
    }
    patch['blocked_reason'] = status == StageStatus.blocked ? blockedReason : null;
    await _client.from('project_stage').update(patch).eq('id', stageId);
    await recomputeHealth(projectId);
  }

  Future<Object?> _stageField(String stageId, String field) async {
    final row = await _client.from('project_stage').select(field).eq('id', stageId).single();
    return row[field];
  }

  String _coalesceDate(Object? existing, String fallback) =>
      (existing as String?) ?? fallback;

  Future<void> recomputeHealth(String projectId) async {
    await _client.rpc('fn_recompute_health', params: {'p_project_id': projectId});
  }

  /// Record a sign-off against a stage (for a stage whose template item
  /// requires one). Clears the sign-off-pending drag on the health score.
  Future<void> addSignoff({
    required String stageId,
    required String projectId,
    String? contactId,
    DateTime? signedOn,
    String? remarks,
    String? documentPath,
  }) async {
    await _client.from('signoff').insert({
      'project_stage_id': stageId,
      'contact_id': contactId,
      'signed_on': (signedOn ?? DateTime.now()).toUtc().toIso8601String(),
      'remarks': remarks,
      'document_path': documentPath,
    });
    await recomputeHealth(projectId);
  }

  // --- modules in scope ---
  Future<List<Map<String, dynamic>>> projectModules(String projectId) async {
    final rows = await _client
        .from('project_module')
        .select('*, module_master(code, name, seq)')
        .eq('project_id', projectId);
    final list = (rows as List).cast<Map<String, dynamic>>();
    list.sort((a, b) {
      final sa = ((a['module_master'] as Map?)?['seq'] as num?)?.toInt() ?? 0;
      final sb = ((b['module_master'] as Map?)?['seq'] as num?)?.toInt() ?? 0;
      return sa.compareTo(sb);
    });
    return list;
  }

  Future<void> setModuleInScope({
    required String projectId,
    required String moduleId,
    required bool inScope,
  }) async {
    // Upsert on the (project_id, module_id) unique key.
    await _client.from('project_module').upsert({
      'project_id': projectId,
      'module_id': moduleId,
      'in_scope': inScope,
    }, onConflict: 'project_id,module_id');
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(supabaseClientProvider));
});
