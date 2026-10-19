import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'hive_boxes.dart';
import 'models.dart';
import 'services.dart';

class _DatedPrice {
  final DateTime day;
  final double price;
  const _DatedPrice(this.day, this.price);
}

/// Daily BTC prices per fiat, used to convert a trade at the rate on its date
/// instead of today's FX. The portfolio chart also reads [priceNear] for the
/// low point in a range.
class HistoricalFx {
  static const _boxKey = 'historicalBtcDaily';

  final Map<String, Map<String, double>> _byDate = {};
  Map<String, List<_DatedPrice>>? _series;
  bool _loaded = false;
  int _revision = 0;

  int get revision => _revision;

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

  /// Bitcoin price in [currency] on [date], or the nearest saved day.
  /// Null when nothing has been saved yet.
  double? priceNear(DateTime date, Currency currency) {
    loadFromBox();
    final code = currencyToString(currency).toLowerCase();
    final series = _seriesFor(code);
    if (series.isEmpty) return null;
    final target = DateTime(date.year, date.month, date.day);
    var lo = 0;
    var hi = series.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (series[mid].day.isBefore(target)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo < series.length && _sameDay(series[lo].day, target)) {
      return series[lo].price;
    }
    final later = lo < series.length ? series[lo] : null;
    final earlier = lo > 0 ? series[lo - 1] : null;
    if (earlier == null) return later?.price;
    if (later == null) return earlier.price;
    final earlierGap = target.difference(earlier.day).inDays.abs();
    final laterGap = later.day.difference(target).inDays.abs();
    return earlierGap <= laterGap ? earlier.price : later.price;
  }

  List<_DatedPrice> _seriesFor(String code) {
    final cached = _series;
    if (cached != null && cached.containsKey(code)) return cached[code]!;
    final built = <String, List<_DatedPrice>>{};
    final days = _byDate.keys.toList()..sort();
    for (final key in days) {
      final parsed = DateTime.tryParse(key);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      final row = _byDate[key];
      if (row == null) continue;
      for (final entry in row.entries) {
        if (entry.value <= 0) continue;
        built.putIfAbsent(entry.key, () => []).add(_DatedPrice(day, entry.value));
      }
    }
    _series = built;
    return built[code] ?? const <_DatedPrice>[];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _storedPricesChanged() {
    _series = null;
    _revision++;
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
    _storedPricesChanged();
  }

  Future<void> persist() async {
    if (!Hive.isBoxOpen(HiveBoxes.preferences)) return;
    await Hive.box(HiveBoxes.preferences).put(_boxKey, _byDate);
  }

  /// [onUpdated] runs after each currency is saved so the chart can redraw
  /// before the other currencies finish.
  Future<void> refreshFromNetwork({void Function()? onUpdated}) async {
    loadFromBox();
    // Public CoinGecko rejects anything longer than 365 days.
    await _refreshEach(
      onUpdated: onUpdated,
      load: (currency) => ApiService.fetchHistoricalData(
        currencyToString(currency),
        365,
      ),
      fillGapsOnly: false,
    );
    // Older than that year: Coinbase's sparse history, without covering
    // the daily prices just saved.
    await _refreshEach(
      onUpdated: onUpdated,
      load: (currency) =>
          ApiService.fetchCoinbaseHistory(currencyToString(currency)),
      fillGapsOnly: true,
      skipWhenCoversBefore: DateTime.now().subtract(const Duration(days: 500)),
    );
  }

  Future<void> _refreshEach({
    required Future<List<PriceDataPoint>> Function(Currency currency) load,
    required bool fillGapsOnly,
    DateTime? skipWhenCoversBefore,
    void Function()? onUpdated,
  }) async {
    for (final currency in Currency.values) {
      final code = currencyToString(currency).toLowerCase();
      if (skipWhenCoversBefore != null &&
          _coversBefore(code, skipWhenCoversBefore)) {
        continue;
      }
      try {
        final points = await load(currency);
        if (_ingest(currency, points, fillGapsOnly: fillGapsOnly)) {
          await persist();
          onUpdated?.call();
        }
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } on RateLimitException {
        await Future<void>.delayed(const Duration(seconds: 8));
      } catch (_) {
        // Keep whatever is already cached.
      }
    }
  }

  bool _coversBefore(String code, DateTime day) {
    final series = _seriesFor(code);
    if (series.isEmpty) return false;
    return series.first.day.isBefore(day);
  }

  bool _ingest(
    Currency currency,
    List<PriceDataPoint> points, {
    bool fillGapsOnly = false,
  }) {
    final code = currencyToString(currency).toLowerCase();
    var changed = false;
    for (final point in points) {
      if (point.price <= 0) continue;
      final key = DateFormat('yyyy-MM-dd').format(point.date.toLocal());
      final row = _byDate.putIfAbsent(key, () => <String, double>{});
      if (fillGapsOnly && (row[code] ?? 0) > 0) continue;
      row[code] = point.price;
      changed = true;
    }
    if (changed) _storedPricesChanged();
    return changed;
  }
}
