import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_financial_provider.dart';

/// Phase 5 implementation. Reads the `client_financial_snapshot` table — which
/// is OUR table in OUR Supabase project, populated server-side by the
/// `sync-financials` Edge Function. This class never touches Oracle and holds
/// no connection string: the isolation rules are intact. It simply surfaces the
/// latest snapshot the seam has synced.
class SnapshotFinancialProvider implements ClientFinancialProvider {
  SnapshotFinancialProvider(this._client);
  final SupabaseClient _client;

  @override
  Future<ClientFinancials?> latestFor(String clientId) async {
    final row = await _client
        .from('client_financial_snapshot')
        .select()
        .eq('client_id', clientId)
        .order('as_of', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return ClientFinancials(
      clientId: clientId,
      totalOutstanding: (row['total_outstanding'] as num?)?.toDouble(),
      overdue90Plus: (row['overdue_90_plus'] as num?)?.toDouble(),
      asOf: row['as_of'] == null ? null : DateTime.tryParse(row['as_of'].toString()),
      syncedAt: row['synced_at'] == null ? null : DateTime.tryParse(row['synced_at'].toString()),
    );
  }
}
