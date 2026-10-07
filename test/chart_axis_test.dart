import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/charts.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/models.dart';

void main() {
  test('a long-range peak is not rounded up to a distant 150k ceiling', () {
    final axis = chartYAxis(0, 100000);
    expect(axis.maxY, greaterThanOrEqualTo(100000));
    expect(axis.maxY, lessThanOrEqualTo(120000));
    expect((axis.maxY - 100000) / 100000, lessThanOrEqualTo(0.2));
  });

  test('each range keeps its own peak near the top of the scale', () {
    final recent = chartYAxis(100000, 112000);
    final long = chartYAxis(0, 140000);
    expect(recent.maxY, lessThan(130000));
    expect(long.maxY, greaterThanOrEqualTo(140000));
    expect(long.maxY, lessThan(170000));
    expect(long.minY, 0);
  });

  test('a negative dip stays on the scale', () {
    final axis = chartYAxis(-20000, 80000);
    expect(axis.minY, lessThanOrEqualTo(-20000));
    expect(axis.maxY, greaterThanOrEqualTo(80000));
  });

  test('a long range keeps one label per year, with today at the end', () {
    final dates = <DateTime>[
      for (var year = 2019; year <= 2026; year++) ...[
        DateTime(year, 1, 15),
        DateTime(year, 8, 2),
      ],
    ];
    final ticks = chartCalendarTickIndices(dates, ChartBottomScale.years);
    expect(ticks.first, 0);
    expect(ticks.last, dates.length - 1);
    expect(ticks.length, 8);
    final years = [for (final i in ticks) dates[i].year];
    expect(years, [2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026]);
    expect(years.toSet().length, years.length);
  });

  test('a one-year range keeps one label per month', () {
    final dates = <DateTime>[
      DateTime(2025, 10, 11),
      DateTime(2025, 12, 4),
      DateTime(2026, 1, 19),
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 10),
      DateTime(2026, 8, 2),
      DateTime(2026, 10, 7),
    ];
    final ticks = chartCalendarTickIndices(dates, ChartBottomScale.months);
    final labels = [
      for (final i in ticks) '${dates[i].year}-${dates[i].month}',
    ];
    expect(labels, ['2025-10', '2025-12', '2026-1', '2026-3', '2026-8', '2026-10']);
    expect(ticks.last, dates.length - 1);
  });

  test('a one-month range uses the start, the middle, and today', () {
    final dates = <DateTime>[
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 10),
      DateTime(2026, 9, 18),
      DateTime(2026, 10, 7),
    ];
    final ticks = chartCalendarTickIndices(dates, ChartBottomScale.days);
    expect(ticks.first, 0);
    expect(ticks.last, 3);
    expect(ticks.length, 3);
    expect(ticks[1], 2);
  });

  test('a narrow axis keeps the ends and drops years that would collide', () {
    final dates = <DateTime>[
      for (var year = 2016; year <= 2026; year++) DateTime(year, 6, 1),
    ];
    String yearAt(int index) => '${dates[index].year}';
    final shown = visibleChartCalendarTicks(
      dates: dates,
      scale: ChartBottomScale.years,
      axisWidth: 140,
      labelAt: yearAt,
    );
    expect(shown.first, 0);
    expect(shown.last, dates.length - 1);
    expect(shown.length, lessThan(dates.length));
    final labels = [for (final i in shown) yearAt(i)];
    expect(labels.toSet().length, labels.length);
    for (var i = 1; i < shown.length; i++) {
      final gap = shown[i] - shown[i - 1];
      expect(gap, greaterThan(0));
    }
  });

  test('a crowded opening year does not erase the years after it', () {
    final dates = <DateTime>[
      DateTime(2022, 10, 7),
      DateTime(2022, 11, 21),
      for (var month = 1; month <= 6; month++) DateTime(2023, month, 10),
      for (var month = 1; month <= 6; month++) DateTime(2024, month, 10),
      for (var month = 1; month <= 6; month++) DateTime(2025, month, 10),
      DateTime(2026, 10, 7),
    ];
    String yearAt(int index) => '${dates[index].year}';
    final shown = visibleChartCalendarTicks(
      dates: dates,
      scale: ChartBottomScale.years,
      axisWidth: 280,
      labelAt: yearAt,
    );
    expect([for (final index in shown) yearAt(index)], [
      '2022',
      '2023',
      '2024',
      '2025',
      '2026',
    ]);
  });

  test('a range remembers the highest and lowest stack value', () {
    final marks = stackRangeMarks([20000, double.nan, 100000, 90000]);
    expect(marks, isNotNull);
    expect(marks!.low, 20000);
    expect(marks.high, 100000);
    expect(formatChartAxisPrice(152759, '\$'), '\$152.8K');
    expect(formatChartAxisPrice(130000, '\$'), '\$130.0K');
    expect(formatChartAxisPrice(850, '\$'), '\$850');
  });

  test('an exact stack mark replaces only the round number it covers', () {
    final marks = StackRangeMarks(20000, 152800);
    const axisSize = 200.0;
    expect(
      chartGridLabelCoveredByStackMark(
        gridValue: 150000,
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
      ),
      isTrue,
    );
    expect(
      chartGridLabelCoveredByStackMark(
        gridValue: 100000,
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
      ),
      isFalse,
    );
    expect(
      visibleStackMarks(
        marks: const StackRangeMarks(100000, 100400),
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
      ),
      [100400],
    );
  });

  test('today is marked only when it sits between the high and the low', () {
    const marks = StackRangeMarks(20000, 100000);
    const axisSize = 400.0;
    expect(
      visibleStackMarks(
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
        current: 90000,
      ),
      [100000, 20000, 90000],
    );
    expect(
      visibleStackMarks(
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: 80,
        current: 90000,
      ),
      [100000, 20000],
    );
    expect(
      visibleStackMarks(
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
        current: 100000,
      ),
      [100000, 20000],
    );
    expect(
      visibleStackMarks(
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
        current: 20000,
      ),
      [100000, 20000],
    );
    expect(
      chartGridLabelCoveredByStackMark(
        gridValue: 90000,
        marks: marks,
        minY: 0,
        maxY: 200000,
        axisSize: axisSize,
        current: 90000,
      ),
      isTrue,
    );
  });

  test('labels that cover each other keep the closing date', () {
    final dates = <DateTime>[DateTime(2024, 1, 1), DateTime(2026, 1, 1)];
    final shown = visibleChartCalendarTicks(
      dates: dates,
      scale: ChartBottomScale.years,
      axisWidth: 30,
      labelAt: (index) => '${dates[index].year}',
    );
    expect(shown, [1]);
  });

  testWidgets('Max draws the closing year once', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sameYear = DateTime(now.year, now.month == 6 ? 3 : 6, 15);
    final dates = <DateTime>[
      for (var year = now.year - 10; year < now.year; year++)
        DateTime(year, 1, 15),
      sameYear,
      today,
    ];
    final purchases = [
      for (var i = 0; i < dates.length; i++)
        Purchase(
          id: 'p$i',
          date: dates[i],
          amountBTC: 0.01,
          pricePerBTC: 10000,
          cashCurrency: Currency.USD,
        ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PortfolioChart(
          purchases: purchases,
          sales: const [],
          isDarkMode: true,
          currentBtcPrice: 60000,
          currency: Currency.USD,
          portfolioValue: 7200,
          totalInvestment: 1200,
          profitLoss: 6000,
          profitLossPercentage: 500,
          onEditPurchase: (_) {},
          onDeletePurchase: (_) {},
          onEditSale: (_) {},
          onDeleteSale: (_) {},
          denomination: Denomination.BTC,
          btcPrices: const {Currency.USD: 60000},
          holdingsHidden: false,
          expanded: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max'));
    await tester.pumpAndSettle();

    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('${now.year - 5}'), findsOneWidget);
    expect(find.text('${now.year - 10}'), findsOneWidget);
  });

  testWidgets('a month shows the highest and lowest stack worth', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final purchases = [
      Purchase(
        id: 'old',
        date: now.subtract(const Duration(days: 40)),
        amountBTC: 1,
        pricePerBTC: 20000,
        cashCurrency: Currency.USD,
      ),
      Purchase(
        id: 'month',
        date: now.subtract(const Duration(days: 10)),
        amountBTC: 1,
        pricePerBTC: 50000,
        cashCurrency: Currency.USD,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PortfolioChart(
          purchases: purchases,
          sales: const [],
          isDarkMode: true,
          currentBtcPrice: 45000,
          currency: Currency.USD,
          portfolioValue: 90000,
          totalInvestment: 70000,
          profitLoss: 20000,
          profitLossPercentage: 28,
          onEditPurchase: (_) {},
          onDeletePurchase: (_) {},
          onEditSale: (_) {},
          onDeleteSale: (_) {},
          denomination: Denomination.BTC,
          btcPrices: const {Currency.USD: 45000},
          holdingsHidden: false,
          expanded: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Highest stack in this range \$100.0K'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Lowest stack in this range \$20.0K'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Current stack \$90.0K'), findsOneWidget);
    expect(find.text('\$100.0K'), findsOneWidget);
    expect(find.text('\$20.0K'), findsOneWidget);
  });
}
