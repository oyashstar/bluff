/// Dart mirrors of the Postgres enum types. Each carries its wire value (the
/// exact string stored in the database) and a human label for the UI.
///
/// Kept hand-written and in one place so the closed sets stay a contract, and
/// so a new value added in a migration is a visible one-line change here.
library;

T _parse<T>(List<T> values, String? wire, String Function(T) toWire, T fallback) {
  if (wire == null) return fallback;
  for (final v in values) {
    if (toWire(v) == wire) return v;
  }
  return fallback;
}

enum ProjectType {
  newImplementation('NewImplementation', 'New implementation'),
  moduleExpansion('ModuleExpansion', 'Module expansion'),
  versionUpgrade('VersionUpgrade', 'Version upgrade'),
  reimplementation('Reimplementation', 'Reimplementation');

  const ProjectType(this.wire, this.label);
  final String wire;
  final String label;

  static ProjectType fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, ProjectType.newImplementation);
}

enum ProjectStatus {
  notStarted('NotStarted', 'Not started'),
  inProgress('InProgress', 'In progress'),
  onHold('OnHold', 'On hold'),
  hypercare('Hypercare', 'Hypercare'),
  closed('Closed', 'Closed'),
  dropped('Dropped', 'Dropped');

  const ProjectStatus(this.wire, this.label);
  final String wire;
  final String label;

  bool get isOpen =>
      this == notStarted || this == inProgress || this == onHold || this == hypercare;

  static ProjectStatus fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, ProjectStatus.notStarted);
}

enum StageStatus {
  pending('Pending', 'Pending'),
  inProgress('InProgress', 'In progress'),
  blocked('Blocked', 'Blocked'),
  done('Done', 'Done'),
  skipped('Skipped', 'Skipped');

  const StageStatus(this.wire, this.label);
  final String wire;
  final String label;

  bool get isComplete => this == done || this == skipped;

  static StageStatus fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, StageStatus.pending);
}

enum QueryChannel {
  phone('Phone', 'Phone'),
  whatsapp('WhatsApp', 'WhatsApp'),
  email('Email', 'Email'),
  siteVisit('SiteVisit', 'Site visit'),
  portal('Portal', 'Portal');

  const QueryChannel(this.wire, this.label);
  final String wire;
  final String label;

  static QueryChannel fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, QueryChannel.phone);
}

enum QuerySeverity {
  s1('S1', 'S1 · production stopped'),
  s2('S2', 'S2 · major, workaround'),
  s3('S3', 'S3 · minor / cosmetic'),
  s4('S4', 'S4 · how-to');

  const QuerySeverity(this.wire, this.label);
  final String wire;
  final String label;

  String get short => wire;

  static QuerySeverity fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, QuerySeverity.s3);
}

enum QueryStatus {
  newQuery('New', 'New'),
  acknowledged('Acknowledged', 'Acknowledged'),
  inProgress('InProgress', 'In progress'),
  awaitingClient('AwaitingClient', 'Awaiting client'),
  awaitingDev('AwaitingDev', 'Awaiting dev'),
  resolved('Resolved', 'Resolved'),
  closed('Closed', 'Closed'),
  reopened('Reopened', 'Reopened'),
  cancelled('Cancelled', 'Cancelled');

  const QueryStatus(this.wire, this.label);
  final String wire;
  final String label;

  bool get pausesClock => this == awaitingClient || this == awaitingDev;
  bool get isOpen =>
      this != resolved && this != closed && this != cancelled;

  static QueryStatus fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, QueryStatus.newQuery);

  /// The transitions the DB status machine (fn_transition_query) permits from
  /// this state. Mirrors the SQL so the UI only offers legal moves; the DB is
  /// still the enforcer.
  List<QueryStatus> get allowedNext => switch (this) {
        newQuery => [acknowledged, inProgress, cancelled],
        acknowledged => [inProgress, awaitingClient, awaitingDev, cancelled],
        inProgress => [awaitingClient, awaitingDev, resolved, cancelled],
        awaitingClient => [inProgress, resolved, cancelled],
        awaitingDev => [inProgress, resolved, cancelled],
        resolved => [closed, reopened],
        reopened => [inProgress, awaitingClient, awaitingDev, cancelled],
        closed => [reopened],
        cancelled => [],
      };
}

enum RootCause {
  bug('Bug', 'Bug'),
  trainingGap('TrainingGap', 'Training gap'),
  customisationRequest('CustomisationRequest', 'Customisation request'),
  dataIssue('DataIssue', 'Data issue'),
  infrastructure('Infrastructure', 'Infrastructure'),
  expectedBehaviour('ExpectedBehaviour', 'Expected behaviour'),
  enhancement('Enhancement', 'Enhancement');

  const RootCause(this.wire, this.label);
  final String wire;
  final String label;

  static RootCause? fromWire(String? w) {
    if (w == null) return null;
    for (final v in values) {
      if (v.wire == w) return v;
    }
    return null;
  }
}

enum AppRole {
  admin('Admin', 'Admin'),
  manager('Manager', 'Manager'),
  consultant('Consultant', 'Consultant'),
  support('Support', 'Support'),
  viewer('Viewer', 'Viewer');

  const AppRole(this.wire, this.label);
  final String wire;
  final String label;

  bool get canEditDelivery =>
      this == admin || this == manager || this == consultant;
  bool get canEditSupport => canEditDelivery || this == support;
  bool get isAdmin => this == admin;

  static AppRole fromWire(String? w) =>
      _parse(values, w, (e) => e.wire, AppRole.viewer);
}
