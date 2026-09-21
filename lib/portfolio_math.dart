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

/// P&L for **all activity from [start] through [end] (today)**: every purchase
/// and sale in that window (including later edits). Remaining net BTC from
/// that window is valued at the live price. Same idea as all-time ROI.
double roiForActivityInRange({
  required List<Purchase> purchases,
  required List<Sale> sales,
  required DateTime start,
  required DateTime end,
  required Currency currency,
  required Map<Currency, double> btcPrices,
  PriceAt? pricesOnDate,
}) {
  final rangeStart = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

  double invested = 0;
  double btcIn = 0;
  for (final purchase in purchases) {
    if (purchase.date.isBefore(rangeStart) || purchase.date.isAfter(rangeEnd)) {
      continue;
    }
    final fx = pricesOnDate?.call(purchase.date) ?? btcPrices;
    invested += convertViaBtc(
      purchase.totalCashSpent,
      purchase.cashCurrency,
      currency,
      fx,
    );
    btcIn += purchase.amountBTC;
  }
  if (invested <= 1e-9) return 0;

  double sold = 0;
  double btcOut = 0;
  for (final sale in sales) {
    if (sale.date.isBefore(rangeStart) || sale.date.isAfter(rangeEnd)) {
      continue;
    }
    final fx = pricesOnDate?.call(sale.date) ?? btcPrices;
    sold += convertViaBtc(
      sale.amountBTC * sale.price,
      sale.originalCurrency,
      currency,
      fx,
    );
    btcOut += sale.amountBTC;
  }

  final remainingBtc = btcIn - btcOut;
  final current = remainingBtc > 0 ? remainingBtc * (btcPrices[currency] ?? 0) : 0.0;
  return (current + sold - invested) / invested * 100;
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
