import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/widgets.dart';

void main() {
  testWidgets('TimeRangeSelector shows all ranges and reports taps', (tester) async {
    TimeRange selected = TimeRange.DAY;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimeRangeSelector(
          selectedTimeRange: selected,
          onTimeRangeChanged: (range) => selected = range,
          isDarkMode: true,
          isRefreshing: false,
        ),
      ),
    ));

    expect(find.text('1D'), findsOneWidget);
    expect(find.text('1W'), findsOneWidget);
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);

    await tester.tap(find.text('1W'));
    await tester.pump();
    expect(selected, TimeRange.WEEK);
  });
}
