import 'package:finsys_tracker/src/finance/client_financial_provider.dart';
import 'package:finsys_tracker/src/finance/stub_financial_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientFinancials', () {
    test('is unavailable when no figures are present', () {
      const f = ClientFinancials(clientId: 'c1');
      expect(f.isUnavailable, isTrue);
    });

    test('is available when an outstanding figure is present', () {
      const f = ClientFinancials(clientId: 'c1', totalOutstanding: 0);
      expect(f.isUnavailable, isFalse);
    });
  });

  group('StubFinancialProvider', () {
    test('returns null for every client in v1', () async {
      const provider = StubFinancialProvider();
      expect(await provider.latestFor('any-client'), isNull);
    });
  });
}
