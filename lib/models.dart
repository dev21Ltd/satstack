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
    return Purchase(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amountBTC: map['amountBTC'],
      pricePerBTC: map['pricePerBTC'] ?? map['totalCashSpent'] / map['amountBTC'],
      cashCurrency: Currency.values[map['cashCurrency']],
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
    if (originalCurrency == currency) return price;

    final btcPriceOriginal = btcPrices[originalCurrency] ?? 0.0;
    final btcPriceTarget = btcPrices[currency] ?? 0.0;

    if (btcPriceOriginal == 0 || btcPriceTarget == 0) return price;

    // Convert via BTC: price (original) -> BTC -> price (target)
    double btcAmount = price / btcPriceOriginal;
    return btcAmount * btcPriceTarget;
  }

  // Updated fromMap method with migration support
  factory Sale.fromMap(Map<String, dynamic> map) {
    // Handle migration from old format
    if (map['originalCurrency'] == null) {
      // This is an old sale record - migrate it
      return Sale(
        id: map['id'],
        date: DateTime.parse(map['date']),
        amountBTC: map['amountBTC'],
        price: map['priceUSD'] ?? 0.0,
        originalCurrency: Currency.USD, // Default to USD for migration
      );
    }

    return Sale(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amountBTC: map['amountBTC'],
      price: map['price'],
      originalCurrency: Currency.values[map['originalCurrency']],
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