import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/historical_fx.dart';
import 'package:satstack/models.dart';
import 'package:satstack/services.dart';

void main() {
  const fiats = ['usd', 'gbp', 'eur', 'cad', 'aud', 'jpy', 'cny'];

  test('CoinGecko body maps all seven currencies', () {
    final prices = ApiService.btcPricesFromCoinGecko({
      'bitcoin': {
        'usd': 100000,
        'gbp': 80000,
        'eur': 90000,
        'cad': 130000,
        'aud': 140000,
        'jpy': 15000000,
        'cny': 700000,
      },
    });
    expect(prices.keys, fiats);
    expect(prices['jpy'], 15000000);
  });

  test('Coinbase string rates map all seven currencies', () {
    final prices = ApiService.btcPricesFromCoinbase({
      'data': {
        'currency': 'BTC',
        'rates': {
          'USD': '85310.42',
          'GBP': '64211.36',
          'EUR': '75068.55',
          'CAD': '120936.87',
          'AUD': '122440.75',
          'JPY': '13374507.48',
          'CNY': '571161.86',
        },
      },
    });
    expect(prices.keys, fiats);
    expect(prices['usd'], closeTo(85310.42, 0.001));
    expect(prices['cny'], closeTo(571161.86, 0.001));
  });

  test('Blockchain ticker uses the last trade for each currency', () {
    final prices = ApiService.btcPricesFromBlockchain({
      'USD': {'last': 85293.93, 'symbol': '\$'},
      'GBP': {'last': 64193.07},
      'EUR': {'last': 75078.11},
      'CAD': {'last': 120940.4},
      'AUD': {'last': 122411.89},
      'JPY': {'last': 13376852.31},
      'CNY': {'last': 571827.59},
    });
    expect(prices['gbp'], closeTo(64193.07, 0.001));
    expect(prices.length, 7);
  });

  test('Coinbase history keeps each dated price', () {
    final points = ApiService.pricePointsFromCoinbaseHistoric({
      'data': {
        'currency': 'BTC',
        'prices': [
          {'price': '81991.715', 'time': '1792368000'},
          {'price': '1017.12', 'time': '1388966400'},
        ],
      },
    });
    expect(points, hasLength(2));
    expect(points.first.price, closeTo(81991.715, 0.001));
    expect(points.first.date.toUtc(), DateTime.utc(2026, 10, 19));
    expect(points.last.price, closeTo(1017.12, 0.001));
    expect(points.last.date.toUtc(), DateTime.utc(2014, 1, 6));
  });

  test('a midnight UTC price stays on that calendar day', () {
    final fx = HistoricalFx();
    // Same instants CoinGecko returns: midnight UTC, constructed the way
    // the parser does (epoch milliseconds, local flag).
    PriceDataPoint atUtcMidnight(int year, int month, int day, double price) {
      return PriceDataPoint(
        DateTime.fromMillisecondsSinceEpoch(
          DateTime.utc(year, month, day).millisecondsSinceEpoch,
        ),
        price,
      );
    }

    fx.ingestForTest(Currency.USD, [
      atUtcMidnight(2026, 9, 25, 50),
      atUtcMidnight(2026, 9, 26, 100),
    ]);

    expect(fx.priceNear(DateTime(2026, 9, 26), Currency.USD), 100);
    expect(fx.priceNear(DateTime(2026, 9, 25), Currency.USD), 50);
    expect(
      fx.pricesOn(DateTime(2026, 9, 26), {Currency.USD: 1})[Currency.USD],
      100,
    );
    expect(btcPriceDayKey(DateTime.utc(2026, 9, 26)), '2026-09-26');
  });

  test('a missing day uses the nearest saved rate', () {
    final fx = HistoricalFx();
    PriceDataPoint at(int month, int day, double price) {
      return PriceDataPoint(DateTime.utc(2024, month, day), price);
    }

    fx.ingestForTest(Currency.USD, [
      at(9, 1, 100),
      at(9, 20, 140),
    ]);
    fx.ingestForTest(Currency.GBP, [
      PriceDataPoint(DateTime.utc(2024, 9, 1), 80),
      PriceDataPoint(DateTime.utc(2024, 9, 20), 100),
    ]);

    final gap = fx.pricesOn(DateTime(2024, 9, 10), {
      Currency.USD: 1,
      Currency.GBP: 1,
    });
    expect(gap[Currency.USD], 100);
    expect(gap[Currency.GBP], 80);

    final exact = fx.pricesOn(DateTime(2024, 9, 20), {
      Currency.USD: 1,
      Currency.GBP: 1,
    });
    expect(exact[Currency.USD], 140);
    expect(exact[Currency.GBP], 100);
  });

  test('a provider missing a currency is rejected', () {
    expect(
      () => ApiService.btcPricesFromCoinbase({
        'data': {
          'rates': {'USD': '1', 'GBP': '1', 'EUR': '1'},
        },
      }),
      throwsA(isA<ApiException>()),
    );
  });
}
