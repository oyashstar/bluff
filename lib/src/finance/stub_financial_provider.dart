import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'client_financial_provider.dart';
import 'snapshot_financial_provider.dart';

/// v1 implementation: there is no ERP link, so there is nothing to return.
/// Returning null (rather than throwing or faking zeros) lets the UI render an
/// honest "Outstanding: not linked" state wherever a figure would go.
class StubFinancialProvider implements ClientFinancialProvider {
  const StubFinancialProvider();

  @override
  Future<ClientFinancials?> latestFor(String clientId) async => null;
}

/// Whether the ERP seam is live. **Ships false** (the brief: ship the stub, do
/// not implement a real one in this build). When the `sync-financials` Edge
/// Function is deployed and populating `client_financial_snapshot`, flip it at
/// build time with `--dart-define=FINANCIAL_SEAM_LIVE=true` — no UI changes,
/// because every screen depends on [ClientFinancialProvider], not the impl.
const bool financialSeamLive =
    bool.fromEnvironment('FINANCIAL_SEAM_LIVE', defaultValue: false);

final clientFinancialProvider = Provider<ClientFinancialProvider>((ref) {
  if (financialSeamLive) {
    return SnapshotFinancialProvider(ref.watch(supabaseClientProvider));
  }
  return const StubFinancialProvider();
});

