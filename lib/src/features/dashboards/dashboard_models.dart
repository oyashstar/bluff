DateTime? _ts(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

/// v_consultant_load
class ConsultantLoad {
  const ConsultantLoad({
    required this.userId,
    required this.name,
    required this.role,
    required this.openProjects,
    required this.openQueries,
  });
  final String userId;
  final String name;
  final String role;
  final int openProjects;
  final int openQueries;

  int get total => openProjects + openQueries;

  factory ConsultantLoad.fromMap(Map<String, dynamic> m) => ConsultantLoad(
        userId: m['user_id'] as String,
        name: (m['name'] as String?) ?? '—',
        role: (m['role'] as String?) ?? '',
        openProjects: (m['open_projects'] as num?)?.toInt() ?? 0,
        openQueries: (m['open_queries'] as num?)?.toInt() ?? 0,
      );
}

/// v_query_heatmap (module × severity, last 30 days)
class HeatmapCell {
  const HeatmapCell({
    required this.moduleId,
    required this.moduleName,
    required this.severity,
    required this.count,
  });
  final String moduleId;
  final String moduleName;
  final String severity;
  final int count;

  factory HeatmapCell.fromMap(Map<String, dynamic> m) => HeatmapCell(
        moduleId: m['module_id'] as String,
        moduleName: (m['module_name'] as String?) ?? '—',
        severity: (m['severity'] as String?) ?? 'S3',
        count: (m['query_count'] as num?)?.toInt() ?? 0,
      );
}

/// v_root_cause_mix (closed by root cause and month)
class RootCauseMonth {
  const RootCauseMonth({required this.month, required this.rootCause, required this.count});
  final DateTime month;
  final String rootCause;
  final int count;

  factory RootCauseMonth.fromMap(Map<String, dynamic> m) => RootCauseMonth(
        month: _ts(m['month']) ?? DateTime.now(),
        rootCause: (m['root_cause'] as String?) ?? '—',
        count: (m['query_count'] as num?)?.toInt() ?? 0,
      );
}

/// v_client_360
class Client360 {
  const Client360({
    required this.clientId,
    required this.code,
    required this.name,
    this.segment,
    this.amcStatus,
    required this.activeProjects,
    required this.openQueries,
    required this.openCriticalQueries,
    this.lastTouchpointAt,
    required this.postGoliveQueries,
    this.latestOutstanding,
    this.outstandingAsOf,
  });
  final String clientId;
  final String code;
  final String name;
  final String? segment;
  final String? amcStatus;
  final int activeProjects;
  final int openQueries;
  final int openCriticalQueries;
  final DateTime? lastTouchpointAt;
  final int postGoliveQueries;
  final num? latestOutstanding;
  final DateTime? outstandingAsOf;

  factory Client360.fromMap(Map<String, dynamic> m) => Client360(
        clientId: m['client_id'] as String,
        code: (m['code'] as String?) ?? '',
        name: (m['name'] as String?) ?? '—',
        segment: m['segment'] as String?,
        amcStatus: m['amc_status'] as String?,
        activeProjects: (m['active_projects'] as num?)?.toInt() ?? 0,
        openQueries: (m['open_queries'] as num?)?.toInt() ?? 0,
        openCriticalQueries: (m['open_critical_queries'] as num?)?.toInt() ?? 0,
        lastTouchpointAt: _ts(m['last_touchpoint_at']),
        postGoliveQueries: (m['post_golive_queries'] as num?)?.toInt() ?? 0,
        latestOutstanding: m['latest_outstanding'] as num?,
        outstandingAsOf: _ts(m['outstanding_as_of']),
      );
}

/// v_sla_board
class SlaBoardRow {
  const SlaBoardRow({
    required this.queryId,
    required this.ticketNo,
    required this.subject,
    required this.severity,
    required this.clientName,
    this.assigneeName,
    this.assigneeUserId,
    required this.responseStatus,
    required this.resolutionStatus,
    this.resolutionDue,
  });
  final String queryId;
  final String ticketNo;
  final String subject;
  final String severity;
  final String clientName;
  final String? assigneeName;
  final String? assigneeUserId;
  final String responseStatus;   // met | pending | breached
  final String resolutionStatus; // on_track | at_risk | breached | met
  final DateTime? resolutionDue;

  factory SlaBoardRow.fromMap(Map<String, dynamic> m) => SlaBoardRow(
        queryId: m['query_id'] as String,
        ticketNo: (m['ticket_no'] as String?) ?? '',
        subject: (m['subject'] as String?) ?? '',
        severity: (m['severity'] as String?) ?? 'S3',
        clientName: (m['client_name'] as String?) ?? '—',
        assigneeName: m['assignee_name'] as String?,
        assigneeUserId: m['assignee_user_id'] as String?,
        responseStatus: (m['response_status'] as String?) ?? 'pending',
        resolutionStatus: (m['resolution_status'] as String?) ?? 'on_track',
        resolutionDue: _ts(m['effective_resolution_due']),
      );
}

/// v_client_outstanding (AR, from the ERP seam)
class ClientOutstanding {
  const ClientOutstanding({
    required this.clientId,
    required this.code,
    required this.name,
    this.erpClientCode,
    this.totalOutstanding,
    this.overdue90Plus,
    this.asOf,
  });
  final String clientId;
  final String code;
  final String name;
  final String? erpClientCode;
  final num? totalOutstanding;
  final num? overdue90Plus;
  final DateTime? asOf;

  bool get isLinked => erpClientCode != null && erpClientCode!.isNotEmpty;
  bool get hasFigure => totalOutstanding != null;

  factory ClientOutstanding.fromMap(Map<String, dynamic> m) => ClientOutstanding(
        clientId: m['client_id'] as String,
        code: (m['code'] as String?) ?? '',
        name: (m['name'] as String?) ?? '—',
        erpClientCode: m['erp_client_code'] as String?,
        totalOutstanding: m['total_outstanding'] as num?,
        overdue90Plus: m['overdue_90_plus'] as num?,
        asOf: _ts(m['as_of']),
      );
}

/// v_silent_clients (churn signal)
class SilentClient {
  const SilentClient({
    required this.clientId,
    required this.name,
    required this.code,
    this.lastQueryAt,
    this.daysSilent,
  });
  final String clientId;
  final String name;
  final String code;
  final DateTime? lastQueryAt;
  final int? daysSilent;

  factory SilentClient.fromMap(Map<String, dynamic> m) => SilentClient(
        clientId: m['client_id'] as String,
        name: (m['name'] as String?) ?? '—',
        code: (m['code'] as String?) ?? '',
        lastQueryAt: _ts(m['last_query_at']),
        daysSilent: (m['days_silent'] as num?)?.toInt(),
      );
}
