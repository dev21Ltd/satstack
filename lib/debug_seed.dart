import 'constants.dart';
import 'models.dart';
import 'services.dart';

/// Debug-only demo book: ~50 trades (buys + sells) from 2019–2026,
/// mix of lots that are up vs today's price and lots that are down.
Future<void> seedDemoPortfolio(StorageService storage) async {
  await storage.savePurchases(_demoPurchases());
  await storage.saveSales(_demoSales());
  print('SEED_DEMO: ${_demoPurchases().length} purchases, ${_demoSales().length} sales');
}

List<Purchase> _demoPurchases() {
  const usd = Currency.USD;
  const gbp = Currency.GBP;
  const eur = Currency.EUR;
  Purchase p(String id, DateTime d, double btc, double px, [Currency c = usd]) =>
      Purchase(id: id, date: d, amountBTC: btc, pricePerBTC: px, cashCurrency: c);

  return [
    p('d01', DateTime(2019, 4, 12), 0.12, 5200),
    p('d02', DateTime(2019, 7, 3), 0.08, 10100),
    p('d03', DateTime(2019, 11, 18), 0.05, 7400, gbp),
    p('d04', DateTime(2020, 3, 16), 0.15, 4800),
    p('d05', DateTime(2020, 5, 22), 0.06, 9100, eur),
    p('d06', DateTime(2020, 8, 9), 0.04, 11800),
    p('d07', DateTime(2020, 12, 17), 0.07, 19200),
    p('d08', DateTime(2021, 1, 8), 0.03, 35500, gbp),
    p('d09', DateTime(2021, 2, 21), 0.05, 48200),
    p('d10', DateTime(2021, 4, 14), 0.04, 62800),
    p('d11', DateTime(2021, 7, 20), 0.06, 31800),
    p('d12', DateTime(2021, 10, 2), 0.03, 48100, eur),
    p('d13', DateTime(2021, 11, 9), 0.02, 67500),
    p('d14', DateTime(2022, 1, 24), 0.05, 35200),
    p('d15', DateTime(2022, 3, 11), 0.04, 39100, gbp),
    p('d16', DateTime(2022, 6, 18), 0.1, 19800),
    p('d17', DateTime(2022, 9, 5), 0.06, 18800),
    p('d18', DateTime(2022, 11, 21), 0.08, 16200),
    p('d19', DateTime(2023, 1, 15), 0.05, 21100, eur),
    p('d20', DateTime(2023, 3, 4), 0.04, 22400),
    p('d21', DateTime(2023, 6, 12), 0.07, 25900),
    p('d22', DateTime(2023, 8, 28), 0.03, 26100, gbp),
    p('d23', DateTime(2023, 10, 16), 0.05, 28500),
    p('d24', DateTime(2023, 12, 9), 0.04, 43800),
    p('d25', DateTime(2024, 1, 11), 0.03, 46200),
    p('d26', DateTime(2024, 3, 5), 0.04, 67100, eur),
    p('d27', DateTime(2024, 4, 20), 0.02, 64800),
    p('d28', DateTime(2024, 6, 8), 0.05, 69500),
    p('d29', DateTime(2024, 8, 14), 0.04, 58400, gbp),
    p('d30', DateTime(2024, 10, 3), 0.03, 62200),
    p('d31', DateTime(2024, 12, 16), 0.02, 104500),
    p('d32', DateTime(2025, 1, 22), 0.03, 102800),
    p('d33', DateTime(2025, 3, 9), 0.04, 83800, eur),
    p('d34', DateTime(2025, 5, 18), 0.05, 103200),
    p('d35', DateTime(2025, 7, 2), 0.02, 108400),
    p('d36', DateTime(2025, 8, 27), 0.03, 111900),
    p('d37', DateTime(2025, 10, 11), 0.04, 109200, gbp),
    p('d38', DateTime(2025, 12, 4), 0.03, 97200),
    p('d39', DateTime(2026, 1, 19), 0.05, 101500),
    p('d40', DateTime(2026, 3, 8), 0.04, 76800),
    p('d41', DateTime(2026, 4, 21), 0.03, 84500, eur),
    p('d42', DateTime(2026, 6, 14), 0.04, 104200),
    p('d43', DateTime(2026, 8, 2), 0.02, 114800),
    p('d44', DateTime(2026, 8, 28), 0.03, 111200),
    p('d45', DateTime(2026, 9, 10), 0.02, 116400),
  ];
}

List<Sale> _demoSales() {
  Sale s(String id, DateTime d, double btc, double px, [Currency c = Currency.USD]) =>
      Sale(id: id, date: d, amountBTC: btc, price: px, originalCurrency: c);

  return [
    s('s01', DateTime(2021, 4, 16), 0.04, 63200),
    s('s02', DateTime(2021, 11, 12), 0.03, 64800, Currency.GBP),
    s('s03', DateTime(2022, 6, 20), 0.05, 19100),
    s('s04', DateTime(2023, 3, 8), 0.03, 22800, Currency.EUR),
    s('s05', DateTime(2024, 3, 12), 0.04, 71200),
    s('s06', DateTime(2024, 12, 18), 0.02, 106000),
    s('s07', DateTime(2025, 8, 30), 0.03, 110500, Currency.GBP),
    s('s08', DateTime(2026, 3, 10), 0.04, 75200),
  ];
}
