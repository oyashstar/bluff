import '../../core/enums.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

/// A row of the project table (editable fields).
class Project {
  const Project({
    required this.id,
    required this.clientId,
    required this.type,
    required this.title,
    this.stageTemplateId,
    this.ownerUserId,
    this.plannedGolive,
    this.actualGolive,
    required this.status,
    this.goliveRevisions = 0,
    this.healthScore,
    this.healthBreakdown = const {},
  });

  final String id;
  final String clientId;
  final ProjectType type;
  final String title;
  final String? stageTemplateId;
  final String? ownerUserId;
  final DateTime? plannedGolive;
  final DateTime? actualGolive;
  final ProjectStatus status;
  final int goliveRevisions;
  final int? healthScore;
  final Map<String, dynamic> healthBreakdown;

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        type: ProjectType.fromWire(m['type'] as String?),
        title: m['title'] as String,
        stageTemplateId: m['stage_template_id'] as String?,
        ownerUserId: m['owner_user_id'] as String?,
        plannedGolive: _date(m['planned_golive']),
        actualGolive: _date(m['actual_golive']),
        status: ProjectStatus.fromWire(m['status'] as String?),
        goliveRevisions: (m['golive_revisions'] as int?) ?? 0,
        healthScore: m['health_score'] as int?,
        healthBreakdown:
            (m['health_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// A row of v_project_board — the denormalised board/list view.
class ProjectBoardRow {
  const ProjectBoardRow({
    required this.projectId,
    required this.title,
    required this.type,
    required this.status,
    this.healthScore,
    this.healthBreakdown = const {},
    this.plannedGolive,
    this.ownerName,
    required this.clientId,
    required this.clientName,
    this.clientCode,
    this.segment,
    this.currentStage,
    this.currentStageSeq,
    this.currentStageStatus,
    this.daysInStage,
    this.defaultDurationDays,
    this.daysStalled,
  });

  final String projectId;
  final String title;
  final ProjectType type;
  final ProjectStatus status;
  final int? healthScore;
  final Map<String, dynamic> healthBreakdown;
  final DateTime? plannedGolive;
  final String? ownerName;
  final String clientId;
  final String clientName;
  final String? clientCode;
  final String? segment;
  final String? currentStage;
  final int? currentStageSeq;
  final StageStatus? currentStageStatus;
  final int? daysInStage;
  final int? defaultDurationDays;

  /// Only present on rows read from v_stalled_projects.
  final int? daysStalled;

  /// True when the current stage has run well past its template duration.
  bool get isOverrunning =>
      daysInStage != null &&
      defaultDurationDays != null &&
      defaultDurationDays! > 0 &&
      daysInStage! > defaultDurationDays! * 1.5;

  factory ProjectBoardRow.fromMap(Map<String, dynamic> m) => ProjectBoardRow(
        projectId: m['project_id'] as String,
        title: m['title'] as String,
        type: ProjectType.fromWire(m['type'] as String?),
        status: ProjectStatus.fromWire(m['status'] as String?),
        healthScore: m['health_score'] as int?,
        healthBreakdown:
            (m['health_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
        plannedGolive: _date(m['planned_golive']),
        ownerName: m['owner_name'] as String?,
        clientId: m['client_id'] as String,
        clientName: m['client_name'] as String,
        clientCode: m['client_code'] as String?,
        segment: m['segment'] as String?,
        currentStage: m['current_stage'] as String?,
        currentStageSeq: (m['current_stage_seq'] as num?)?.toInt(),
        currentStageStatus: m['current_stage_status'] == null
            ? null
            : StageStatus.fromWire(m['current_stage_status'] as String?),
        daysInStage: (m['days_in_stage'] as num?)?.toInt(),
        defaultDurationDays: (m['default_duration_days'] as num?)?.toInt(),
        daysStalled: (m['days_stalled'] as num?)?.toInt(),
      );
}

/// A project_stage row joined with its template item (name, seq, sign-off).
class ProjectStage {
  const ProjectStage({
    required this.id,
    required this.projectId,
    this.projectModuleId,
    required this.stageName,
    required this.seq,
    required this.requiresSignoff,
    this.defaultDurationDays = 0,
    required this.status,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.ownerUserId,
    this.blockedReason,
  });

  final String id;
  final String projectId;
  final String? projectModuleId;
  final String stageName;
  final int seq;
  final bool requiresSignoff;
  final int defaultDurationDays;
  final StageStatus status;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String? ownerUserId;
  final String? blockedReason;

  factory ProjectStage.fromMap(Map<String, dynamic> m) {
    final item = (m['stage_template_item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProjectStage(
      id: m['id'] as String,
      projectId: m['project_id'] as String,
      projectModuleId: m['project_module_id'] as String?,
      stageName: (item['name'] as String?) ?? 'Stage',
      seq: (item['seq'] as int?) ?? 0,
      requiresSignoff: (item['requires_signoff'] as bool?) ?? false,
      defaultDurationDays: (item['default_duration_days'] as int?) ?? 0,
      status: StageStatus.fromWire(m['status'] as String?),
      plannedStart: _date(m['planned_start']),
      plannedEnd: _date(m['planned_end']),
      actualStart: _date(m['actual_start']),
      actualEnd: _date(m['actual_end']),
      ownerUserId: m['owner_user_id'] as String?,
      blockedReason: m['blocked_reason'] as String?,
    );
  }
}

/// A row of stage_template (for the template picker).
class StageTemplate {
  const StageTemplate({required this.id, required this.name, required this.projectType});
  final String id;
  final String name;
  final ProjectType projectType;

  factory StageTemplate.fromMap(Map<String, dynamic> m) => StageTemplate(
        id: m['id'] as String,
        name: m['name'] as String,
        projectType: ProjectType.fromWire(m['project_type'] as String?),
      );
}
