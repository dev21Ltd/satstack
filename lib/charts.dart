// charts.dart - OPTIMIZED TOOLTIP VERSION WITH ACCURATE PORTFOLIO VALUE USING ACTUAL TRANSACTION PRICES
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'constants.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';

enum PortfolioTimeRange {
  MONTH_1,
  MONTH_6,
  YEAR_1,
  YEAR_2,
  YEAR_3,
  YEAR_4,
  YEAR_5,
  YEAR_10,
  MAX,
}

/// Chart X/Y axis style.
/// `true`  = calendar ticks, clusters, activity strip.
/// `false` = original axes: rotated trade dates and a purchase/sale dot on each trade day.
const bool kUseNiceChartAxes = false;

class PortfolioChart extends StatefulWidget {
  final List<Purchase> purchases;
  final List<Sale> sales;
  final bool isDarkMode;
  final double currentBtcPrice;
  final Currency currency;
  final double portfolioValue;
  final double totalInvestment;
  final double profitLoss;
  final double profitLossPercentage;
  final Function(Purchase) onEditPurchase;
  final Function(Purchase) onDeletePurchase;
  final Function(Sale) onEditSale;
  final Function(Sale) onDeleteSale;
  final Denomination denomination;
  final Map<Currency, double> btcPrices;
  final bool holdingsHidden;
  final Map<Currency, double> Function(DateTime date)? pricesOnDate;
  final bool expanded;

  const PortfolioChart({
    Key? key,
    required this.purchases,
    required this.sales,
    required this.isDarkMode,
    required this.currentBtcPrice,
    required this.currency,
    required this.portfolioValue,
    required this.totalInvestment,
    required this.profitLoss,
    required this.profitLossPercentage,
    required this.onEditPurchase,
    required this.onDeletePurchase,
    required this.onEditSale,
    required this.onDeleteSale,
    required this.denomination,
    required this.btcPrices,
    required this.holdingsHidden,
    this.pricesOnDate,
    this.expanded = false,
  }) : super(key: key);

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends State<PortfolioChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<PortfolioDataPoint> _portfolioData = [];
  double _minValue = 0, _maxValue = 0;
  bool _isInitialized = false;
  PortfolioTimeRange _selectedTimeRange = PortfolioTimeRange.MONTH_1;
  double _averagePurchasePrice = 0, _totalBTC = 0;
  int? _hoveredIndex;
  List<int> _xTicks = [];
  double _yInterval = 1000;
  List<_TradeCluster> _clusters = [];
  final Map<int, _TradeCluster> _clusterByIndex = {};
  List<int> _stripBuys = [];
  List<int> _stripSells = [];
  double? _viewMinX;
  double? _viewMaxX;
  double _scaleStartMinX = 0;
  double _scaleStartMaxX = 1;
  double _chartWidth = 1;

  final Color _portfolioColor = Color(0xFF34C759);
  final Color _investmentColor = Color(0xFF8E8E93);
  final Color _purchaseDotColor = Color(0xFFF7931A);
  final Color _saleDotColor = Colors.purple;
  final Color _profitColor = Color(0xFF34C759);
  final Color _lossColor = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: 1000.ms);
    _animation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic);
    _calculatePortfolioData(notify: false);
    _animationController.forward();
    _isInitialized = true;
  }

  @override
  void didUpdateWidget(PortfolioChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchases.length != widget.purchases.length ||
        oldWidget.sales.length != widget.sales.length ||
        oldWidget.currency != widget.currency ||
        oldWidget.currentBtcPrice != widget.currentBtcPrice ||
        oldWidget.portfolioValue != widget.portfolioValue ||
        oldWidget.totalInvestment != widget.totalInvestment ||
        oldWidget.profitLoss != widget.profitLoss ||
        oldWidget.holdingsHidden != widget.holdingsHidden) {
      _calculatePortfolioData(notify: false);
      if (_isInitialized) {
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  void _setTimeRange(PortfolioTimeRange timeRange) {
    setState(() {
      _selectedTimeRange = timeRange;
      _viewMinX = null;
      _viewMaxX = null;
      _calculatePortfolioData(notify: false);
    });
  }

  double get _dataMaxX => math.max(1.0, (_portfolioData.length - 1).toDouble());

  double get _minX => (_viewMinX ?? 0).clamp(0, _dataMaxX);

  double get _maxX {
    final max = _viewMaxX ?? _dataMaxX;
    return max <= _minX ? _minX + 1 : max.clamp(_minX + 1, _dataMaxX);
  }

  bool get _isZoomed => _viewMinX != null || _viewMaxX != null;

  void _resetZoom() {
    setState(() {
      _viewMinX = null;
      _viewMaxX = null;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartMinX = _minX;
    _scaleStartMaxX = _maxX;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.expanded || details.pointerCount < 2) return;
    final startRange = _scaleStartMaxX - _scaleStartMinX;
    if (startRange <= 0 || _chartWidth < 16) return;
    final newRange = (startRange / details.scale).clamp(2.0, _dataMaxX);
    final focalFrac = (details.localFocalPoint.dx / _chartWidth).clamp(0.0, 1.0);
    final focalX = _scaleStartMinX + focalFrac * startRange;
    var newMin = focalX - newRange * focalFrac;
    var newMax = focalX + newRange * (1 - focalFrac);
    final pan = details.focalPointDelta.dx * (startRange / _chartWidth);
    newMin -= pan;
    newMax -= pan;
    if (newMin < 0) {
      newMax -= newMin;
      newMin = 0;
    }
    if (newMax > _dataMaxX) {
      newMin -= (newMax - _dataMaxX);
      newMax = _dataMaxX;
      if (newMin < 0) newMin = 0;
    }
    setState(() {
      _viewMinX = newMin;
      _viewMaxX = newMax;
    });
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PortfolioChart(
          purchases: widget.purchases,
          sales: widget.sales,
          isDarkMode: widget.isDarkMode,
          currentBtcPrice: widget.currentBtcPrice,
          currency: widget.currency,
          portfolioValue: widget.portfolioValue,
          totalInvestment: widget.totalInvestment,
          profitLoss: widget.profitLoss,
          profitLossPercentage: widget.profitLossPercentage,
          onEditPurchase: widget.onEditPurchase,
          onDeletePurchase: widget.onDeletePurchase,
          onEditSale: widget.onEditSale,
          onDeleteSale: widget.onDeleteSale,
          denomination: widget.denomination,
          btcPrices: widget.btcPrices,
          holdingsHidden: widget.holdingsHidden,
          pricesOnDate: widget.pricesOnDate,
          expanded: true,
        ),
      ),
    );
  }

  void _calculatePortfolioData({bool notify = true}) {
    try {
      _calculatePortfolioDataUnsafe();
    } catch (e, st) {
      print('Chart data error: $e\n$st');
      _portfolioData = [
        PortfolioDataPoint(
          date: DateTime.now(),
          portfolioValue: widget.portfolioValue.isFinite ? widget.portfolioValue : 0,
          investmentValue: widget.totalInvestment.isFinite ? widget.totalInvestment : 0,
          btcAmount: _totalBTC.isFinite ? _totalBTC : 0,
        ),
      ];
      _minValue = 0;
      _maxValue = 1000;
      _yInterval = 250;
      _xTicks = const [0];
      _clusters = [];
      _clusterByIndex.clear();
      _stripBuys = [];
      _stripSells = [];
    }
    if (notify && mounted) setState(() {});
  }

  void _calculatePortfolioDataUnsafe() {
    if (widget.purchases.isEmpty) {
      _portfolioData = [];
      return;
    }

    final sortedPurchases = List<Purchase>.from(widget.purchases)
      ..sort((a, b) => a.date.compareTo(b.date));
    final purchasedBtc = sortedPurchases.fold(
        0.0, (sum, purchase) => sum + purchase.amountBTC);
    _totalBTC = purchasedBtc -
        widget.sales.fold(0.0, (sum, sale) => sum + sale.amountBTC);

    double totalInvestment = sortedPurchases.fold(
        0.0,
            (sum, purchase) =>
        sum +
            _convertCurrency(purchase.totalCashSpent, purchase.cashCurrency,
                widget.currency, purchase.date));
    _averagePurchasePrice =
        purchasedBtc > 0 ? totalInvestment / purchasedBtc : 0;

    _portfolioData = [];
    final now = DateTime.now();
    DateTime startDate =
    _calculateStartDate(sortedPurchases.first.date, now);

    double runningBTC = 0, runningInvestment = 0;
    int purchaseIndex = 0;
    int saleIndex = 0;
    final sortedSales = List<Sale>.from(widget.sales)
      ..sort((a, b) => a.date.compareTo(b.date));

    while (purchaseIndex < sortedPurchases.length &&
        sortedPurchases[purchaseIndex].date.isBefore(startDate)) {
      final purchase = sortedPurchases[purchaseIndex];
      runningBTC += purchase.amountBTC;
      runningInvestment += _convertCurrency(
          purchase.totalCashSpent,
          purchase.cashCurrency,
          widget.currency,
          purchase.date);
      purchaseIndex++;
    }

    while (saleIndex < sortedSales.length &&
        sortedSales[saleIndex].date.isBefore(startDate)) {
      final sale = sortedSales[saleIndex];
      runningBTC -= sale.amountBTC;
      saleIndex++;
    }

    List<DateTime> allDates = _collectRelevantDates(
        startDate,
        now,
        sortedPurchases,
        purchaseIndex,
        sortedSales,
        saleIndex);
    _processDates(allDates, now, sortedPurchases, sortedSales, runningBTC,
        runningInvestment, purchaseIndex, saleIndex);

    if (_portfolioData.isEmpty) {
      _portfolioData.add(PortfolioDataPoint(
          date: now,
          portfolioValue: widget.portfolioValue,
          investmentValue: widget.totalInvestment,
          btcAmount: _totalBTC));
    }

    // ----- FIX: deduplicate by calendar date (ignore time) -----
    final Map<DateTime, PortfolioDataPoint> uniqueByDate = {};
    for (final point in _portfolioData) {
      final key = DateTime(point.date.year, point.date.month, point.date.day);
      // Keep the point with the later time (or last in list)
      if (!uniqueByDate.containsKey(key) ||
          point.date.isAfter(uniqueByDate[key]!.date)) {
        uniqueByDate[key] = point;
      }
    }
    _portfolioData = uniqueByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // ----------------------------------------------------------

    _calculateMinMaxValues();
  }

  DateTime _calculateStartDate(DateTime firstPurchaseDate, DateTime now) {
    DateTime startDate;
    final years = _yearsBack(_selectedTimeRange);
    if (_selectedTimeRange == PortfolioTimeRange.MONTH_1) {
      startDate = _getStartDate(
          firstPurchaseDate, DateTime(now.year, now.month - 1, now.day));
    } else if (_selectedTimeRange == PortfolioTimeRange.MONTH_6) {
      startDate = _getStartDate(
          firstPurchaseDate, DateTime(now.year, now.month - 6, now.day));
    } else if (years != null) {
      startDate = _getStartDate(
          firstPurchaseDate, DateTime(now.year - years, now.month, now.day));
    } else {
      startDate = firstPurchaseDate;
      if (startDate.isBefore(DateTime(2009, 1, 3))) {
        startDate = DateTime(2009, 1, 3);
      }
    }
    return startDate.isAfter(now) ? now : startDate;
  }

  DateTime _getStartDate(DateTime firstPurchaseDate, DateTime rangeDate) =>
      firstPurchaseDate.isAfter(rangeDate) ? firstPurchaseDate : rangeDate;

  List<DateTime> _collectRelevantDates(
      DateTime startDate,
      DateTime now,
      List<Purchase> sortedPurchases,
      int purchaseIndex,
      List<Sale> sortedSales,
      int saleIndex) {
    List<DateTime> allDates = [startDate];

    for (int i = purchaseIndex; i < sortedPurchases.length; i++) {
      final purchase = sortedPurchases[i];
      if ((purchase.date.isAfter(startDate) ||
          purchase.date.isAtSameMomentAs(startDate)) &&
          (purchase.date.isBefore(now) ||
              purchase.date.isAtSameMomentAs(now))) {
        allDates.add(purchase.date);
      }
    }

    for (int i = saleIndex; i < sortedSales.length; i++) {
      final sale = sortedSales[i];
      if ((sale.date.isAfter(startDate) ||
          sale.date.isAtSameMomentAs(startDate)) &&
          (sale.date.isBefore(now) || sale.date.isAtSameMomentAs(now))) {
        allDates.add(sale.date);
      }
    }

    if (!allDates.any((date) =>
    date.year == now.year &&
        date.month == now.month &&
        date.day == now.day)) {
      allDates.add(now);
    }

    allDates = allDates.toSet().toList()..sort();
    return allDates;
  }

  void _processDates(
      List<DateTime> allDates,
      DateTime now,
      List<Purchase> sortedPurchases,
      List<Sale> sortedSales,
      double runningBTC,
      double runningInvestment,
      int startPurchaseIndex,
      int startSaleIndex) {
    int currentPurchaseIndex = startPurchaseIndex;
    int currentSaleIndex = startSaleIndex;

    // Track the most recent known price from transactions
    double lastKnownPrice = 0;
    DateTime? lastTransactionDate;

    // Pre-calculate all transaction prices for quick lookup
    Map<DateTime, double> transactionPrices = {};

    // Add purchase prices
    for (final purchase in sortedPurchases) {
      transactionPrices[purchase.date] = _convertCurrency(
          purchase.pricePerBTC,
          purchase.cashCurrency,
          widget.currency);
    }

    // Add sale prices
    for (final sale in sortedSales) {
      transactionPrices[sale.date] = _convertCurrency(
          sale.price,
          sale.originalCurrency,
          widget.currency);
    }

    for (final date in allDates) {
      // Check if there's a transaction on this exact date
      bool hasTransactionToday = false;

      while (currentPurchaseIndex < sortedPurchases.length &&
          sortedPurchases[currentPurchaseIndex]
              .date
              .isBefore(date.add(Duration(days: 1)))) {
        final purchase = sortedPurchases[currentPurchaseIndex];
        runningBTC += purchase.amountBTC;
        runningInvestment += _convertCurrency(purchase.totalCashSpent,
            purchase.cashCurrency, widget.currency);

        // Update last known price from this transaction
        lastKnownPrice = _convertCurrency(purchase.pricePerBTC,
            purchase.cashCurrency, widget.currency);
        lastTransactionDate = purchase.date;
        hasTransactionToday = true;

        currentPurchaseIndex++;
      }

      while (currentSaleIndex < sortedSales.length &&
          sortedSales[currentSaleIndex]
              .date
              .isBefore(date.add(Duration(days: 1)))) {
        final sale = sortedSales[currentSaleIndex];
        runningBTC -= sale.amountBTC;

        // Update last known price from this transaction
        lastKnownPrice = _convertCurrency(sale.price,
            sale.originalCurrency, widget.currency);
        lastTransactionDate = sale.date;
        hasTransactionToday = true;

        currentSaleIndex++;
      }

      double portfolioValue;

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        // For current date, use actual portfolio value
        portfolioValue = widget.portfolioValue;
      } else if (hasTransactionToday && runningBTC > 0) {
        // For dates with transactions, use the transaction price
        portfolioValue = runningBTC * lastKnownPrice;
      } else if (lastKnownPrice > 0 && runningBTC > 0) {
        // For dates without transactions, use the most recent transaction price
        portfolioValue = runningBTC * lastKnownPrice;
      } else if (runningBTC > 0) {
        // No transaction price yet, calculate weighted average from purchases
        double totalWeightedPrice = 0;
        double totalBTCForAvg = 0;

        for (int i = 0; i < currentPurchaseIndex && i < sortedPurchases.length; i++) {
          final purchase = sortedPurchases[i];
          if (purchase.date.isBefore(date.add(Duration(days: 1)))) {
            final convertedPrice = _convertCurrency(
                purchase.pricePerBTC,
                purchase.cashCurrency,
                widget.currency);
            totalWeightedPrice += convertedPrice * purchase.amountBTC;
            totalBTCForAvg += purchase.amountBTC;
          }
        }

        // Subtract BTC from sales for average calculation
        for (int i = 0; i < currentSaleIndex && i < sortedSales.length; i++) {
          final sale = sortedSales[i];
          if (sale.date.isBefore(date.add(Duration(days: 1)))) {
            // For sales, we need to remove BTC from the weighted average
            // Using FIFO approach: remove oldest purchases first
            double btcToRemove = sale.amountBTC;
            int j = 0;

            while (btcToRemove > 0 && j < sortedPurchases.length) {
              final purchase = sortedPurchases[j];
              if (purchase.date.isBefore(date.add(Duration(days: 1)))) {
                double btcFromPurchase = purchase.amountBTC;
                if (btcFromPurchase <= btcToRemove) {
                  totalWeightedPrice -= _convertCurrency(purchase.pricePerBTC,
                      purchase.cashCurrency, widget.currency) * btcFromPurchase;
                  totalBTCForAvg -= btcFromPurchase;
                  btcToRemove -= btcFromPurchase;
                } else {
                  totalWeightedPrice -= _convertCurrency(purchase.pricePerBTC,
                      purchase.cashCurrency, widget.currency) * btcToRemove;
                  totalBTCForAvg -= btcToRemove;
                  btcToRemove = 0;
                }
              }
              j++;
            }
          }
        }

        final avgPrice = totalBTCForAvg > 0 ? totalWeightedPrice / totalBTCForAvg : 0;
        portfolioValue = runningBTC * avgPrice;
      } else {
        // No BTC yet
        portfolioValue = 0;
      }

      _portfolioData.add(PortfolioDataPoint(
          date: date,
          portfolioValue: portfolioValue,
          investmentValue: runningInvestment,
          btcAmount: runningBTC));
    }
  }

  void _calculateMinMaxValues() {
    if (_portfolioData.isEmpty) return;

    _minValue = _portfolioData.fold<double>(
        double.infinity,
            (prev, e) =>
            math.min(prev, math.min(e.portfolioValue, e.investmentValue)));
    _maxValue = _portfolioData.fold<double>(
        0,
            (prev, e) =>
            math.max(prev, math.max(e.portfolioValue, e.investmentValue)));
    if (!_minValue.isFinite) _minValue = 0;
    if (!_maxValue.isFinite) _maxValue = 0;

    if (kUseNiceChartAxes) {
      try {
        _applyNiceYRange();
        _xTicks = _dropDuplicateLabels(_timelineTickIndices());
        _rebuildTradeOverlays();
      } catch (e) {
        print('Chart axis error: $e');
        _yInterval = 1000;
        _minValue = 0;
        _maxValue = 1000;
        _xTicks = _portfolioData.length <= 1
            ? const [0]
            : [0, _portfolioData.length - 1];
        _clusters = [];
        _clusterByIndex.clear();
      }
      return;
    }

    // Floor the axis at the real line start (can be negative). Pad only the top
    // so the first $ label sits on the line instead of below it.
    final dataMin = _minValue;
    final dataMax = _maxValue;
    final valueRange = dataMax - dataMin;
    _minValue = dataMin;
    if (valueRange > 0) {
      _maxValue = dataMax + valueRange * 0.08;
    } else {
      final pad = math.max(dataMax.abs() * 0.1, 1.0);
      _minValue = dataMin - pad;
      _maxValue = dataMax + pad;
    }
    _yInterval = _getPriceInterval(_minValue, _maxValue);
    _xTicks = [];
  }

  void _applyNiceYRange() {
    var dataMin = _minValue.isFinite ? _minValue : 0.0;
    var dataMax = _maxValue.isFinite ? _maxValue : 0.0;
    if (dataMax <= dataMin) dataMax = dataMin + 1;
    final neverNegative = dataMin >= 0;
    var span = dataMax - (neverNegative && dataMin <= dataMax * 0.15 ? 0 : dataMin);
    if (!span.isFinite || span <= 0) span = 1;
    _yInterval = _getPriceInterval(0, span);
    if (!_yInterval.isFinite || _yInterval <= 0) _yInterval = 1000;

    if (neverNegative && dataMin <= dataMax * 0.15) {
      _minValue = 0;
    } else {
      _minValue = (dataMin / _yInterval).floor() * _yInterval;
      if (neverNegative && _minValue < 0) _minValue = 0;
    }
    _maxValue = (dataMax / _yInterval).ceil() * _yInterval;
    if (!_minValue.isFinite) _minValue = 0;
    if (!_maxValue.isFinite) _maxValue = _minValue + _yInterval * 4;
    if (_maxValue <= _minValue) _maxValue = _minValue + _yInterval * 4;
    while (_yInterval > 0 && (_maxValue - _minValue) / _yInterval < 3) {
      _maxValue += _yInterval;
    }
  }

  /// Calendar labels only (not one label per trade). First/last always kept.
  List<int> _timelineTickIndices() {
    final n = _portfolioData.length;
    if (n == 0) return [];
    if (n == 1) return const [0];

    final periodStarts = <int>[0];
    String? lastBucket;
    for (var i = 0; i < n; i++) {
      final bucket = _timelineBucket(_portfolioData[i].date);
      if (bucket != lastBucket) {
        if (i != 0) periodStarts.add(i);
        lastBucket = bucket;
      }
    }
    if (periodStarts.last != n - 1) periodStarts.add(n - 1);

    final maxTicks = _maxTimelineTicks();
    if (periodStarts.length <= maxTicks) return periodStarts;
    return _evenSampleKeepingEnds(periodStarts, maxTicks);
  }

  int _maxTimelineTicks() {
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
      case PortfolioTimeRange.MONTH_6:
        return 6;
      case PortfolioTimeRange.YEAR_1:
      case PortfolioTimeRange.YEAR_2:
        return 8;
      case PortfolioTimeRange.YEAR_3:
      case PortfolioTimeRange.YEAR_4:
      case PortfolioTimeRange.YEAR_5:
      case PortfolioTimeRange.YEAR_10:
      case PortfolioTimeRange.MAX:
        return 12;
    }
  }

  String _timelineBucket(DateTime date) {
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
        return '${monday.year}-${monday.month}-${monday.day}';
      case PortfolioTimeRange.MONTH_6:
      case PortfolioTimeRange.YEAR_1:
      case PortfolioTimeRange.YEAR_2:
        return '${date.year}-${date.month}';
      case PortfolioTimeRange.YEAR_3:
      case PortfolioTimeRange.YEAR_4:
      case PortfolioTimeRange.YEAR_5:
      case PortfolioTimeRange.YEAR_10:
      case PortfolioTimeRange.MAX:
        return '${date.year}';
    }
  }

  List<int> _evenSampleKeepingEnds(List<int> items, int count) {
    if (items.length <= count) return items;
    final inner = count - 2;
    if (inner <= 0) return [items.first, items.last];
    final sampled = <int>[items.first];
    for (var i = 1; i <= inner; i++) {
      final index = (i * (items.length - 1) / (count - 1)).round();
      sampled.add(items[index.clamp(1, items.length - 2)]);
    }
    sampled.add(items.last);
    return sampled.toSet().toList()..sort();
  }

  DateTime get _rangeStart =>
      _portfolioData.isEmpty ? DateTime.now() : _portfolioData.first.date;
  DateTime get _rangeEnd =>
      _portfolioData.isEmpty ? DateTime.now() : _portfolioData.last.date;

  bool _inChartRange(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(_rangeStart.year, _rangeStart.month, _rangeStart.day);
    final end = DateTime(_rangeEnd.year, _rangeEnd.month, _rangeEnd.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  int _indexForDate(DateTime date) {
    if (_portfolioData.isEmpty) return 0;
    final target = DateTime(date.year, date.month, date.day);
    var best = 0;
    var bestDist = 1 << 30;
    for (var i = 0; i < _portfolioData.length; i++) {
      final d = _portfolioData[i].date;
      final dist = DateTime(d.year, d.month, d.day).difference(target).inDays.abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
      if (dist == 0) return i;
    }
    return best;
  }

  int _uniqueTradeDaysInView() {
    final days = <String>{};
    for (final p in widget.purchases) {
      if (_inChartRange(p.date)) {
        days.add('${p.date.year}-${p.date.month}-${p.date.day}');
      }
    }
    for (final s in widget.sales) {
      if (_inChartRange(s.date)) {
        days.add('${s.date.year}-${s.date.month}-${s.date.day}');
      }
    }
    return days.length;
  }

  bool get _shouldClusterTrades => _uniqueTradeDaysInView() > 12;

  String _clusterKey(DateTime date) {
    if (!_shouldClusterTrades) {
      return '${date.year}-${date.month}-${date.day}';
    }
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
        return 'w-${monday.year}-${monday.month}-${monday.day}';
      case PortfolioTimeRange.MONTH_6:
      case PortfolioTimeRange.YEAR_1:
      case PortfolioTimeRange.YEAR_2:
        return 'm-${date.year}-${date.month}';
      case PortfolioTimeRange.YEAR_3:
      case PortfolioTimeRange.YEAR_4:
      case PortfolioTimeRange.YEAR_5:
      case PortfolioTimeRange.YEAR_10:
      case PortfolioTimeRange.MAX:
        return _uniqueTradeDaysInView() > 40
            ? 'q-${date.year}-${((date.month - 1) ~/ 3) + 1}'
            : 'm-${date.year}-${date.month}';
    }
  }

  String _clusterTitle(DateTime date) {
    if (!_shouldClusterTrades) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
        return 'Week of ${DateFormat('d MMM yyyy').format(monday)}';
      case PortfolioTimeRange.MONTH_6:
      case PortfolioTimeRange.YEAR_1:
      case PortfolioTimeRange.YEAR_2:
        return DateFormat('MMMM yyyy').format(date);
      case PortfolioTimeRange.YEAR_3:
      case PortfolioTimeRange.YEAR_4:
      case PortfolioTimeRange.YEAR_5:
      case PortfolioTimeRange.YEAR_10:
      case PortfolioTimeRange.MAX:
        return _uniqueTradeDaysInView() > 40
            ? 'Q${((date.month - 1) ~/ 3) + 1} ${date.year}'
            : DateFormat('MMMM yyyy').format(date);
    }
  }

  void _rebuildTradeOverlays() {
    _clusters = [];
    _clusterByIndex.clear();
    if (_portfolioData.isEmpty) {
      _stripBuys = [];
      _stripSells = [];
      return;
    }

    final byKey = <String, _TradeCluster>{};
    void addPurchase(Purchase purchase) {
      if (!_inChartRange(purchase.date)) return;
      final key = _clusterKey(purchase.date);
      final cluster = byKey.putIfAbsent(
        key,
        () => _TradeCluster(
          index: _indexForDate(purchase.date),
          title: _clusterTitle(purchase.date),
        ),
      );
      cluster.purchases.add(purchase);
    }

    void addSale(Sale sale) {
      if (!_inChartRange(sale.date)) return;
      final key = _clusterKey(sale.date);
      final cluster = byKey.putIfAbsent(
        key,
        () => _TradeCluster(
          index: _indexForDate(sale.date),
          title: _clusterTitle(sale.date),
        ),
      );
      cluster.sales.add(sale);
    }

    for (final purchase in widget.purchases) {
      addPurchase(purchase);
    }
    for (final sale in widget.sales) {
      addSale(sale);
    }

    final merged = <int, _TradeCluster>{};
    for (final cluster in byKey.values) {
      final existing = merged[cluster.index];
      if (existing == null) {
        merged[cluster.index] = cluster;
      } else {
        existing.purchases.addAll(cluster.purchases);
        existing.sales.addAll(cluster.sales);
      }
    }
    _clusters = merged.values.toList();
    _clusterByIndex
      ..clear()
      ..addAll(merged);

    const slots = 48;
    final n = _portfolioData.length;
    final slotCount = n <= 1 ? 1 : math.min(slots, n);
    _stripBuys = List<int>.filled(slotCount, 0);
    _stripSells = List<int>.filled(slotCount, 0);
    int slotFor(DateTime date) {
      if (n <= 1) return 0;
      final i = _indexForDate(date);
      return ((i / (n - 1)) * (slotCount - 1)).round().clamp(0, slotCount - 1);
    }

    for (final purchase in widget.purchases) {
      if (_inChartRange(purchase.date)) _stripBuys[slotFor(purchase.date)]++;
    }
    for (final sale in widget.sales) {
      if (_inChartRange(sale.date)) _stripSells[slotFor(sale.date)]++;
    }
  }

  List<_TradeCluster> _clustersForSlot(int slot) {
    if (_stripBuys.isEmpty) return const [];
    final n = _portfolioData.length;
    final slotCount = _stripBuys.length;
    return _clusters.where((cluster) {
      final clusterSlot = n <= 1
          ? 0
          : ((cluster.index / (n - 1)) * (slotCount - 1)).round().clamp(0, slotCount - 1);
      return clusterSlot == slot;
    }).toList();
  }

  List<int> _dropDuplicateLabels(List<int> ticks) {
    if (ticks.length <= 1) return ticks;
    final result = <int>[ticks.first];
    for (var i = 1; i < ticks.length; i++) {
      final label = _formatChartDate(_portfolioData[ticks[i]].date);
      final prev = _formatChartDate(_portfolioData[result.last].date);
      if (label != prev) {
        result.add(ticks[i]);
      } else if (i == ticks.length - 1) {
        result[result.length - 1] = ticks[i];
      }
    }
    return result;
  }

  List<int> _evenSample(List<int> items, int count) {
    if (count <= 0 || items.isEmpty) return const [];
    if (items.length <= count) return items;
    if (count == 1) return [items[items.length ~/ 2]];
    final result = <int>[];
    for (var i = 0; i < count; i++) {
      final index = (i * (items.length - 1) / (count - 1)).round();
      result.add(items[index]);
    }
    return result.toSet().toList()..sort();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int? _yearsBack(PortfolioTimeRange range) {
    switch (range) {
      case PortfolioTimeRange.YEAR_1:
        return 1;
      case PortfolioTimeRange.YEAR_2:
        return 2;
      case PortfolioTimeRange.YEAR_3:
        return 3;
      case PortfolioTimeRange.YEAR_4:
        return 4;
      case PortfolioTimeRange.YEAR_5:
        return 5;
      case PortfolioTimeRange.YEAR_10:
        return 10;
      case PortfolioTimeRange.MONTH_1:
      case PortfolioTimeRange.MONTH_6:
      case PortfolioTimeRange.MAX:
        return null;
    }
  }

  bool get _useYearLabels {
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.YEAR_2:
      case PortfolioTimeRange.YEAR_3:
      case PortfolioTimeRange.YEAR_4:
      case PortfolioTimeRange.YEAR_5:
      case PortfolioTimeRange.YEAR_10:
      case PortfolioTimeRange.MAX:
        return true;
      default:
        return false;
    }
  }

  String _getTimeRangeLabel(PortfolioTimeRange timeRange) {
    switch (timeRange) {
      case PortfolioTimeRange.MONTH_1:
        return '1M';
      case PortfolioTimeRange.MONTH_6:
        return '6M';
      case PortfolioTimeRange.YEAR_1:
        return '1Y';
      case PortfolioTimeRange.YEAR_2:
        return '2Y';
      case PortfolioTimeRange.YEAR_3:
        return '3Y';
      case PortfolioTimeRange.YEAR_4:
        return '4Y';
      case PortfolioTimeRange.YEAR_5:
        return '5Y';
      case PortfolioTimeRange.YEAR_10:
        return '10Y';
      case PortfolioTimeRange.MAX:
        return 'Max';
    }
  }

  double _btcPriceOn(DateTime date) {
    final prices = widget.pricesOnDate?.call(date) ?? widget.btcPrices;
    final price = prices[widget.currency];
    if (price != null && price > 0) return price;
    return widget.currentBtcPrice;
  }

  bool get _windowCoversAllHistory {
    if (widget.purchases.isEmpty || _portfolioData.isEmpty) return true;
    final windowStart = DateTime(
      _portfolioData.first.date.year,
      _portfolioData.first.date.month,
      _portfolioData.first.date.day,
    );
    return widget.purchases.every((purchase) {
      final day = DateTime(
        purchase.date.year,
        purchase.date.month,
        purchase.date.day,
      );
      return !day.isBefore(windowStart);
    });
  }

  /// Return for the selected chip only (1M, 4Y, Max, …).
  /// If the chip is longer than your history (e.g. 4Y with 3 years of buys),
  /// this is the same as all-time ROI.
  double get _periodRoi {
    if (_portfolioData.isEmpty) return 0;
    if (_windowCoversAllHistory) return widget.profitLossPercentage;
    final start = _portfolioData.first;
    final end = _portfolioData.last;
    final startMarket = start.btcAmount * _btcPriceOn(start.date);
    final endMarket = widget.portfolioValue > 0
        ? widget.portfolioValue
        : end.portfolioValue;
    if (!startMarket.isFinite || !endMarket.isFinite) return 0;

    double cashIn = 0;
    for (final purchase in widget.purchases) {
      if (purchase.date.isAfter(start.date) && !purchase.date.isAfter(end.date)) {
        cashIn += _convertCurrency(
          purchase.totalCashSpent,
          purchase.cashCurrency,
          widget.currency,
          purchase.date,
        );
      }
    }
    double cashOut = 0;
    for (final sale in widget.sales) {
      if (sale.date.isAfter(start.date) && !sale.date.isAfter(end.date)) {
        cashOut += _convertCurrency(
          sale.amountBTC * sale.price,
          sale.originalCurrency,
          widget.currency,
          sale.date,
        );
      }
    }

    final capital = startMarket + cashIn;
    if (capital.abs() < 1e-6) return 0;
    return (endMarket - startMarket - cashIn + cashOut) / capital * 100;
  }

  double _convertCurrency(double amount, Currency from, Currency to, [DateTime? date]) {
    final prices = (date != null && widget.pricesOnDate != null)
        ? widget.pricesOnDate!(date)
        : widget.btcPrices;
    return convertViaBtc(amount, from, to, prices);
  }

  bool _isPurchaseDate(DateTime date) =>
      widget.purchases.any((purchase) =>
      purchase.date.year == date.year &&
          purchase.date.month == date.month &&
          purchase.date.day == date.day);

  bool _isSaleDate(DateTime date) => widget.sales.any((sale) =>
  sale.date.year == date.year &&
      sale.date.month == date.month &&
      sale.date.day == date.day);

  List<Purchase> _getPurchasesForDate(DateTime date) => widget.purchases
      .where((purchase) =>
  purchase.date.year == date.year &&
      purchase.date.month == date.month &&
      purchase.date.day == date.day)
      .toList();

  List<Sale> _getSalesForDate(DateTime date) => widget.sales
      .where((sale) =>
  sale.date.year == date.year &&
      sale.date.month == date.month &&
      sale.date.day == date.day)
      .toList();

  double _getTotalPurchaseAmount(List<Purchase> purchases) =>
      purchases.fold(0.0, (sum, purchase) => sum + purchase.amountBTC);

  double _getAveragePurchasePrice(List<Purchase> purchases) {
    if (purchases.isEmpty) return 0;
    double totalValue = 0, totalBTC = 0;
    for (var purchase in purchases) {
      totalValue += _convertCurrency(purchase.amountBTC * purchase.pricePerBTC,
          purchase.cashCurrency, widget.currency);
      totalBTC += purchase.amountBTC;
    }
    return totalBTC == 0 ? 0 : totalValue / totalBTC;
  }

  double _calculatePurchaseValue(List<Purchase> purchases) =>
      purchases.fold(
          0.0,
              (sum, purchase) =>
          sum +
              _convertCurrency(purchase.amountBTC * purchase.pricePerBTC,
                  purchase.cashCurrency, widget.currency));

  double _calculateCurrentValue(List<Purchase> purchases) => purchases.fold(
      0.0,
          (sum, purchase) => sum + (purchase.amountBTC * widget.currentBtcPrice));

  double _calculateProfitLoss(List<Purchase> purchases) =>
      purchases.isEmpty
          ? 0
          : _calculateCurrentValue(purchases) - _calculatePurchaseValue(purchases);

  double _calculateProfitLossPercentage(List<Purchase> purchases) {
    if (purchases.isEmpty) return 0;
    double purchaseValue = _calculatePurchaseValue(purchases);
    return purchaseValue == 0
        ? 0
        : (_calculateProfitLoss(purchases) / purchaseValue) * 100;
  }

  bool _isProfit(List<Purchase> purchases) =>
      _calculateProfitLoss(purchases) >= 0;

  void _showDateDetails(DateTime date, List<Purchase> purchases, List<Sale> sales) {
    _showTradesDialog(
      DateFormat('dd/MM/yyyy').format(date),
      purchases,
      sales,
    );
  }

  void _showClusterDetails(_TradeCluster cluster) {
    _showTradesDialog(cluster.title, cluster.purchases, cluster.sales);
  }

  void _showTradesDialog(String title, List<Purchase> purchases, List<Sale> sales) {
    if (widget.holdingsHidden) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Holdings are currently hidden'),
          backgroundColor: Colors.orange));
      return;
    }
    if (purchases.isEmpty && sales.isEmpty) return;

    double totalAmount = _getTotalPurchaseAmount(purchases);
    double averagePricePerBTC = _getAveragePurchasePrice(purchases);
    double purchaseValue = _calculatePurchaseValue(purchases);
    double currentValue = _calculateCurrentValue(purchases);
    double profitLoss = _calculateProfitLoss(purchases);
    double profitLossPercentage = _calculateProfitLossPercentage(purchases);
    bool isProfit = _isProfit(purchases);

    showDialog(
        context: context,
        builder: (BuildContext context) => _buildDateDetailsDialog(
            title,
            purchases,
            sales,
            totalAmount,
            averagePricePerBTC,
            purchaseValue,
            currentValue,
            profitLoss,
            profitLossPercentage,
            isProfit));
  }

  AlertDialog _buildDateDetailsDialog(
      String title,
      List<Purchase> purchases,
      List<Sale> sales,
      double totalAmount,
      double averagePricePerBTC,
      double purchaseValue,
      double currentValue,
      double profitLoss,
      double profitLossPercentage,
      bool isProfit) {
    return AlertDialog(
      title: Text(title,
          style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black)),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (purchases.isNotEmpty) ...[
                Text(
                    'Total Purchased: ${formatDenomination(totalAmount, widget.denomination)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                    'Purchase Value: ${purchaseValue.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                SizedBox(height: 4),
                Text(
                    'Current Value: ${currentValue.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                SizedBox(height: 4),
                Text(
                    'Avg Price: ${averagePricePerBTC.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                SizedBox(height: 4),
                Text(
                    'P&L: ${profitLoss.toStringAsFixed(2)} ${currencyToString(widget.currency)} (${profitLossPercentage.toStringAsFixed(2)}%)',
                    style: TextStyle(
                        color: isProfit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold)),
                if (purchases.isNotEmpty) ..._buildPurchaseList(purchases),
                SizedBox(height: 16),
              ],

              if (sales.isNotEmpty) ...[
                Text('Sales:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                        fontSize: 16)),
                SizedBox(height: 8),
                ...sales.map((sale) => _buildSaleItem(sale)).toList(),
              ],

              if (purchases.isEmpty && sales.isEmpty)
                Text('No transactions on this date',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
            ],
          )),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'))
      ],
    );
  }

  Widget _buildSaleItem(Sale sale) {
    double saleValue = sale.amountBTC * sale.price;
    double saleValueInSelectedCurrency = _convertCurrency(
        saleValue, sale.originalCurrency, widget.currency);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.purple[900]!.withOpacity(0.3)
            : Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_circle_down, color: Colors.purple, size: 16),
              SizedBox(width: 4),
              Text('Sale',
                  style: TextStyle(
                      color: Colors.purple, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 4),
          Text(
              '${formatDenomination(sale.amountBTC, widget.denomination)} @ ${sale.price.toStringAsFixed(2)} ${currencyToString(sale.originalCurrency)}',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontSize: 12)),
          SizedBox(height: 2),
          Text(
              'Value: ${saleValueInSelectedCurrency.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 11)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit,
                    color: widget.isDarkMode ? Colors.blue[300] : Colors.blue,
                    size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showEditSaleDialog(sale);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete,
                    color: widget.isDarkMode ? Colors.red[300] : Colors.red,
                    size: 20),
                onPressed: () {
                  widget.onDeleteSale(sale);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPurchaseList(List<Purchase> purchases) {
    return [
      SizedBox(height: 16),
      Text('Purchases:',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black)),
      SizedBox(height: 8),
      ...purchases.map((purchase) => _buildPurchaseItem(purchase)).toList()
    ];
  }

  Widget _buildPurchaseItem(Purchase purchase) {
    double currentValue = purchase.amountBTC * widget.currentBtcPrice;
    double purchaseValueInSelectedCurrency = _convertCurrency(
        purchase.totalCashSpent, purchase.cashCurrency, widget.currency);
    bool isIndividualProfit = currentValue >= purchaseValueInSelectedCurrency;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${formatDenomination(purchase.amountBTC, widget.denomination)} @ ${purchase.pricePerBTC.toStringAsFixed(2)} ${currencyToString(purchase.cashCurrency)}',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold)),
          if (purchase.cashCurrency != widget.currency) ...[
            SizedBox(height: 4),
            Text(
                'Converted: ${_convertCurrency(purchase.pricePerBTC, purchase.cashCurrency, widget.currency).toStringAsFixed(2)} ${currencyToString(widget.currency)}/BTC',
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.orange : Colors.blue)),
          ],
          SizedBox(height: 4),
          Text(
              'Purchase Value: ${purchaseValueInSelectedCurrency.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
          Text(
              'Current Value: ${currentValue.toStringAsFixed(2)} ${currencyToString(widget.currency)}',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
          Text(
              'P&L: ${(currentValue - purchaseValueInSelectedCurrency).toStringAsFixed(2)} ${currencyToString(widget.currency)}',
              style: TextStyle(
                  color: isIndividualProfit ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit,
                    color: widget.isDarkMode ? Colors.blue[300] : Colors.blue,
                    size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showEditPurchaseDialog(purchase);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete,
                    color: widget.isDarkMode ? Colors.red[300] : Colors.red,
                    size: 20),
                onPressed: () {
                  widget.onDeletePurchase(purchase);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditPurchaseDialog(Purchase purchase) {
    final TextEditingController amountController = TextEditingController(
        text: widget.denomination == Denomination.BTC
            ? purchase.amountBTC.toString()
            : btcToSatoshis(purchase.amountBTC).toString());
    final TextEditingController priceController =
    TextEditingController(text: purchase.pricePerBTC.toString());
    DateTime selectedDate = purchase.date;

    showDialog(
        context: context,
        builder: (BuildContext context) => _buildEditPurchaseDialog(
            purchase, amountController, priceController, selectedDate));
  }

  AlertDialog _buildEditPurchaseDialog(
      Purchase purchase,
      TextEditingController amountController,
      TextEditingController priceController,
      DateTime selectedDate) {
    return AlertDialog(
      title: Text('Edit Purchase',
          style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black)),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: widget.denomination == Denomination.BTC
                    ? TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                decoration: InputDecoration(
                    labelText: widget.denomination == Denomination.BTC
                        ? 'BTC Amount'
                        : 'Sats Amount',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                    'Price (${currencyToString(purchase.cashCurrency)}) - Original Currency',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2009, 1, 3),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Text('Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black)),
              ),
              if (purchase.cashCurrency != widget.currency) ...[
                SizedBox(height: 16),
                Text(
                    'Price in ${currencyToString(widget.currency)}: ${_convertCurrency(purchase.pricePerBTC, purchase.cashCurrency, widget.currency).toStringAsFixed(2)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.bold)),
              ],
            ],
          )),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => _savePurchaseEdit(
                purchase, amountController, priceController, selectedDate),
            child: const Text('Save')),
      ],
    );
  }

  void _showEditSaleDialog(Sale sale) {
    final TextEditingController amountController = TextEditingController(
        text: widget.denomination == Denomination.BTC
            ? sale.amountBTC.toString()
            : btcToSatoshis(sale.amountBTC).toString());
    final TextEditingController priceController =
    TextEditingController(text: sale.price.toString());
    DateTime selectedDate = sale.date;

    showDialog(
        context: context,
        builder: (context) => _buildEditSaleDialog(
            sale, amountController, priceController, selectedDate));
  }

  AlertDialog _buildEditSaleDialog(
      Sale sale,
      TextEditingController amountController,
      TextEditingController priceController,
      DateTime selectedDate) {
    return AlertDialog(
      title: Text('Edit Sale',
          style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black)),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: widget.denomination == Denomination.BTC
                    ? TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                decoration: InputDecoration(
                    labelText: widget.denomination == Denomination.BTC
                        ? 'BTC Amount'
                        : 'Sats Amount',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                    'Price (${currencyToString(sale.originalCurrency)}) - Original Currency',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
                style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2009, 1, 3),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Text('Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black)),
              ),
              SizedBox(height: 16),
              Text(
                  'Price in ${currencyToString(widget.currency)}: ${_convertCurrency(sale.price, sale.originalCurrency, widget.currency).toStringAsFixed(2)}',
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold)),
            ],
          )),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => _saveSaleEdit(
                sale, amountController, priceController, selectedDate),
            child: const Text('Save')),
      ],
    );
  }

  void _saveSaleEdit(Sale sale, TextEditingController amountController,
      TextEditingController priceController, DateTime selectedDate) {
    double newAmount = widget.denomination == Denomination.BTC
        ? double.tryParse(amountController.text) ?? 0
        : satoshisToBtc(int.tryParse(amountController.text) ?? 0);
    final newPrice = double.tryParse(priceController.text);

    if (newAmount <= 0 || newPrice == null || newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid values')));
      return;
    }

    final updatedSale = Sale(
      id: sale.id,
      date: selectedDate,
      amountBTC: newAmount,
      price: newPrice,
      originalCurrency: sale.originalCurrency,
    );
    widget.onEditSale(updatedSale);
    Navigator.of(context).pop();
  }

  void _savePurchaseEdit(
      Purchase purchase,
      TextEditingController amountController,
      TextEditingController priceController,
      DateTime selectedDate) {
    double newAmount = widget.denomination == Denomination.BTC
        ? double.tryParse(amountController.text) ?? 0
        : satoshisToBtc(int.tryParse(amountController.text) ?? 0);
    final newPricePerBTC = double.tryParse(priceController.text);

    if (newAmount <= 0 || newPricePerBTC == null || newPricePerBTC <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid values')));
      return;
    }

    final updatedPurchase = Purchase(
        id: purchase.id,
        date: selectedDate,
        amountBTC: newAmount,
        pricePerBTC: newPricePerBTC,
        cashCurrency: purchase.cashCurrency);
    widget.onEditPurchase(updatedPurchase);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.purchases.isEmpty) return _buildEmptyState();
    if (_portfolioData.isEmpty) return _buildLoadingState();

    final profitLossColor = widget.profitLoss >= 0 ? _profitColor : _lossColor;
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final compact = landscape || media.size.height < 560;
    if (!widget.expanded) {
      return _buildChartCard(profitLossColor, compact: compact);
    }
    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Chart'),
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[200],
        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
        toolbarHeight: compact ? 44 : 56,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chrome = compact ? 200.0 : 280.0;
            final chartHeight = math.max(160.0, constraints.maxHeight - chrome);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(8, compact ? 4 : 8, 8, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildChartCard(
                  profitLossColor,
                  compact: compact,
                  chartHeight: chartHeight,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartCard(
    Color profitLossColor, {
    required bool compact,
    double? chartHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: EdgeInsets.all(compact ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCleanHeader(profitLossColor),
          SizedBox(height: compact ? 8 : 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTimeRangeSelector()),
              if (!widget.expanded)
                IconButton(
                  tooltip: 'Full screen',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.fullscreen,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: _openFullScreen,
                ),
              if (widget.expanded && _isZoomed)
                IconButton(
                  tooltip: 'Reset zoom',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.zoom_out_map,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: _resetZoom,
                ),
            ],
          ),
          if (widget.expanded && !compact)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Pinch to zoom · tap a dot for trades',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
            )
          else
            SizedBox(height: compact ? 8 : 12),
          _buildChartPlot(height: chartHeight),
          if (kUseNiceChartAxes && !widget.holdingsHidden) ...[
            const SizedBox(height: 8),
            _buildActivityStrip(),
          ],
          SizedBox(height: compact ? 8 : 16),
          _buildLegendAndMetrics(profitLossColor),
        ],
      ),
    );
  }

  Widget _buildCleanHeader(Color profitLossColor) {
    final bitcoinPriceFormat =
    NumberFormat.currency(symbol: _getCurrencySymbol(widget.currency), decimalDigits: 0);
    final stackValueFormat =
    NumberFormat.currency(symbol: _getCurrencySymbol(widget.currency), decimalDigits: 0);

    return Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderItem(
                title: 'Bitcoin Price',
                value: bitcoinPriceFormat.format(widget.currentBtcPrice),
                subtitle: currencyToString(widget.currency),
                icon: Icons.currency_bitcoin,
                iconColor: Color(0xFFF7931A),
                valueColor: widget.isDarkMode ? Colors.white : Colors.black),
            _buildHeaderItem(
                title: 'Stack Value',
                value: widget.holdingsHidden
                    ? '****'
                    : stackValueFormat.format(widget.portfolioValue),
                subtitle: widget.holdingsHidden
                    ? '****'
                    : currencyToString(widget.currency),
                icon: Icons.account_balance_wallet,
                iconColor: Colors.blue,
                valueColor: widget.isDarkMode ? Colors.white : Colors.black),
            _buildHeaderItem(
                title: 'P&L',
                value: widget.holdingsHidden
                    ? '****'
                    : _formatCleanValue(widget.profitLoss, widget.currency),
                subtitle: widget.holdingsHidden
                    ? '****%'
                    : '${widget.profitLossPercentage.toStringAsFixed(2)}%',
                icon: widget.profitLoss >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                iconColor: profitLossColor,
                valueColor: profitLossColor),
          ],
        ));
  }

  Widget _buildHeaderItem(
      {required String title,
        required String value,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        required Color valueColor}) {
    return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 16),
                SizedBox(width: 6),
                Flexible(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: valueColor),
                  maxLines: 1),
            ),
            SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: widget.isDarkMode ? Colors.white54 : Colors.black54)),
          ],
        ));
  }

  String _formatCleanValue(double value, Currency currency) {
    if (value == 0) return '0';
    final absValue = value.abs();
    final symbol = _getCurrencySymbol(currency);
    final sign = value < 0 ? '-' : '';
    if (absValue >= 1000000)
      return '$sign$symbol${(absValue / 1000000).toStringAsFixed(absValue >= 10000000 ? 0 : 1)}M';
    else if (absValue >= 1000)
      return '$sign$symbol${(absValue / 1000).toStringAsFixed(absValue >= 10000 ? 0 : 1)}K';
    else if (absValue >= 1)
      return '$sign$symbol${absValue.toStringAsFixed(absValue >= 100 ? 0 : 2)}';
    else
      return '$sign$symbol${absValue.toStringAsFixed(4)}';
  }

  Widget _buildChartPlot({double? height}) {
    return Container(
      height: height ?? (kUseNiceChartAxes ? 216 : 200),
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: widget.holdingsHidden
          ? _buildHiddenChart()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (!constraints.hasBoundedWidth || constraints.maxWidth < 16) {
                  return const SizedBox.expand();
                }
                _chartWidth = constraints.maxWidth;
                try {
                  final chart = LineChart(_buildChartData());
                  if (!widget.expanded) return chart;
                  return GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    child: chart,
                  );
                } catch (e, st) {
                  print('LineChart error: $e\n$st');
                  return const Center(child: Text('Chart unavailable'));
                }
              },
            ),
    );
  }

  Widget _buildHiddenChart() {
    return Container(
        height: 200,
        decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8)),
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_off,
                    size: 40,
                    color: widget.isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                SizedBox(height: 8),
                Text('Holdings Hidden',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                SizedBox(height: 4),
                Text('Toggle visibility to view chart',
                    style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[500])),
              ],
            )));
  }

  Widget _buildActivityStrip() {
    final hasActivity = _stripBuys.any((c) => c > 0) || _stripSells.any((c) => c > 0);
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
              if (width < 8) return const SizedBox(height: 18);
              return GestureDetector(
                onTapDown: hasActivity
                    ? (details) => _onActivityStripTap(details, width)
                    : null,
                child: SizedBox(
                  height: 18,
                  width: width,
                  child: CustomPaint(
                    painter: _ActivityStripPainter(
                      buys: _stripBuys,
                      sells: _stripSells,
                      buyColor: _purchaseDotColor,
                      sellColor: _saleDotColor,
                    ),
                  ),
                ),
              );
            },
          ),
          if (_shouldClusterTrades)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tap a mark or the activity bar for trades',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onActivityStripTap(TapDownDetails details, double width) {
    final slotCount = _stripBuys.length;
    if (slotCount == 0 || width <= 0) return;
    final slot = (details.localPosition.dx / (width / slotCount)).floor().clamp(0, slotCount - 1);
    final clusters = _clustersForSlot(slot);
    if (clusters.isEmpty) return;
    final purchases = [for (final c in clusters) ...c.purchases];
    final sales = [for (final c in clusters) ...c.sales];
    final title = clusters.length == 1
        ? clusters.first.title
        : '${purchases.length + sales.length} trades';
    _showTradesDialog(title, purchases, sales);
  }

  Widget _buildTimeRangeSelector() {
    Widget row(List<PortfolioTimeRange> ranges) {
      return Row(
        children: [
          for (final range in ranges) _buildTimeRangeButton(range),
        ],
      );
    }

    const all = [
      PortfolioTimeRange.MONTH_1,
      PortfolioTimeRange.MONTH_6,
      PortfolioTimeRange.YEAR_1,
      PortfolioTimeRange.YEAR_2,
      PortfolioTimeRange.YEAR_3,
      PortfolioTimeRange.YEAR_4,
      PortfolioTimeRange.YEAR_5,
      PortfolioTimeRange.YEAR_10,
      PortfolioTimeRange.MAX,
    ];
    if (MediaQuery.sizeOf(context).width >= 640) {
      return row(all);
    }
    return Column(
      children: [
        row(all.sublist(0, 5)),
        const SizedBox(height: 4),
        row(all.sublist(5)),
      ],
    );
  }

  Widget _buildTimeRangeButton(PortfolioTimeRange timeRange) {
    final isSelected = _selectedTimeRange == timeRange;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Color(0xFFF7931A)
                    : widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            onPressed: () => _setTimeRange(timeRange),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_getTimeRangeLabel(timeRange),
                  style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : widget.isDarkMode ? Colors.white : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1),
            )),
      ),
    );
  }

  LineChartData _buildChartData() {
    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (event, response) {
          if (event is FlTapUpEvent &&
              response?.lineBarSpots != null &&
              response!.lineBarSpots!.isNotEmpty) {
            final spot = response.lineBarSpots!.first;
            final index = spot.spotIndex.toInt();
            if (index < 0 || index >= _portfolioData.length) return;
            if (kUseNiceChartAxes) {
              final cluster = _clusterByIndex[index];
              if (cluster != null) {
                _showClusterDetails(cluster);
              }
            } else {
              final dataPoint = _portfolioData[index];
              final purchases = _getPurchasesForDate(dataPoint.date);
              final sales = _getSalesForDate(dataPoint.date);
              if (purchases.isNotEmpty || sales.isNotEmpty) {
                _showDateDetails(dataPoint.date, purchases, sales);
              }
            }
          }
          if (response?.lineBarSpots != null &&
              response!.lineBarSpots!.isNotEmpty) {
            final spot = response.lineBarSpots!.first;
            final index = spot.spotIndex.toInt();
            if (!mounted || index < 0 || index >= _portfolioData.length) return;
            if (kUseNiceChartAxes) {
              setState(() => _hoveredIndex =
                  _clusterByIndex.containsKey(index) ? index : null);
            } else {
              final dataPoint = _portfolioData[index];
              final isPurchaseOrSale =
                  _isPurchaseDate(dataPoint.date) || _isSaleDate(dataPoint.date);
              setState(() => _hoveredIndex =
              isPurchaseOrSale ? index : null);
            }
          } else if (mounted) {
            setState(() => _hoveredIndex = null);
          }
        },
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: widget.isDarkMode
              ? Colors.blueGrey[800]!.withOpacity(0.95)
              : Colors.blueGrey[50]!.withOpacity(0.95),
          tooltipRoundedRadius: 8,
          tooltipPadding: EdgeInsets.all(12),
          getTooltipItems: (touchedSpots) =>
              touchedSpots.map((touchedSpot) {
                if (touchedSpot.spotIndex < 0 ||
                    touchedSpot.spotIndex >= _portfolioData.length) {
                  return LineTooltipItem('', const TextStyle(fontSize: 1));
                }
                final dataPoint = _portfolioData[touchedSpot.spotIndex];

                if (kUseNiceChartAxes &&
                    touchedSpot.barIndex == 0 &&
                    _clusterByIndex.containsKey(touchedSpot.spotIndex)) {
                  final cluster = _clusterByIndex[touchedSpot.spotIndex]!;
                  final currencySymbol = _getCurrencySymbol(widget.currency);
                  final parts = <String>[cluster.title];
                  if (cluster.purchases.isNotEmpty) {
                    parts.add('${cluster.purchases.length} purchase${cluster.purchases.length == 1 ? '' : 's'}');
                  }
                  if (cluster.sales.isNotEmpty) {
                    parts.add('${cluster.sales.length} sale${cluster.sales.length == 1 ? '' : 's'}');
                  }
                  parts.add(_formatCompactValue(
                      cluster.purchases.fold(0.0, (sum, p) => sum + p.amountBTC * widget.currentBtcPrice),
                      currencySymbol));
                  return LineTooltipItem(
                    parts.join('\n'),
                    TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  );
                }

                if (touchedSpot.barIndex == 0 &&
                    (_isPurchaseDate(dataPoint.date) ||
                        _isSaleDate(dataPoint.date))) {
                  final purchases = _getPurchasesForDate(dataPoint.date);
                  final sales = _getSalesForDate(dataPoint.date);

                  String tooltipText = '${_formatTooltipDate(dataPoint.date)}\n';

                  if (purchases.isNotEmpty && purchases.length == 1) {
                    final purchase = purchases.first;
                    final purchaseValueInSelectedCurrency = _convertCurrency(
                        purchase.totalCashSpent,
                        purchase.cashCurrency,
                        widget.currency);
                    final currentValue = purchase.amountBTC * widget.currentBtcPrice;
                    final profitLoss =
                        currentValue - purchaseValueInSelectedCurrency;
                    final profitLossPercentage =
                    purchaseValueInSelectedCurrency > 0
                        ? (profitLoss / purchaseValueInSelectedCurrency) * 100
                        : 0;
                    final isProfit = profitLoss >= 0;
                    final currencySymbol = _getCurrencySymbol(widget.currency);

                    tooltipText +=
                    'Buy: ${formatDenomination(purchase.amountBTC, widget.denomination)} @ ${_formatCompactPrice(_convertCurrency(purchase.pricePerBTC, purchase.cashCurrency, widget.currency))}\n';
                    tooltipText +=
                    '${_formatCompactValue(currentValue, currencySymbol)} | ${isProfit ? '+' : ''}${_formatCompactValue(profitLoss, currencySymbol)} (${profitLossPercentage.toStringAsFixed(1)}%)\n';
                  } else if (purchases.isNotEmpty) {
                    final totalAmount = _getTotalPurchaseAmount(purchases);
                    final averagePricePerBTC = _getAveragePurchasePrice(purchases);
                    final purchaseValue = _calculatePurchaseValue(purchases);
                    final currentValue = _calculateCurrentValue(purchases);
                    final profitLoss = currentValue - purchaseValue;
                    final profitLossPercentage = purchaseValue > 0
                        ? (profitLoss / purchaseValue) * 100
                        : 0;
                    final isProfit = profitLoss >= 0;
                    final currencySymbol = _getCurrencySymbol(widget.currency);

                    tooltipText +=
                    '${purchases.length}× ${formatDenomination(totalAmount, widget.denomination)}\n';
                    tooltipText += 'Avg: ${_formatCompactPrice(averagePricePerBTC)}\n';
                    tooltipText +=
                    '${_formatCompactValue(currentValue, currencySymbol)} | ${isProfit ? '+' : ''}${_formatCompactValue(profitLoss, currencySymbol)} (${profitLossPercentage.toStringAsFixed(1)}%)\n';
                  }

                  if (sales.isNotEmpty) {
                    for (final sale in sales) {
                      final saleValue = sale.amountBTC * sale.price;
                      final saleValueInSelectedCurrency = _convertCurrency(
                          saleValue, sale.originalCurrency, widget.currency);
                      final currencySymbol = _getCurrencySymbol(widget.currency);

                      tooltipText +=
                      'Sale: ${formatDenomination(sale.amountBTC, widget.denomination)} @ ${_formatCompactPrice(sale.price)} (${_formatCompactValue(saleValueInSelectedCurrency, currencySymbol)})\n';
                    }
                  }

                  return LineTooltipItem(
                    tooltipText.trim(),
                    TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  );
                }

                final title =
                touchedSpot.barIndex == 0 ? 'Stack Value' : 'Investment';
                final currencySymbol = _getCurrencySymbol(widget.currency);
                return LineTooltipItem(
                  '$title\n${_formatCompactValue(touchedSpot.y, currencySymbol)}',
                  TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                );
              }).toList(),
        ),
        handleBuiltInTouches: true,
        getTouchLineStart: (data, index) => _minValue,
        getTouchLineEnd: (data, index) => _maxValue,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: kUseNiceChartAxes
            ? _yInterval
            : _getPriceInterval(_minValue, _maxValue),
        verticalInterval: kUseNiceChartAxes ? 1 : _getTimeInterval(),
        checkToShowVerticalLine: (value) {
          if (!kUseNiceChartAxes) return true;
          return _xTicks.contains(value.round());
        },
        getDrawingHorizontalLine: (value) => FlLine(
          color: widget.isDarkMode
              ? Colors.grey.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: widget.isDarkMode
              ? Colors.grey.withOpacity(0.08)
              : Colors.grey.withOpacity(0.08),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: kUseNiceChartAxes ? 1 : _getTimeInterval(),
            reservedSize: kUseNiceChartAxes ? 28 : 48,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value >= _portfolioData.length) return const SizedBox();
              final index = value.round();
              if (kUseNiceChartAxes && !_xTicks.contains(index)) {
                return const SizedBox();
              }
              if ((value - index).abs() > 0.01) return const SizedBox();
              final date = _portfolioData[index].date;
              final label = _formatChartDate(date);
              if (kUseNiceChartAxes) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 10,
                        color: widget.isDarkMode ? Colors.white54 : Colors.black54),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 8 : 0, top: 16.0),
                child: Transform.rotate(
                  angle: -0.4,
                  alignment: Alignment.topLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 9,
                        color: widget.isDarkMode ? Colors.white54 : Colors.black54),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: kUseNiceChartAxes
                ? _yInterval
                : _getPriceInterval(_minValue, _maxValue),
            reservedSize: kUseNiceChartAxes ? 44 : 55,
            getTitlesWidget: (value, meta) {
              if (kUseNiceChartAxes) {
                if (!_yInterval.isFinite || _yInterval <= 0) {
                  return const SizedBox();
                }
                final ticksFromMin = ((value - _minValue) / _yInterval);
                if (!ticksFromMin.isFinite) return const SizedBox();
                if ((ticksFromMin - ticksFromMin.round()).abs() > 0.02) {
                  return const SizedBox();
                }
              } else {
                if (value < _minValue || value > _maxValue) {
                  return const SizedBox();
                }
                final yStep = _getPriceInterval(_minValue, _maxValue);
                if (yStep > 0) {
                  final distMin = (value - _minValue).abs();
                  final distMax = (value - _maxValue).abs();
                  final isMin = distMin <= yStep * 0.08;
                  final isMax = distMax <= yStep * 0.08;
                  final onGridZero =
                      ((value / yStep) - (value / yStep).round()).abs() < 0.08;
                  final fromMin = (value - _minValue) / yStep;
                  final onGridMin = (fromMin - fromMin.round()).abs() < 0.08;
                  final onGrid = onGridZero || onGridMin;
                  if (!isMin && !isMax && !onGrid) {
                    return const SizedBox();
                  }
                  if (onGrid && !isMin && distMin < yStep * 0.18) {
                    return const SizedBox();
                  }
                  // Drop the extra top $ so it does not sit on the last grid tick.
                  if (isMax && !onGrid) {
                    return const SizedBox();
                  }
                  if (onGrid && !isMax && distMax < yStep * 0.35) {
                    return const SizedBox();
                  }
                }
              }
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  _formatPriceForAxis(value, widget.currency),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: false,
        horizontalLines: [
          if (_minValue < 0 && _maxValue > 0)
            HorizontalLine(
              y: 0,
              color: widget.isDarkMode
                  ? Colors.white.withOpacity(0.35)
                  : Colors.black.withOpacity(0.35),
              strokeWidth: 1,
            ),
        ],
      ),
      borderData: FlBorderData(show: false),
      minX: _minX,
      maxX: _maxX,
      minY: _minValue.isFinite ? _minValue : 0,
      maxY: (_maxValue.isFinite && _maxValue > _minValue)
          ? _maxValue
          : (_minValue.isFinite ? _minValue + 1 : 1),
      lineBarsData: [
        _buildPortfolioLine(),
        _buildInvestmentLine(),
      ],
    );
  }

  String _formatCompactPrice(double price) {
    if (price >= 1000) {
      return '${_getCurrencySymbol(widget.currency)}${(price / 1000).toStringAsFixed(price >= 10000 ? 0 : 1)}k';
    }
    return '${_getCurrencySymbol(widget.currency)}${price.toStringAsFixed(price >= 100 ? 0 : 2)}';
  }

  String _formatCompactValue(double value, String currencySymbol) {
    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';

    if (absValue >= 1000000) {
      return '$sign$currencySymbol${(absValue / 1000000).toStringAsFixed(absValue >= 10000000 ? 0 : 1)}M';
    } else if (absValue >= 1000) {
      return '$sign$currencySymbol${(absValue / 1000).toStringAsFixed(absValue >= 10000 ? 0 : 1)}K';
    } else if (absValue >= 1) {
      return '$sign$currencySymbol${absValue.toStringAsFixed(absValue >= 100 ? 0 : 2)}';
    } else {
      return '$sign$currencySymbol${absValue.toStringAsFixed(4)}';
    }
  }

  LineChartBarData _buildPortfolioLine() {
    return LineChartBarData(
      spots: _portfolioData
          .asMap()
          .entries
          .map((entry) => FlSpot(
                entry.key.toDouble(),
                entry.value.portfolioValue.isFinite
                    ? entry.value.portfolioValue
                    : 0,
              ))
          .toList(),
      isCurved: true,
      color: _portfolioColor,
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            _portfolioColor.withOpacity(0.3),
            _portfolioColor.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final isHovered = _hoveredIndex == index;
          if (index < 0 || index >= _portfolioData.length) {
            return FlDotCirclePainter(radius: 0, color: Colors.transparent);
          }
          if (kUseNiceChartAxes) {
            final cluster = _clusterByIndex[index.toInt()];
            if (cluster == null) {
              return FlDotCirclePainter(radius: 0, color: Colors.transparent);
            }
            final hasPurchases = cluster.purchases.isNotEmpty;
            final hasSales = cluster.sales.isNotEmpty;
            final count = cluster.tradeCount;
            final radius = (isHovered ? 7.0 : 5.0) + math.min(4.0, math.log(count + 1));
            return CustomDotPainter(
              radius: radius,
              color: hasPurchases && !hasSales
                  ? _purchaseDotColor
                  : (!hasPurchases && hasSales ? _saleDotColor : _purchaseDotColor),
              strokeWidth: isHovered ? 3 : 2,
              strokeColor: isHovered ? Colors.white : (hasSales && hasPurchases ? _saleDotColor : Colors.transparent),
              hasSale: hasSales && hasPurchases,
              saleDotColor: _saleDotColor,
              saleDotRadius: isHovered ? 3 : 1.5,
              badge: count > 1 ? (count > 99 ? '99+' : '$count') : null,
            );
          }

          final dataPoint = _portfolioData[index.toInt()].date;
          final isPurchaseDate = _isPurchaseDate(dataPoint);
          final isSaleDate = _isSaleDate(dataPoint);

          final isPureSaleDate = isSaleDate && !isPurchaseDate;

          if (isPureSaleDate) {
            return CustomDotPainter(
              radius: isHovered ? 8 : 6,
              color: _saleDotColor,
              strokeWidth: isHovered ? 3 : 2,
              strokeColor: isHovered ? Colors.white : _saleDotColor,
              hasSale: false,
              saleDotColor: Colors.transparent,
              saleDotRadius: 0,
            );
          } else if (isPurchaseDate) {
            final purchases = _getPurchasesForDate(dataPoint);
            final profitLoss = _calculateProfitLoss(purchases);
            final isProfit = profitLoss > 0, isLoss = profitLoss < 0;

            return CustomDotPainter(
              radius: isHovered ? 8 : 5,
              color: _purchaseDotColor,
              strokeWidth: isHovered ? 3 : 2,
              strokeColor: isHovered
                  ? Colors.white
                  : (isProfit ? _profitColor : (isLoss ? _lossColor : Colors.grey)),
              hasSale: isSaleDate,
              saleDotColor: _saleDotColor,
              saleDotRadius: isHovered ? 3 : 1.5,
            );
          }
          return FlDotCirclePainter(
            radius: 0,
            color: Colors.transparent,
          );
        },
      ),
      shadow: Shadow(
        color: _portfolioColor.withOpacity(0.2),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    );
  }

  LineChartBarData _buildInvestmentLine() {
    return LineChartBarData(
      spots: _portfolioData
          .asMap()
          .entries
          .map((entry) => FlSpot(
                entry.key.toDouble(),
                entry.value.investmentValue.isFinite
                    ? entry.value.investmentValue
                    : 0,
              ))
          .toList(),
      isCurved: true,
      color: _investmentColor.withOpacity(0.6),
      barWidth: 1.5,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      dashArray: [3, 3],
    );
  }

  Widget _buildLegendAndMetrics(Color profitLossColor) {
    final priceFormat = NumberFormat.currency(
        symbol: _getCurrencySymbol(widget.currency),
        decimalDigits: _getDecimalDigits(widget.currency, widget.portfolioValue));
    return Column(children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem('Stack Value', _portfolioColor),
            const SizedBox(width: 12),
            _buildLegendItem('Total Investment', _investmentColor),
            const SizedBox(width: 12),
            _buildLegendItem('Purchases', _purchaseDotColor),
            const SizedBox(width: 12),
            _buildLegendItem('Sales', _saleDotColor),
          ],
        ),
      ),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildDetailItem(
              'All-time ROI',
              widget.holdingsHidden
                  ? '****%'
                  : '${widget.profitLossPercentage.toStringAsFixed(2)}%',
              widget.isDarkMode,
              valueColor: profitLossColor)),
          Expanded(child: _buildDetailItem(
              '${_getTimeRangeLabel(_selectedTimeRange)} ROI',
              widget.holdingsHidden
                  ? '****%'
                  : '${_periodRoi.toStringAsFixed(2)}%',
              widget.isDarkMode,
              valueColor: _periodRoi >= 0 ? _profitColor : _lossColor)),
        ],
      ),
      SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;
        return isWide
            ? Row(
          children: [
            Expanded(child: _buildDetailItem('Total BTC',
                widget.holdingsHidden ? '****' : '${_totalBTC.toStringAsFixed(8)}', widget.isDarkMode)),
            Expanded(child: _buildDetailItem(
                'Avg Purchase Price',
                widget.holdingsHidden
                    ? '****'
                    : priceFormat.format(_averagePurchasePrice),
                widget.isDarkMode)),
            Expanded(child: _buildDetailItem('Purchases', '${widget.purchases.length}', widget.isDarkMode)),
            Expanded(child: _buildDetailItem('Sales', '${widget.sales.length}', widget.isDarkMode)),
          ],
        )
            : Column(children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('Total BTC',
                  widget.holdingsHidden ? '****' : '${_totalBTC.toStringAsFixed(8)}', widget.isDarkMode)),
              Expanded(child: _buildDetailItem(
                  'Avg Price',
                  widget.holdingsHidden
                      ? '****'
                      : priceFormat.format(_averagePurchasePrice),
                  widget.isDarkMode)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Purchases', '${widget.purchases.length}', widget.isDarkMode)),
              Expanded(child: _buildDetailItem('Sales', '${widget.sales.length}', widget.isDarkMode)),
            ],
          ),
        ]);
      }),
    ]);
  }

  Widget _buildDetailItem(
      String label, String value, bool isDarkMode, {Color? valueColor}) {
    final defaultColor = isDarkMode ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? defaultColor),
              maxLines: 1),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
        height: 320,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ]),
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up,
                    size: 48,
                    color: widget.isDarkMode ? Colors.white38 : Colors.black38),
                SizedBox(height: 16),
                Text('No portfolio data available',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                        fontSize: 16)),
                SizedBox(height: 8),
                Text('Add your first purchase to see your stack growth',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white38 : Colors.black38,
                        fontSize: 14),
                    textAlign: TextAlign.center),
              ],
            )));
  }

  Widget _buildLoadingState() {
    return Container(
        height: 320,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ]),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFFF7931A))));
  }

  double _getTimeInterval() {
    final dataLength = _portfolioData.length;
    if (dataLength <= 10) return 1;
    if (dataLength <= 20) return 2;
    if (dataLength <= 50) return 5;
    if (dataLength <= 100) return 10;
    return (dataLength / 8).ceilToDouble();
  }

  double _getPriceInterval(double minPrice, double maxPrice) {
    final priceRange = maxPrice - minPrice;
    if (!priceRange.isFinite || priceRange <= 0) return 1000;
    final double roughInterval = priceRange / 5;
    if (!roughInterval.isFinite || roughInterval <= 0) return 1000;
    final logVal = math.log(roughInterval) / math.ln10;
    if (!logVal.isFinite) return 1000;
    final double magnitude = math.pow(10, logVal.floor()).toDouble();
    final double remainder = roughInterval / magnitude;
    if (remainder < 1.5) return 1 * magnitude;
    else if (remainder < 3) return 2 * magnitude;
    else if (remainder < 7) return 5 * magnitude;
    else return 10 * magnitude;
  }

  String _formatChartDate(DateTime date) {
    final dataLength = _portfolioData.length;
    if (_useYearLabels) {
      return DateFormat('yyyy').format(date);
    }
    if (kUseNiceChartAxes) {
      switch (_selectedTimeRange) {
        case PortfolioTimeRange.MONTH_1:
          return DateFormat('d MMM').format(date);
        case PortfolioTimeRange.MONTH_6:
        case PortfolioTimeRange.YEAR_1:
          return DateFormat('MMM yy').format(date);
        default:
          return DateFormat('yyyy').format(date);
      }
    }
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        return DateFormat('d MMM').format(date);
      case PortfolioTimeRange.MONTH_6:
        return DateFormat('MMM').format(date);
      case PortfolioTimeRange.YEAR_1:
        return dataLength > 20
            ? DateFormat('MMM yy').format(date)
            : DateFormat('MMM yyyy').format(date);
      default:
        return DateFormat('yyyy').format(date);
    }
  }

  String _formatTooltipDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  NumberFormat _buildPriceFormat() => NumberFormat.currency(
      symbol: _getCurrencySymbol(widget.currency),
      decimalDigits: _getDecimalDigits(widget.currency, widget.portfolioValue));

  String _formatPriceForAxis(double price, Currency currency) {
    String symbol = _getCurrencySymbol(currency);
    final absPrice = price.abs();
    final sign = price < 0 ? '-' : '';
    if (kUseNiceChartAxes) {
      if (absPrice >= 1000000) {
        return '$sign$symbol${_trimAxisDecimal(absPrice / 1000000)}M';
      }
      if (absPrice >= 1000) {
        return '$sign$symbol${_trimAxisDecimal(absPrice / 1000)}K';
      }
      if (absPrice >= 1) return '$sign$symbol${absPrice.toStringAsFixed(0)}';
      return '$sign$symbol${absPrice.toStringAsFixed(2)}';
    }
    if (absPrice >= 1000000)
      return '$sign$symbol${(absPrice / 1000000).toStringAsFixed(1)}M';
    else if (absPrice >= 1000)
      return '$sign$symbol${(absPrice / 1000).toStringAsFixed(1)}K';
    else if (absPrice >= 1)
      return '$sign$symbol${absPrice.toStringAsFixed(0)}';
    else
      return '$sign$symbol${absPrice.toStringAsFixed(2)}';
  }

  String _trimAxisDecimal(double value) {
    if (value >= 10 || (value - value.round()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  int _getDecimalDigits(Currency currency, double price) {
    if (currency == Currency.JPY || currency == Currency.CNY) return 0;
    else if (price > 1000) return 0;
    else if (price > 1) return 2;
    else return 4;
  }

  String _getCurrencySymbol(Currency currency) {
    switch (currency) {
      case Currency.USD:
        return '\$';
      case Currency.GBP:
        return '£';
      case Currency.EUR:
        return '€';
      case Currency.CAD:
        return 'C\$';
      case Currency.AUD:
        return 'A\$';
      case Currency.JPY:
        return '¥';
      case Currency.CNY:
        return '¥';
    }
  }
}

class _TradeCluster {
  final int index;
  final String title;
  final List<Purchase> purchases = [];
  final List<Sale> sales = [];

  _TradeCluster({required this.index, required this.title});

  int get tradeCount => purchases.length + sales.length;
}

class _ActivityStripPainter extends CustomPainter {
  final List<int> buys;
  final List<int> sells;
  final Color buyColor;
  final Color sellColor;

  _ActivityStripPainter({
    required this.buys,
    required this.sells,
    required this.buyColor,
    required this.sellColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = buys.length;
    if (n == 0 || size.width <= 0) return;
    var maxCount = 0;
    for (var i = 0; i < n; i++) {
      final total = buys[i] + sells[i];
      if (total > maxCount) maxCount = total;
    }
    if (maxCount == 0) {
      final axis = Paint()
        ..color = sellColor.withOpacity(0.15)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), axis);
      return;
    }
    final barWidth = size.width / n;
    for (var i = 0; i < n; i++) {
      final buy = buys[i];
      final sell = sells[i];
      final total = buy + sell;
      if (total == 0) continue;
      final height = (total / maxCount) * size.height;
      final buyHeight = total == 0 ? 0.0 : height * (buy / total);
      final x = i * barWidth + barWidth * 0.15;
      final w = barWidth * 0.7;
      if (buy > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - buyHeight, w, buyHeight),
            const Radius.circular(1),
          ),
          Paint()..color = buyColor,
        );
      }
      if (sell > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - height, w, height - buyHeight),
            const Radius.circular(1),
          ),
          Paint()..color = sellColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityStripPainter oldDelegate) {
    return oldDelegate.buys != buys || oldDelegate.sells != sells;
  }
}

class CustomDotPainter extends FlDotPainter {
  final double radius;
  final Color color;
  final double strokeWidth;
  final Color strokeColor;
  final bool hasSale;
  final Color saleDotColor;
  final double saleDotRadius;
  final String? badge;

  CustomDotPainter({
    required this.radius,
    required this.color,
    this.strokeWidth = 0,
    this.strokeColor = Colors.transparent,
    this.hasSale = false,
    this.saleDotColor = Colors.purple,
    this.saleDotRadius = 1.5,
    this.badge,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetInCanvas, radius, outerPaint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(offsetInCanvas, radius, strokePaint);
    }

    if (hasSale) {
      final innerPaint = Paint()
        ..color = saleDotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offsetInCanvas, saleDotRadius, innerPaint);
    }

    if (badge != null && badge!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: badge,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        offsetInCanvas.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    }
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(radius * 2, radius * 2);
  }

  @override
  List<Object?> get props =>
      [radius, color, strokeWidth, strokeColor, hasSale, saleDotColor, saleDotRadius, badge];
}

class PortfolioDataPoint {
  final DateTime date;
  final double portfolioValue;
  final double investmentValue;
  final double btcAmount;

  PortfolioDataPoint(
      {required this.date,
        required this.portfolioValue,
        required this.investmentValue,
        required this.btcAmount});
}