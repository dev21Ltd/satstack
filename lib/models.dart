// models.dart - UPDATED
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Purchase {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime date;
  @HiveField(2) final double amountBTC;
  @HiveField(3) final double pricePerBTC;
  @HiveField(4) final Currency cashCurrency;

  Purchase({
    String? id,
    required this.date,
    required this.amountBTC,
    required this.pricePerBTC,
    required this.cashCurrency,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  double get totalCashSpent => amountBTC * pricePerBTC;

  factory Purchase.fromMap(Map<String, dynamic> map) {
    final amount = _asDouble(map['amountBTC']);
    final price = map['pricePerBTC'] != null
        ? _asDouble(map['pricePerBTC'])
        : (amount == 0 ? 0.0 : _asDouble(map['totalCashSpent']) / amount);
    return Purchase(
      id: map['id']?.toString(),
      date: DateTime.parse(map['date'].toString()),
      amountBTC: amount,
      pricePerBTC: price,
      cashCurrency: Currency.values[_asIndex(map['cashCurrency'], Currency.values.length)],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amountBTC': amountBTC,
      'pricePerBTC': pricePerBTC,
      'cashCurrency': cashCurrency.index,
    };
  }

  String formatUKDate() => DateFormat('dd/MM/yyyy').format(date);
}

class PriceDataPoint {
  final DateTime date;
  final double price;

  PriceDataPoint(this.date, this.price);
}

@HiveType(typeId: 1)
class Sale {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime date;
  @HiveField(2) final double amountBTC;
  @HiveField(3) final double price;
  @HiveField(4) final Currency originalCurrency;

  Sale({
    String? id,
    required this.date,
    required this.amountBTC,
    required this.price,
    required this.originalCurrency,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Helper method to get price in any currency
  double getPriceInCurrency(Currency currency, Map<Currency, double> btcPrices) {
    return convertViaBtc(price, originalCurrency, currency, btcPrices);
  }

  // Updated fromMap method with migration support
  factory Sale.fromMap(Map<String, dynamic> map) {
    // Handle migration from old format
    if (map['originalCurrency'] == null) {
      // This is an old sale record - migrate it
      return Sale(
        id: map['id']?.toString(),
        date: DateTime.parse(map['date'].toString()),
        amountBTC: _asDouble(map['amountBTC']),
        price: _asDouble(map['priceUSD']),
        originalCurrency: Currency.USD, // Default to USD for migration
      );
    }

    return Sale(
      id: map['id']?.toString(),
      date: DateTime.parse(map['date'].toString()),
      amountBTC: _asDouble(map['amountBTC']),
      price: _asDouble(map['price']),
      originalCurrency: Currency.values[_asIndex(map['originalCurrency'], Currency.values.length)],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amountBTC': amountBTC,
      'price': price,
      'originalCurrency': originalCurrency.index,
    };
  }

  String formatUKDate() => DateFormat('dd/MM/yyyy').format(date);
}

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asIndex(dynamic value, int length, [int fallback = 0]) {
  final index = value is num ? value.toInt() : fallback;
  if (index < 0 || index >= length) return fallback;
  return index;
}