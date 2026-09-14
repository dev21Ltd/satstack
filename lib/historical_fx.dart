import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'hive_boxes.dart';
import 'models.dart';
import 'services.dart';

/// Daily BTC prices per fiat, used to convert a trade at the rate on its date
/// instead of today's FX.
class HistoricalFx {
  static const _boxKey = 'historicalBtcDaily';

  final Map<String, Map<String, double>> _byDate = {};
  bool _loaded = false;

  Map<Currency, double> pricesOn(
    DateTime date,
    Map<Currency, double> fallback,
  ) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final row = _byDate[key];
    if (row == null || row.isEmpty) return fallback;
    final mapped = <Currency, double>{};
    for (final currency in Currency.values) {
      final stored = row[currencyToString(currency).toLowerCase()];
      mapped[currency] = stored ?? fallback[currency] ?? 0;
    }
    return mapped;
  }

  void loadFromBox() {
    if (_loaded || !Hive.isBoxOpen(HiveBoxes.preferences)) return;
    final raw = Hive.box(HiveBoxes.preferences).get(_boxKey);
    if (raw is Map) {
      raw.forEach((date, currencies) {
        if (currencies is! Map) return;
        final row = <String, double>{};
        currencies.forEach((code, value) {
          if (value is num) row[code.toString()] = value.toDouble();
        });
        if (row.isNotEmpty) _byDate[date.toString()] = row;
      });
    }
    _loaded = true;
  }

  Future<void> persist() async {
    if (!Hive.isBoxOpen(HiveBoxes.preferences)) return;
    await Hive.box(HiveBoxes.preferences).put(_boxKey, _byDate);
  }

  Future<void> refreshFromNetwork() async {
    loadFromBox();
    for (final currency in Currency.values) {
      try {
        final points = await ApiService.fetchHistoricalData(
          currencyToString(currency),
          3650,
        );
        _ingest(currency, points);
        await persist();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } on RateLimitException {
        await Future<void>.delayed(const Duration(seconds: 8));
      } catch (_) {
        // Keep whatever is already cached.
      }
    }
  }

  void _ingest(Currency currency, List<PriceDataPoint> points) {
    final code = currencyToString(currency).toLowerCase();
    for (final point in points) {
      final key = DateFormat('yyyy-MM-dd').format(point.date.toLocal());
      final row = _byDate.putIfAbsent(key, () => <String, double>{});
      row[code] = point.price;
    }
  }
}
