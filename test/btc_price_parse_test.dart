import 'package:flutter_test/flutter_test.dart';
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
