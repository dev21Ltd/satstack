import 'constants.dart';
import 'models.dart';

double netBtcHoldings(List<Purchase> purchases, List<Sale> sales) {
  return purchases.fold(0.0, (sum, p) => sum + p.amountBTC) -
      sales.fold(0.0, (sum, s) => sum + s.amountBTC);
}

double totalPurchasedBtc(List<Purchase> purchases) {
  return purchases.fold(0.0, (sum, p) => sum + p.amountBTC);
}

typedef PriceAt = Map<Currency, double> Function(DateTime date);

double totalInvestmentInCurrency(
  List<Purchase> purchases,
  Currency to,
  Map<Currency, double> btcPrices, {
  PriceAt? pricesOnDate,
}) {
  return purchases.fold(
    0.0,
    (sum, p) =>
        sum +
        convertViaBtc(
          p.totalCashSpent,
          p.cashCurrency,
          to,
          pricesOnDate?.call(p.date) ?? btcPrices,
        ),
  );
}

double totalSalesProceedsInCurrency(
  List<Sale> sales,
  Currency to,
  Map<Currency, double> btcPrices, {
  PriceAt? pricesOnDate,
}) {
  return sales.fold(
    0.0,
    (sum, s) =>
        sum +
        convertViaBtc(
          s.amountBTC * s.price,
          s.originalCurrency,
          to,
          pricesOnDate?.call(s.date) ?? btcPrices,
        ),
  );
}

double portfolioValueInCurrency(
  double netBtc,
  Currency currency,
  Map<Currency, double> btcPrices,
) {
  return netBtc * (btcPrices[currency] ?? 0.0);
}

double profitLossInCurrency({
  required List<Purchase> purchases,
  required List<Sale> sales,
  required Currency currency,
  required Map<Currency, double> btcPrices,
  PriceAt? pricesOnDate,
}) {
  final current = portfolioValueInCurrency(
    netBtcHoldings(purchases, sales),
    currency,
    btcPrices,
  );
  final invested = totalInvestmentInCurrency(
    purchases,
    currency,
    btcPrices,
    pricesOnDate: pricesOnDate,
  );
  final sold = totalSalesProceedsInCurrency(
    sales,
    currency,
    btcPrices,
    pricesOnDate: pricesOnDate,
  );
  return current + sold - invested;
}

double averagePurchasePriceInCurrency(
  List<Purchase> purchases,
  Currency to,
  Map<Currency, double> btcPrices, {
  PriceAt? pricesOnDate,
}) {
  final bought = totalPurchasedBtc(purchases);
  if (bought == 0) return 0;
  return totalInvestmentInCurrency(
        purchases,
        to,
        btcPrices,
        pricesOnDate: pricesOnDate,
      ) /
      bought;
}

double profitLossPercent(double profitLoss, double investment) {
  if (investment == 0) return 0;
  return (profitLoss / investment) * 100;
}
