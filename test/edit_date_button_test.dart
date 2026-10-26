import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/models.dart';
import 'package:satstack/purchase_calendar.dart';

void main() {
  testWidgets('the edit date button shows the day you pick', (tester) async {
    final today = DateTime.now();
    final original = DateTime(today.year, today.month, 1);
    Purchase? saved;
    final prices = {for (final currency in Currency.values) currency: 50000.0};

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PurchaseCalendar(
          purchases: [
            Purchase(
              id: 'p1',
              date: original,
              amountBTC: 0.5,
              pricePerBTC: 20000,
              cashCurrency: Currency.USD,
            ),
          ],
          sales: const [],
          onDateSelected: (_) {},
          isDarkMode: true,
          currentBtcPrice: 50000,
          selectedCurrency: Currency.USD,
          onEditPurchase: (purchase) {
            saved = purchase;
            return true;
          },
          onDeletePurchase: (_) => true,
          onEditSale: (_) => true,
          onDeleteSale: (_) => true,
          denomination: Denomination.BTC,
          btcPrices: prices,
          holdingsHidden: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    final originalLabel = 'Date: ${DateFormat('dd/MM/yyyy').format(original)}';
    expect(find.text(originalLabel), findsOneWidget);

    await tester.tap(find.text(originalLabel));
    await tester.pumpAndSettle();

    late DateTime picked;
    if (today.day > 1) {
      picked = DateTime(today.year, today.month, 2);
      await tester.tap(find.text('2').last);
    } else {
      picked = DateTime(today.year, today.month - 1, 15);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final pickedLabel = 'Date: ${DateFormat('dd/MM/yyyy').format(picked)}';
    expect(find.text(pickedLabel), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.date.year, picked.year);
    expect(saved?.date.month, picked.month);
    expect(saved?.date.day, picked.day);
  });
}
