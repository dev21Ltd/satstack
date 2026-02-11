// charts.dart - OPTIMIZED TOOLTIP VERSION WITH ACCURATE PORTFOLIO VALUE USING ACTUAL TRANSACTION PRICES
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'constants.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';

enum PortfolioTimeRange { MONTH_1, MONTH_6, YEAR_1, YEAR_3, MAX }

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
    _calculatePortfolioData();
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
      _calculatePortfolioData();
      if (_isInitialized) {
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  void _setTimeRange(PortfolioTimeRange timeRange) {
    setState(() => _selectedTimeRange = timeRange);
    _calculatePortfolioData();
  }

  void _calculatePortfolioData() {
    if (widget.purchases.isEmpty) {
      _portfolioData = [];
      setState(() {});
      return;
    }

    final sortedPurchases = List<Purchase>.from(widget.purchases)
      ..sort((a, b) => a.date.compareTo(b.date));
    _totalBTC = sortedPurchases.fold(
        0.0, (sum, purchase) => sum + purchase.amountBTC) -
        widget.sales.fold(0.0, (sum, sale) => sum + sale.amountBTC);

    double totalInvestment = sortedPurchases.fold(
        0.0,
            (sum, purchase) =>
        sum +
            _convertCurrency(purchase.totalCashSpent, purchase.cashCurrency,
                widget.currency));
    _averagePurchasePrice = _totalBTC > 0 ? totalInvestment / _totalBTC : 0;

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
          widget.currency);
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

    _calculateMinMaxValues();
    setState(() {});
  }

  DateTime _calculateStartDate(DateTime firstPurchaseDate, DateTime now) {
    DateTime startDate;
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        startDate = _getStartDate(
            firstPurchaseDate, DateTime(now.year, now.month - 1, now.day));
        break;
      case PortfolioTimeRange.MONTH_6:
        startDate = _getStartDate(
            firstPurchaseDate, DateTime(now.year, now.month - 6, now.day));
        break;
      case PortfolioTimeRange.YEAR_1:
        startDate = _getStartDate(
            firstPurchaseDate, DateTime(now.year - 1, now.month, now.day));
        break;
      case PortfolioTimeRange.YEAR_3:
        startDate = _getStartDate(
            firstPurchaseDate, DateTime(now.year - 3, now.month, now.day));
        break;
      case PortfolioTimeRange.MAX:
        startDate = firstPurchaseDate;
        if (startDate.isBefore(DateTime(2009, 1, 3)))
          startDate = DateTime(2009, 1, 3);
        break;
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

    if (_selectedTimeRange == PortfolioTimeRange.MAX &&
        allDates.length > 100) {
      List<DateTime> sampledDates = [];
      final step = (allDates.length / 50).ceil();
      for (int i = 0; i < allDates.length; i += step)
        sampledDates.add(allDates[i]);
      if (!sampledDates.contains(allDates.first))
        sampledDates.insert(0, allDates.first);
      if (!sampledDates.contains(allDates.last))
        sampledDates.add(allDates.last);
      allDates = sampledDates;
    }
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

    final valueRange = _maxValue - _minValue;
    if (valueRange > 0) {
      _minValue -= valueRange * 0.05;
      _maxValue += valueRange * 0.05;
    } else if (_maxValue > 0) {
      _minValue *= 0.95;
      _maxValue *= 1.05;
    }

    if (_maxValue - _minValue < _maxValue * 0.1) {
      final mid = (_maxValue + _minValue) / 2;
      final range = _maxValue * 0.1;
      _minValue = mid - range / 2;
      _maxValue = mid + range / 2;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTimeRangeLabel(PortfolioTimeRange timeRange) {
    switch (timeRange) {
      case PortfolioTimeRange.MONTH_1:
        return '1M';
      case PortfolioTimeRange.MONTH_6:
        return '6M';
      case PortfolioTimeRange.YEAR_1:
        return '1Y';
      case PortfolioTimeRange.YEAR_3:
        return '3Y';
      case PortfolioTimeRange.MAX:
        return 'Max';
    }
  }

  double _convertCurrency(double amount, Currency from, Currency to) {
    if (from == to) return amount;
    final btcPriceFrom = widget.btcPrices[from] ?? 0.0;
    final btcPriceTo = widget.btcPrices[to] ?? 0.0;
    if (btcPriceFrom == 0 || btcPriceTo == 0) return amount;
    return (amount / btcPriceFrom) * btcPriceTo;
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
    if (widget.holdingsHidden) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Holdings are currently hidden'),
          backgroundColor: Colors.orange));
      return;
    }

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
            date,
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
      DateTime date,
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
      title: Text('${date.day}/${date.month}/${date.year}',
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
    return Animate(
        effects: [FadeEffect(duration: 300.ms), ScaleEffect(duration: 300.ms)],
        child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ]),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCleanHeader(profitLossColor),
                SizedBox(height: 20),
                _buildTimeRangeSelector(),
                SizedBox(height: 20),

                Container(
                  height: 200,
                  constraints: BoxConstraints(minWidth: double.infinity),
                  child: widget.holdingsHidden
                      ? _buildHiddenChart()
                      : LineChart(_buildChartData()),
                ),

                SizedBox(height: 16),
                _buildLegendAndMetrics(profitLossColor),
              ],
            )));
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
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
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

  Widget _buildTimeRangeSelector() {
    return Container(
        width: double.infinity,
        child: LayoutBuilder(builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth / 5 - 8;
          return Container(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimeRangeButton(PortfolioTimeRange.MONTH_1, buttonWidth),
                  _buildTimeRangeButton(PortfolioTimeRange.MONTH_6, buttonWidth),
                  _buildTimeRangeButton(PortfolioTimeRange.YEAR_1, buttonWidth),
                  _buildTimeRangeButton(PortfolioTimeRange.YEAR_3, buttonWidth),
                  _buildTimeRangeButton(PortfolioTimeRange.MAX, buttonWidth),
                ],
              ));
        }));
  }

  Widget _buildTimeRangeButton(PortfolioTimeRange timeRange, double buttonWidth) {
    final isSelected = _selectedTimeRange == timeRange;
    return Container(
        width: buttonWidth,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Color(0xFFF7931A)
                    : widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            onPressed: () => _setTimeRange(timeRange),
            child: Text(_getTimeRangeLabel(timeRange),
                style: TextStyle(
                    color: isSelected
                        ? Colors.black
                        : widget.isDarkMode ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis)));
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
            final dataPoint = _portfolioData[spot.spotIndex.toInt()];
            final purchases = _getPurchasesForDate(dataPoint.date);
            final sales = _getSalesForDate(dataPoint.date);
            if (purchases.isNotEmpty || sales.isNotEmpty) {
              _showDateDetails(dataPoint.date, purchases, sales);
            }
          }
          if (response?.lineBarSpots != null &&
              response!.lineBarSpots!.isNotEmpty) {
            final spot = response.lineBarSpots!.first;
            final dataPoint = _portfolioData[spot.spotIndex.toInt()];
            final isPurchaseOrSale =
                _isPurchaseDate(dataPoint.date) || _isSaleDate(dataPoint.date);
            setState(() => _hoveredIndex =
            isPurchaseOrSale ? spot.spotIndex : null);
          } else {
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
                final dataPoint = _portfolioData[touchedSpot.spotIndex];

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
        horizontalInterval: _getPriceInterval(_minValue, _maxValue),
        verticalInterval: _getTimeInterval(),
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
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _getTimeInterval(),
            getTitlesWidget: (value, meta) {
              if (value < 0 || value >= _portfolioData.length) return SizedBox();
              final date = _portfolioData[value.toInt()].date;
              return Transform.rotate(
                angle: -0.4,
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    _formatChartDate(date),
                    style: TextStyle(
                        fontSize: 9,
                        color: widget.isDarkMode ? Colors.white54 : Colors.black54),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _getPriceInterval(_minValue, _maxValue),
            reservedSize: 55,
            getTitlesWidget: (value, meta) {
              if (value < _minValue || value > _maxValue) return SizedBox();
              return Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Text(
                  _formatPriceForAxis(value, widget.currency),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (_portfolioData.length - 1).toDouble(),
      minY: _minValue,
      maxY: _maxValue,
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
          .map((entry) =>
          FlSpot(entry.key.toDouble(), entry.value.portfolioValue))
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
          final dataPoint = _portfolioData[index.toInt()].date;
          final isPurchaseDate = _isPurchaseDate(dataPoint);
          final isSaleDate = _isSaleDate(dataPoint);
          final isHovered = _hoveredIndex == index;

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
          .map((entry) =>
          FlSpot(entry.key.toDouble(), entry.value.investmentValue))
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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Stack Value', _portfolioColor),
          SizedBox(width: 12),
          _buildLegendItem('Total Investment', _investmentColor),
          SizedBox(width: 12),
          _buildLegendItem('Purchases', _purchaseDotColor),
          SizedBox(width: 12),
          _buildLegendItem('Sales', _saleDotColor),
        ],
      ),
      SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;
        return isWide
            ? Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailItem('Total BTC',
                widget.holdingsHidden ? '****' : '${_totalBTC.toStringAsFixed(8)}', widget.isDarkMode),
            _buildDetailItem(
                'Avg Purchase Price',
                widget.holdingsHidden
                    ? '****'
                    : priceFormat.format(_averagePurchasePrice),
                widget.isDarkMode),
            _buildDetailItem('Purchases', '${widget.purchases.length}', widget.isDarkMode),
            _buildDetailItem('Sales', '${widget.sales.length}', widget.isDarkMode),
            _buildDetailItem(
                'ROI',
                widget.holdingsHidden
                    ? '****%'
                    : '${widget.profitLossPercentage.toStringAsFixed(2)}%',
                widget.isDarkMode,
                valueColor: profitLossColor),
          ],
        )
            : Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem('Total BTC',
                  widget.holdingsHidden ? '****' : '${_totalBTC.toStringAsFixed(8)}', widget.isDarkMode),
              _buildDetailItem(
                  'Avg Price',
                  widget.holdingsHidden
                      ? '****'
                      : priceFormat.format(_averagePurchasePrice),
                  widget.isDarkMode),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem('Purchases', '${widget.purchases.length}', widget.isDarkMode),
              _buildDetailItem('Sales', '${widget.sales.length}', widget.isDarkMode),
              _buildDetailItem(
                  'ROI',
                  widget.holdingsHidden
                      ? '****%'
                      : '${widget.profitLossPercentage.toStringAsFixed(2)}%',
                  widget.isDarkMode,
                  valueColor: profitLossColor),
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
                color: isDarkMode ? Colors.white54 : Colors.black54)),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? defaultColor)),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              fontSize: 12,
              color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
    ]);
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
    if (priceRange <= 0) return 1000;
    final double roughInterval = priceRange / 5;
    final double magnitude =
    math.pow(10, (math.log(roughInterval) / math.ln10).floor()).toDouble();
    final double remainder = roughInterval / magnitude;
    if (remainder < 1.5) return 1 * magnitude;
    else if (remainder < 3) return 2 * magnitude;
    else if (remainder < 7) return 5 * magnitude;
    else return 10 * magnitude;
  }

  String _formatChartDate(DateTime date) {
    final now = DateTime.now();
    final dataLength = _portfolioData.length;
    switch (_selectedTimeRange) {
      case PortfolioTimeRange.MONTH_1:
        return DateFormat('d MMM').format(date);
      case PortfolioTimeRange.MONTH_6:
        return DateFormat('MMM').format(date);
      case PortfolioTimeRange.YEAR_1:
        return dataLength > 20
            ? DateFormat('MMM yy').format(date)
            : DateFormat('MMM yyyy').format(date);
      case PortfolioTimeRange.YEAR_3:
        return DateFormat('yyyy').format(date);
      case PortfolioTimeRange.MAX:
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
    if (absPrice >= 1000000)
      return '$sign$symbol${(absPrice / 1000000).toStringAsFixed(1)}M';
    else if (absPrice >= 1000)
      return '$sign$symbol${(absPrice / 1000).toStringAsFixed(1)}K';
    else if (absPrice >= 1)
      return '$sign$symbol${absPrice.toStringAsFixed(0)}';
    else
      return '$sign$symbol${absPrice.toStringAsFixed(2)}';
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

class CustomDotPainter extends FlDotPainter {
  final double radius;
  final Color color;
  final double strokeWidth;
  final Color strokeColor;
  final bool hasSale;
  final Color saleDotColor;
  final double saleDotRadius;

  CustomDotPainter({
    required this.radius,
    required this.color,
    this.strokeWidth = 0,
    this.strokeColor = Colors.transparent,
    this.hasSale = false,
    this.saleDotColor = Colors.purple,
    this.saleDotRadius = 1.5,
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
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(radius * 2, radius * 2);
  }

  @override
  List<Object?> get props =>
      [radius, color, strokeWidth, strokeColor, hasSale, saleDotColor, saleDotRadius];
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