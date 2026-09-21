import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/charts.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/models.dart';
import 'package:satstack/widgets.dart';

/// Pixel 9 Pro logical size at density 3.0 (1280x2856).
const Size pixel9ProSize = Size(426.67, 952);

void _setPhoneSurface(WidgetTester tester, {Size size = pixel9ProSize}) {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(top: 52 * 3, bottom: 24 * 3);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _pumpPhone(WidgetTester tester, Widget child, {Size size = pixel9ProSize}) async {
  _setPhoneSurface(tester, size: size);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 3,
        padding: const EdgeInsets.only(top: 52, bottom: 24),
      ),
      child: Scaffold(body: child),
    ),
  ));
}

void main() {
  testWidgets('CompactCurrencyDisplay fits Pixel 9 Pro width', (tester) async {
    await _pumpPhone(
      tester,
      CompactCurrencyDisplay(
        favoriteCurrency: Currency.USD,
        secondaryCurrency: Currency.JPY,
        selectedCurrency: Currency.JPY,
        prices: const {
          Currency.USD: 117432,
          Currency.JPY: 17500000,
        },
        onCurrencyChanged: (_) {},
        onSettingsPressed: () {},
        isRefreshing: false,
        isDarkMode: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('JPY'), findsOneWidget);
  });

  testWidgets('CompactCurrencyDisplay fits a 360dp phone', (tester) async {
    await _pumpPhone(
      tester,
      CompactCurrencyDisplay(
        favoriteCurrency: Currency.USD,
        secondaryCurrency: Currency.GBP,
        selectedCurrency: Currency.USD,
        prices: const {
          Currency.USD: 117432,
          Currency.GBP: 92000,
        },
        onCurrencyChanged: (_) {},
        onSettingsPressed: () {},
        isRefreshing: false,
        isDarkMode: false,
      ),
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TimeRangeSelector fits Pixel 9 Pro width', (tester) async {
    await _pumpPhone(
      tester,
      TimeRangeSelector(
        selectedTimeRange: TimeRange.DAY,
        onTimeRangeChanged: (_) {},
        isDarkMode: true,
        isRefreshing: false,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1D'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
  });

  testWidgets('AppBar with phone actions does not overflow', (tester) async {
    _setPhoneSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: pixel9ProSize,
          devicePixelRatio: 3,
          padding: EdgeInsets.only(top: 52, bottom: 24),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_bitcoin, color: Color(0xFFF7931A)),
                  SizedBox(width: 6),
                  Text('SatStack'),
                ],
              ),
            ),
            centerTitle: false,
            titleSpacing: 12,
            actions: const [
              IconButton(icon: Icon(Icons.favorite, color: Color(0xFFF7931A)), onPressed: null),
              IconButton(icon: Icon(Icons.visibility), onPressed: null),
              IconButton(icon: Icon(Icons.import_export), onPressed: null),
              IconButton(icon: Icon(Icons.more_vert), onPressed: null),
            ],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('SatStack'), findsOneWidget);
  });

  testWidgets('PortfolioChart fits Pixel 9 Pro width', (tester) async {
    final purchases = [
      Purchase(
        date: DateTime.now().subtract(const Duration(days: 10)),
        amountBTC: 1.75,
        pricePerBTC: 26364,
        cashCurrency: Currency.USD,
      ),
    ];
    await _pumpPhone(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PortfolioChart(
          purchases: purchases,
          sales: const [],
          isDarkMode: true,
          currentBtcPrice: 117432,
          currency: Currency.USD,
          portfolioValue: 205506,
          totalInvestment: 46137,
          profitLoss: 159369,
          profitLossPercentage: 345.4,
          onEditPurchase: (_) {},
          onDeletePurchase: (_) {},
          onEditSale: (_) {},
          onDeleteSale: (_) {},
          denomination: Denomination.BTC,
          btcPrices: const {Currency.USD: 117432},
          holdingsHidden: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('2Y'), findsOneWidget);
    expect(find.text('10Y'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(find.text('All-time ROI'), findsOneWidget);
    expect(find.text('1M ROI'), findsOneWidget);
    expect(find.text('Stack Value'), findsWidgets);
    expect(find.text('Total Investment'), findsOneWidget);
  });

  testWidgets('PortfolioChart survives an import-style data reload', (tester) async {
    final first = [
      Purchase(
        date: DateTime.now().subtract(const Duration(days: 40)),
        amountBTC: 0.5,
        pricePerBTC: 20000,
        cashCurrency: Currency.USD,
      ),
      Purchase(
        date: DateTime.now().subtract(const Duration(days: 10)),
        amountBTC: 1,
        pricePerBTC: 40000,
        cashCurrency: Currency.GBP,
      ),
    ];
    final imported = [
      ...first,
      Purchase(
        date: DateTime.now().subtract(const Duration(days: 3)),
        amountBTC: 0.25,
        pricePerBTC: 90000,
        cashCurrency: Currency.EUR,
      ),
    ];

    Widget chart(List<Purchase> purchases) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PortfolioChart(
          purchases: purchases,
          sales: const [],
          isDarkMode: true,
          currentBtcPrice: 117432,
          currency: Currency.USD,
          portfolioValue: purchases.fold(0.0, (sum, p) => sum + p.amountBTC) * 117432,
          totalInvestment: purchases.fold(0.0, (sum, p) => sum + p.totalCashSpent),
          profitLoss: 1000,
          profitLossPercentage: 10,
          onEditPurchase: (_) {},
          onDeletePurchase: (_) {},
          onEditSale: (_) {},
          onDeleteSale: (_) {},
          denomination: Denomination.BTC,
          btcPrices: const {
            Currency.USD: 117432,
            Currency.GBP: 92000,
            Currency.EUR: 108000,
          },
          holdingsHidden: false,
        ),
      );
    }

    await _pumpPhone(tester, chart(first));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _pumpPhone(tester, chart(imported));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1M'), findsOneWidget);
  });
}
