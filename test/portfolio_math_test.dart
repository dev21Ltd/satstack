import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/models.dart';
import 'package:satstack/portfolio_math.dart';

void main() {
  final prices = {
    Currency.USD: 100000.0,
    Currency.GBP: 80000.0,
    Currency.EUR: 90000.0,
    Currency.CAD: 0.0,
    Currency.AUD: 0.0,
    Currency.JPY: 0.0,
    Currency.CNY: 0.0,
  };

  Purchase buy({
    required double btc,
    required double price,
    Currency currency = Currency.USD,
    DateTime? date,
  }) {
    return Purchase(
      id: 'p-$btc-$price',
      date: date ?? DateTime(2024, 1, 1),
      amountBTC: btc,
      pricePerBTC: price,
      cashCurrency: currency,
    );
  }

  Sale sell({
    required double btc,
    required double price,
    Currency currency = Currency.USD,
    DateTime? date,
  }) {
    return Sale(
      id: 's-$btc-$price',
      date: date ?? DateTime(2024, 6, 1),
      amountBTC: btc,
      price: price,
      originalCurrency: currency,
    );
  }

  test('net holdings subtracts sales from purchases', () {
    final purchases = [buy(btc: 2, price: 20000), buy(btc: 1, price: 30000)];
    final sales = [sell(btc: 0.5, price: 40000)];
    expect(netBtcHoldings(purchases, sales), closeTo(2.5, 1e-9));
    expect(totalPurchasedBtc(purchases), 3);
  });

  test('average purchase price uses purchased BTC, not net holdings', () {
    final purchases = [buy(btc: 2, price: 20000)];
    final sales = [sell(btc: 1, price: 40000)];
    expect(
      averagePurchasePriceInCurrency(purchases, Currency.USD, prices),
      20000,
    );
    expect(netBtcHoldings(purchases, sales), 1);
  });

  test('P&L is current value plus sale proceeds minus cost', () {
    final purchases = [buy(btc: 2, price: 20000)];
    final sales = [sell(btc: 1, price: 40000)];
    // remaining 1 BTC * 100000 + 40000 proceeds - 40000 cost = 100000
    expect(
      profitLossInCurrency(
        purchases: purchases,
        sales: sales,
        currency: Currency.USD,
        btcPrices: prices,
      ),
      closeTo(100000, 0.01),
    );
  });

  test('convertViaBtc uses BTC prices as current FX', () {
    expect(convertViaBtc(80000, Currency.GBP, Currency.USD, prices), 100000);
    expect(convertViaBtc(50, Currency.USD, Currency.USD, prices), 50);
    expect(convertViaBtc(100, Currency.USD, Currency.CAD, prices), 100);
  });

  test('mixed-currency cost converts through live BTC prices', () {
    final purchases = [
      buy(btc: 1, price: 80000, currency: Currency.GBP),
    ];
    expect(
      totalInvestmentInCurrency(purchases, Currency.USD, prices),
      closeTo(100000, 0.01),
    );
  });

  test('historical FX converts a trade at its own date rates', () {
    final purchases = [
      buy(btc: 1, price: 80000, currency: Currency.GBP, date: DateTime(2024, 1, 1)),
    ];
    Map<Currency, double> onDate(DateTime date) => {
          Currency.USD: 80000,
          Currency.GBP: 40000,
          Currency.EUR: 0,
          Currency.CAD: 0,
          Currency.AUD: 0,
          Currency.JPY: 0,
          Currency.CNY: 0,
        };
    expect(
      totalInvestmentInCurrency(
        purchases,
        Currency.USD,
        prices,
        pricesOnDate: onDate,
      ),
      closeTo(160000, 0.01),
    );
  });

  test('satoshi helpers round-trip', () {
    expect(btcToSatoshis(1), 100000000);
    expect(satoshisToBtc(50000000), 0.5);
    expect(formatDenomination(1, Denomination.SATS).replaceAll(RegExp(r'[^0-9]'), ''), '100000000');
    expect(formatDenomination(1, Denomination.SATS).endsWith('sats'), isTrue);
  });
}
