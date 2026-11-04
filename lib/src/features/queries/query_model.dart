import '../../core/enums.dart';

DateTime? _ts(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

/// A row of the query table, optionally joined with client/module/assignee
/// names for list and detail display.
class Query {
  const Query({
    required this.id,
    required this.ticketNo,
    required this.clientId,
    this.projectId,
    this.moduleId,
    this.contactId,
    required this.channel,
    required this.severity,
    required this.subject,
    this.description,
    required this.status,
    this.assigneeUserId,
    this.isPostGolive = false,
    required this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.closedAt,
    this.slaResponseDue,
    this.slaResolutionDue,
    this.slaPausedMinutes = 0,
    this.rootCause,
    this.resolutionNotes,
    // joined
    this.clientName,
    this.clientCode,
    this.moduleName,
    this.assigneeName,
  });

  final String id;
  final String ticketNo;
  final String clientId;
  final String? projectId;
  final String? moduleId;
  final String? contactId;
  final QueryChannel channel;
  final QuerySeverity severity;
  final String subject;
  final String? description;
  final QueryStatus status;
  final String? assigneeUserId;
  final bool isPostGolive;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime? slaResponseDue;
  final DateTime? slaResolutionDue;
  final int slaPausedMinutes;
  final RootCause? rootCause;
  final String? resolutionNotes;

  final String? clientName;
  final String? clientCode;
  final String? moduleName;
  final String? assigneeName;

  factory Query.fromMap(Map<String, dynamic> m) {
    final client = (m['client'] as Map?)?.cast<String, dynamic>();
    final module = (m['module_master'] as Map?)?.cast<String, dynamic>();
    final assignee = (m['assignee'] as Map?)?.cast<String, dynamic>();
    return Query(
      id: m['id'] as String,
      ticketNo: m['ticket_no'] as String,
      clientId: m['client_id'] as String,
      projectId: m['project_id'] as String?,
      moduleId: m['module_id'] as String?,
      contactId: m['contact_id'] as String?,
      channel: QueryChannel.fromWire(m['channel'] as String?),
      severity: QuerySeverity.fromWire(m['severity'] as String?),
      subject: m['subject'] as String,
      description: m['description'] as String?,
      status: QueryStatus.fromWire(m['status'] as String?),
      assigneeUserId: m['assignee_user_id'] as String?,
      isPostGolive: (m['is_post_golive'] as bool?) ?? false,
      createdAt: _ts(m['created_at']) ?? DateTime.now(),
      acknowledgedAt: _ts(m['acknowledged_at']),
      resolvedAt: _ts(m['resolved_at']),
      closedAt: _ts(m['closed_at']),
      slaResponseDue: _ts(m['sla_response_due']),
      slaResolutionDue: _ts(m['sla_resolution_due']),
      slaPausedMinutes: (m['sla_paused_minutes'] as int?) ?? 0,
      rootCause: RootCause.fromWire(m['root_cause'] as String?),
      resolutionNotes: m['resolution_notes'] as String?,
      clientName: client?['name'] as String?,
      clientCode: client?['code'] as String?,
      moduleName: module?['name'] as String?,
      assigneeName: assignee?['name'] as String?,
    );
  }
}

class QueryComment {
  const QueryComment({
    required this.id,
    required this.body,
    required this.isInternal,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String body;
  final bool isInternal;
  final DateTime createdAt;
  final String? authorName;

  factory QueryComment.fromMap(Map<String, dynamic> m) {
    final author = (m['author'] as Map?)?.cast<String, dynamic>();
    return QueryComment(
      id: m['id'] as String,
      body: m['body'] as String,
      isInternal: (m['is_internal'] as bool?) ?? true,
      createdAt: _ts(m['created_at']) ?? DateTime.now(),
      authorName: author?['name'] as String?,
    );
  }
}
