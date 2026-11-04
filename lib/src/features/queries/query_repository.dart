import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../supabase/supabase_providers.dart';
import 'query_model.dart';

/// Query / comment / attachment data access. Status changes go ONLY through
/// fn_transition_query (the DB enforces the machine and the SLA pause).
class QueryRepository {
  QueryRepository(this._client);
  final SupabaseClient _client;

  static const _select =
      '*, client:client_id(name, code), module_master:module_id(name), '
      'assignee:assignee_user_id(name)';

  Future<List<Query>> list({
    String? clientId,
    bool openOnly = false,
    QuerySeverity? severity,
    String? assigneeUserId,
  }) async {
    var q = _client.from('query').select(_select);
    if (clientId != null) q = q.eq('client_id', clientId);
    if (severity != null) q = q.eq('severity', severity.wire);
    if (assigneeUserId != null) q = q.eq('assignee_user_id', assigneeUserId);
    if (openOnly) {
      q = q.not('status', 'in', '(Resolved,Closed,Cancelled)');
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List).map((e) => Query.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Query> getById(String id) async {
    final row = await _client.from('query').select(_select).eq('id', id).single();
    return Query.fromMap(row);
  }

  /// The quick-log path: minimal required fields. ticket_no, SLA due dates and
  /// status default on the server.
  Future<Query> create({
    required String clientId,
    required QuerySeverity severity,
    required String subject,
    String? description,
    String? moduleId,
    String? projectId,
    String? contactId,
    QueryChannel channel = QueryChannel.phone,
    String? assigneeUserId,
    bool isPostGolive = false,
  }) async {
    final row = await _client
        .from('query')
        .insert({
          'client_id': clientId,
          'severity': severity.wire,
          'subject': subject,
          'description': description,
          'module_id': moduleId,
          'project_id': projectId,
          'contact_id': contactId,
          'channel': channel.wire,
          'assignee_user_id': assigneeUserId,
          'is_post_golive': isPostGolive,
        })
        .select(_select)
        .single();
    return Query.fromMap(row);
  }

  /// Change status through the DB function. For Resolved/Closed the root cause
  /// must already be set — [rootCause]/[resolutionNotes] are written first.
  Future<Query> transition(
    String id,
    QueryStatus to, {
    RootCause? rootCause,
    String? resolutionNotes,
  }) async {
    if (rootCause != null || resolutionNotes != null) {
      final patch = <String, dynamic>{};
      if (rootCause != null) patch['root_cause'] = rootCause.wire;
      if (resolutionNotes != null) patch['resolution_notes'] = resolutionNotes;
      await _client.from('query').update(patch).eq('id', id);
    }
    final row = await _client.rpc('fn_transition_query', params: {
      'p_query_id': id,
      'p_to': to.wire,
    });
    // rpc returns the composite row; re-fetch with joins for a consistent shape.
    if (row is Map<String, dynamic>) {
      return getById(id);
    }
    return getById(id);
  }

  Future<void> reassign(String id, String? assigneeUserId) async {
    await _client.from('query').update({'assignee_user_id': assigneeUserId}).eq('id', id);
  }

  Future<void> setSeverity(String id, QuerySeverity severity) async {
    await _client.from('query').update({'severity': severity.wire}).eq('id', id);
  }

  // --- comments ---
  Future<List<QueryComment>> comments(String queryId) async {
    final rows = await _client
        .from('query_comment')
        .select('*, author:user_id(name)')
        .eq('query_id', queryId)
        .order('created_at');
    return (rows as List)
        .map((e) => QueryComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment({
    required String queryId,
    required String body,
    bool isInternal = true,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('query_comment').insert({
      'query_id': queryId,
      'user_id': uid,
      'body': body,
      'is_internal': isInternal,
    });
  }

  // --- attachments via Supabase Storage ---
  static const _bucket = 'attachments';

  Future<List<Map<String, dynamic>>> attachments(String queryId) async {
    final rows = await _client
        .from('attachment')
        .select()
        .eq('entity_type', 'query')
        .eq('entity_id', queryId)
        .order('uploaded_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> uploadAttachment({
    required String queryId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    final path = 'query/$queryId/${DateTime.now().millisecondsSinceEpoch}_$filename';
    await _client.storage.from(_bucket).uploadBinary(path, bytes);
    await _client.from('attachment').insert({
      'entity_type': 'query',
      'entity_id': queryId,
      'storage_path': path,
      'uploaded_by': uid,
    });
  }

  Future<String> signedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 60 * 10);
  }
}

final queryRepositoryProvider = Provider<QueryRepository>((ref) {
  return QueryRepository(ref.watch(supabaseClientProvider));
});
