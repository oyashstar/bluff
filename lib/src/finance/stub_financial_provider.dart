import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_financial_provider.dart';

/// v1 implementation: there is no ERP link, so there is nothing to return.
/// Returning null (rather than throwing or faking zeros) lets the UI render an
/// honest "Outstanding: not linked" state wherever a figure would go.
class StubFinancialProvider implements ClientFinancialProvider {
  const StubFinancialProvider();

  @override
  Future<ClientFinancials?> latestFor(String clientId) async => null;
}

/// Swap this provider's implementation in Phase 5 for one backed by the
/// `client_financial_snapshot` table. No UI code should need to change: it
/// depends on [ClientFinancialProvider], not on the stub.
final clientFinancialProvider = Provider<ClientFinancialProvider>((ref) {
  return const StubFinancialProvider();
});
