/// The ERP seam, Dart side.
///
/// Hard constraint #5: all financial data (outstanding, overdue, …) sits behind
/// this abstraction. v1 ships [StubFinancialProvider] which returns null. The
/// real implementation (Phase 5) reads [client_financial_snapshot] — which is
/// populated by a scheduled Edge Function against a read-only Oracle view. The
/// Flutter app never talks to Oracle and never holds a DB connection string.
///
/// Designing this seam now costs about an hour. Retrofitting it later is a
/// rewrite, which is exactly why it exists on day one even though it does
/// nothing yet.
library;

/// A client's financial position as of a point in time. All fields nullable:
/// "we don't know yet" and "the ERP link isn't live" are first-class states,
/// not zeros.
class ClientFinancials {
  const ClientFinancials({
    required this.clientId,
    this.totalOutstanding,
    this.overdue90Plus,
    this.asOf,
    this.syncedAt,
  });

  final String clientId;
  final double? totalOutstanding;
  final double? overdue90Plus;
  final DateTime? asOf;
  final DateTime? syncedAt;

  /// True when there is no real figure to show (stub, or seam not yet synced).
  bool get isUnavailable => totalOutstanding == null && overdue90Plus == null;
}

/// Read-only access to client financials. Intentionally has no write surface:
/// nothing in this app writes financial data.
abstract interface class ClientFinancialProvider {
  /// Latest known snapshot for a client, or null if none exists.
  Future<ClientFinancials?> latestFor(String clientId);
}
