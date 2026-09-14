import 'package:flutter_test/flutter_test.dart';
import 'package:satstack/constants.dart';
import 'package:satstack/models.dart';

void main() {
  test('Purchase round-trips through toMap/fromMap', () {
    final original = Purchase(
      id: 'abc',
      date: DateTime.utc(2021, 5, 10),
      amountBTC: 0.25,
      pricePerBTC: 40000,
      cashCurrency: Currency.EUR,
    );
    final restored = Purchase.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.amountBTC, original.amountBTC);
    expect(restored.pricePerBTC, original.pricePerBTC);
    expect(restored.cashCurrency, Currency.EUR);
    expect(restored.totalCashSpent, 10000);
  });

  test('Sale migrates legacy priceUSD records to USD', () {
    final sale = Sale.fromMap({
      'id': 'old',
      'date': '2020-01-01T00:00:00.000',
      'amountBTC': 0.1,
      'priceUSD': 8000.0,
    });
    expect(sale.originalCurrency, Currency.USD);
    expect(sale.price, 8000.0);
    expect(sale.amountBTC, 0.1);
  });

  test('Purchase.fromMap coerces JSON ints to double', () {
    final restored = Purchase.fromMap({
      'id': 42,
      'date': '2021-05-10T00:00:00.000Z',
      'amountBTC': 1,
      'pricePerBTC': 40000,
      'cashCurrency': 0,
    });
    expect(restored.id, '42');
    expect(restored.amountBTC, 1.0);
    expect(restored.pricePerBTC, 40000.0);
    expect(restored.cashCurrency, Currency.USD);
  });

  test('Sale.round-trips new format', () {
    final original = Sale(
      id: 'new',
      date: DateTime.utc(2022, 3, 4),
      amountBTC: 0.2,
      price: 25000,
      originalCurrency: Currency.GBP,
    );
    final restored = Sale.fromMap(original.toMap());
    expect(restored.originalCurrency, Currency.GBP);
    expect(restored.price, 25000);
  });
}
