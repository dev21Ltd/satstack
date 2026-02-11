// purchase_calendar.dart - UPDATED WITH SALES VISIBILITY
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'constants.dart';

class PurchaseCalendar extends StatefulWidget {
  final List<Purchase> purchases;
  final List<Sale> sales;
  final Function(DateTime) onDateSelected;
  final bool isDarkMode;
  final DateTime? selectedDate;
  final double currentBtcPrice;
  final Currency selectedCurrency;
  final Function(Purchase) onEditPurchase;
  final Function(Purchase) onDeletePurchase;
  final Function(Sale) onEditSale;
  final Function(Sale) onDeleteSale;
  final Denomination denomination;
  final Map<Currency, double> btcPrices;
  final bool holdingsHidden;

  const PurchaseCalendar({
    Key? key,
    required this.purchases,
    required this.sales,
    required this.onDateSelected,
    required this.isDarkMode,
    this.selectedDate,
    required this.currentBtcPrice,
    required this.selectedCurrency,
    required this.onEditPurchase,
    required this.onDeletePurchase,
    required this.onEditSale,
    required this.onDeleteSale,
    required this.denomination,
    required this.btcPrices,
    required this.holdingsHidden,
  }) : super(key: key);

  @override
  State<PurchaseCalendar> createState() => _PurchaseCalendarState();
}

class _PurchaseCalendarState extends State<PurchaseCalendar> {
  DateTime _currentDisplayedMonth = DateTime.now();
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();
  final DateTime _genesisBlock = DateTime(2009, 1, 3);
  double _bottomPadding = 0;

  @override
  void initState() {
    super.initState();
    _currentDisplayedMonth = DateTime(
        _currentDisplayedMonth.year, _currentDisplayedMonth.month);
    _selectedDate = widget.selectedDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBottomPadding();
  }

  void _calculateBottomPadding() {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    setState(() {
      _bottomPadding = bottomPadding > 0 ? bottomPadding : 16;
    });
  }

  @override
  void didUpdateWidget(PurchaseCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        _selectedDate = widget.selectedDate;
        if (_selectedDate != null) {
          _currentDisplayedMonth = DateTime(
              _selectedDate!.year, _selectedDate!.month);
        }
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentDisplayedMonth = DateTime(
          _currentDisplayedMonth.year, _currentDisplayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDisplayedMonth = DateTime(
          _currentDisplayedMonth.year, _currentDisplayedMonth.month + 1);
    });
  }

  void _selectYear(int year) {
    setState(() {
      _currentDisplayedMonth = DateTime(year, _currentDisplayedMonth.month);
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _currentDisplayedMonth = DateTime(_currentDisplayedMonth.year, month);
    });
  }

  void _jumpToDate(DateTime date) {
    setState(() {
      _currentDisplayedMonth = DateTime(date.year, date.month);
      _selectedDate = date;
    });
    widget.onDateSelected(date);
  }

  void _handleDateInput() {
    try {
      final input = _dateController.text.trim();
      final parts = input.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final newDate = DateTime(year, month, day);
        if (newDate.isAfter(_genesisBlock) &&
            newDate.isBefore(DateTime.now().add(const Duration(days: 1)))) {
          _jumpToDate(newDate);
        } else {
          _showError('Date must be between 03/01/2009 and today');
        }
      } else {
        _showError('Please use DD/MM/YYYY format');
      }
    } catch (e) {
      _showError('Invalid date format');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isPurchaseDate(DateTime date) {
    return widget.purchases.any((purchase) =>
    purchase.date.year == date.year &&
        purchase.date.month == date.month &&
        purchase.date.day == date.day);
  }

  bool _isSaleDate(DateTime date) {
    return widget.sales.any((sale) =>
    sale.date.year == date.year &&
        sale.date.month == date.month &&
        sale.date.day == date.day);
  }

  List<Purchase> _getPurchasesForDate(DateTime date) {
    return widget.purchases.where((purchase) =>
    purchase.date.year == date.year &&
        purchase.date.month == date.month &&
        purchase.date.day == date.day).toList();
  }

  List<Sale> _getSalesForDate(DateTime date) {
    return widget.sales.where((sale) =>
    sale.date.year == date.year &&
        sale.date.month == date.month &&
        sale.date.day == date.day).toList();
  }

  double _getTotalPurchaseAmount(List<Purchase> purchases) {
    return purchases.fold(
        0.0, (sum, purchase) => sum + purchase.amountBTC);
  }

  double _convertCurrency(double amount, Currency from, Currency to) {
    if (from == to) return amount;
    final btcPriceFrom = widget.btcPrices[from] ?? 0.0;
    final btcPriceTo = widget.btcPrices[to] ?? 0.0;
    if (btcPriceFrom == 0 || btcPriceTo == 0) return amount;
    double amountInBTC = amount / btcPriceFrom;
    return amountInBTC * btcPriceTo;
  }

  double _getAveragePurchasePrice(List<Purchase> purchases) {
    if (purchases.isEmpty) return 0;
    double totalValue = 0;
    double totalBTC = 0;
    for (var purchase in purchases) {
      double purchaseValueInSelectedCurrency = _convertCurrency(
          purchase.amountBTC * purchase.pricePerBTC,
          purchase.cashCurrency,
          widget.selectedCurrency);
      totalValue += purchaseValueInSelectedCurrency;
      totalBTC += purchase.amountBTC;
    }
    if (totalBTC == 0) return 0;
    return totalValue / totalBTC;
  }

  double _calculatePurchaseValue(List<Purchase> purchases) {
    return purchases.fold(0.0, (sum, purchase) {
      return sum +
          _convertCurrency(purchase.amountBTC * purchase.pricePerBTC,
              purchase.cashCurrency, widget.selectedCurrency);
    });
  }

  double _calculateCurrentValue(List<Purchase> purchases) {
    return purchases.fold(
        0.0,
            (sum, purchase) =>
        sum + (purchase.amountBTC * widget.currentBtcPrice));
  }

  double _calculateProfitLoss(List<Purchase> purchases) {
    if (purchases.isEmpty) return 0;
    return _calculateCurrentValue(purchases) -
        _calculatePurchaseValue(purchases);
  }

  double _calculateProfitLossPercentage(List<Purchase> purchases) {
    if (purchases.isEmpty) return 0;
    double purchaseValue = _calculatePurchaseValue(purchases);
    if (purchaseValue == 0) return 0;
    return (_calculateProfitLoss(purchases) / purchaseValue) * 100;
  }

  bool _isProfit(List<Purchase> purchases) {
    return _calculateProfitLoss(purchases) >= 0;
  }

  void _showDateDetails(DateTime date) {
    if (widget.holdingsHidden) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Holdings are currently hidden'),
          backgroundColor: Colors.orange));
      return;
    }

    final purchases = _getPurchasesForDate(date);
    final sales = _getSalesForDate(date);

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                  Text('Purchases:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black)),
                  const SizedBox(height: 8),
                  ...purchases.map((purchase) {
                    double currentValue = purchase.amountBTC * widget.currentBtcPrice;
                    double purchaseValueInSelectedCurrency = _convertCurrency(
                        purchase.totalCashSpent,
                        purchase.cashCurrency,
                        widget.selectedCurrency);
                    bool isIndividualProfit =
                        currentValue >= purchaseValueInSelectedCurrency;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${formatDenomination(purchase.amountBTC, widget.denomination)} @ ${purchase.pricePerBTC.toStringAsFixed(2)} ${currencyToString(purchase.cashCurrency)}',
                              style: TextStyle(
                                  color:
                                  widget.isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          if (purchase.cashCurrency != widget.selectedCurrency)
                            Text(
                                'Converted: ${_convertCurrency(purchase.pricePerBTC, purchase.cashCurrency, widget.selectedCurrency).toStringAsFixed(2)} ${currencyToString(widget.selectedCurrency)}/BTC',
                                style: TextStyle(
                                    color: widget.isDarkMode
                                        ? Colors.orange
                                        : Colors.blue)),
                          if (purchase.cashCurrency != widget.selectedCurrency)
                            const SizedBox(height: 4),
                          Text(
                              'Purchase Value: ${purchaseValueInSelectedCurrency.toStringAsFixed(2)} ${currencyToString(widget.selectedCurrency)}',
                              style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.white70
                                      : Colors.black54)),
                          Text(
                              'Current Value: ${currentValue.toStringAsFixed(2)} ${currencyToString(widget.selectedCurrency)}',
                              style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.white70
                                      : Colors.black54)),
                          Text(
                              'P&L: ${(currentValue - purchaseValueInSelectedCurrency).toStringAsFixed(2)} ${currencyToString(widget.selectedCurrency)}',
                              style: TextStyle(
                                  color: isIndividualProfit ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: widget.isDarkMode
                                        ? Colors.blue[300]
                                        : Colors.blue,
                                    size: 20),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showEditPurchaseDialog(purchase);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: widget.isDarkMode
                                        ? Colors.red[300]
                                        : Colors.red,
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
                  }).toList(),
                  SizedBox(height: 16),
                ],

                if (sales.isNotEmpty) ...[
                  Text('Sales:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                          fontSize: 16)),
                  SizedBox(height: 8),
                  ...sales.map((sale) {
                    double saleValue = sale.amountBTC * sale.price;
                    double saleValueInSelectedCurrency = _convertCurrency(
                        saleValue, sale.originalCurrency, widget.selectedCurrency);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.purple[900]!.withOpacity(0.3)
                            : Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.5), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_circle_down,
                                  color: Colors.purple, size: 16),
                              SizedBox(width: 4),
                              Text('Sale',
                                  style: TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                              '${formatDenomination(sale.amountBTC, widget.denomination)} @ ${sale.price.toStringAsFixed(2)} ${currencyToString(sale.originalCurrency)}',
                              style: TextStyle(
                                  color:
                                  widget.isDarkMode ? Colors.white : Colors.black,
                                  fontSize: 12)),
                          SizedBox(height: 2),
                          Text(
                              'Value: ${saleValueInSelectedCurrency.toStringAsFixed(2)} ${currencyToString(widget.selectedCurrency)}',
                              style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 11)),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: widget.isDarkMode
                                        ? Colors.blue[300]
                                        : Colors.blue,
                                    size: 20),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showEditSaleDialog(sale);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: widget.isDarkMode
                                        ? Colors.red[300]
                                        : Colors.red,
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
                  }).toList(),
                ],

                if (purchases.isEmpty && sales.isEmpty)
                  Text('No transactions on this date',
                      style: TextStyle(
                          color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'))
          ],
        );
      },
    );
  }

  void _showEditPurchaseDialog(Purchase purchase) {
    final TextEditingController amountController = TextEditingController(
      text: widget.denomination == Denomination.BTC
          ? purchase.amountBTC.toString()
          : btcToSatoshis(purchase.amountBTC).toString(),
    );
    final TextEditingController priceController =
    TextEditingController(text: purchase.pricePerBTC.toString());
    DateTime selectedDate = purchase.date;

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                    'Price (${currencyToString(purchase.cashCurrency)}) - Original Currency',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2009, 1, 3),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() {
                      selectedDate = picked;
                    });
                  },
                  child: Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                      style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black)),
                ),
                const SizedBox(height: 16),
                if (purchase.cashCurrency != widget.selectedCurrency)
                  Text(
                    'Price in ${currencyToString(widget.selectedCurrency)}: ${_convertCurrency(purchase.pricePerBTC, purchase.cashCurrency, widget.selectedCurrency).toStringAsFixed(2)}',
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                double newAmount;
                if (widget.denomination == Denomination.BTC) {
                  newAmount = double.tryParse(amountController.text) ?? 0;
                } else {
                  final sats = int.tryParse(amountController.text) ?? 0;
                  newAmount = satoshisToBtc(sats);
                }
                final newPricePerBTC = double.tryParse(priceController.text);
                if (newAmount <= 0 ||
                    newPricePerBTC == null ||
                    newPricePerBTC <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid values')));
                  return;
                }
                final updatedPurchase = Purchase(
                  id: purchase.id,
                  date: selectedDate,
                  amountBTC: newAmount,
                  pricePerBTC: newPricePerBTC,
                  cashCurrency: purchase.cashCurrency,
                );
                widget.onEditPurchase(updatedPurchase);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSaleDialog(Sale sale) {
    final TextEditingController amountController = TextEditingController(
      text: widget.denomination == Denomination.BTC
          ? sale.amountBTC.toString()
          : btcToSatoshis(sale.amountBTC).toString(),
    );
    final TextEditingController priceController =
    TextEditingController(text: sale.price.toString());
    DateTime selectedDate = sale.date;

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                    'Price (${currencyToString(sale.originalCurrency)}) - Original Currency',
                    labelStyle: TextStyle(
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2009, 1, 3),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() {
                      selectedDate = picked;
                    });
                  },
                  child: Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                      style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Price in ${currencyToString(widget.selectedCurrency)}: ${_convertCurrency(sale.price, sale.originalCurrency, widget.selectedCurrency).toStringAsFixed(2)}',
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                double newAmount;
                if (widget.denomination == Denomination.BTC) {
                  newAmount = double.tryParse(amountController.text) ?? 0;
                } else {
                  final sats = int.tryParse(amountController.text) ?? 0;
                  newAmount = satoshisToBtc(sats);
                }
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
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDayHeaders() {
    return ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
      return Expanded(
        child: Center(
          child: Text(day,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
        ),
      );
    }).toList();
  }

  void _showAmountTooltip(DateTime date, List<Purchase> purchases) {
    if (widget.holdingsHidden) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Holdings are currently hidden'),
          duration: const Duration(seconds: 2),
          backgroundColor:
          widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20)));
      return;
    }
    final totalAmount = _getTotalPurchaseAmount(purchases);
    final formattedAmount = formatDenomination(totalAmount, widget.denomination);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
        Text('Total purchase on ${date.day}/${date.month}/${date.year}: $formattedAmount'),
        duration: const Duration(seconds: 2),
        backgroundColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[300],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20)));
  }

  List<Widget> _buildDays() {
    final firstDayOfMonth = DateTime(
        _currentDisplayedMonth.year, _currentDisplayedMonth.month, 1);
    final lastDayOfMonth = DateTime(
        _currentDisplayedMonth.year, _currentDisplayedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday;
    List<Widget> dayWidgets = [];

    for (int i = 0; i < startingWeekday % 7; i++) dayWidgets.add(Container());
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(
          _currentDisplayedMonth.year, _currentDisplayedMonth.month, day);
      final isPurchaseDate = _isPurchaseDate(currentDate);
      final isSaleDate = _isSaleDate(currentDate);
      final purchasesOnDate = _getPurchasesForDate(currentDate);
      final isProfit = _isProfit(purchasesOnDate);
      final isSelected = _selectedDate != null &&
          _selectedDate!.year == currentDate.year &&
          _selectedDate!.month == currentDate.month &&
          _selectedDate!.day == currentDate.day;
      final isToday = currentDate.year == DateTime.now().year &&
          currentDate.month == DateTime.now().month &&
          currentDate.day == DateTime.now().day;
      final isBeforeGenesis = currentDate.isBefore(_genesisBlock);
      final isAfterToday = currentDate.isAfter(DateTime.now());

      final isPureSaleDate = isSaleDate && !isPurchaseDate;

      Color dateColor = Colors.transparent;
      if (isSelected) {
        dateColor = const Color(0xFFF7931A);
      } else if (isPureSaleDate) {
        dateColor = Colors.purple.withOpacity(0.8);
      } else if (isPurchaseDate) {
        dateColor = isProfit
            ? Colors.green.withOpacity(0.8)
            : Colors.red.withOpacity(0.8);
      } else if (isToday) {
        dateColor = widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
      }

      dayWidgets.add(
        Container(
          margin: const EdgeInsets.all(1.0),
          child: GestureDetector(
            onTap: isBeforeGenesis || isAfterToday
                ? null
                : () {
              setState(() {
                _selectedDate = currentDate;
              });
              widget.onDateSelected(currentDate);
              if (isPurchaseDate || isSaleDate) _showDateDetails(currentDate);
            },
            onLongPress: (isPurchaseDate || isSaleDate) &&
                !isBeforeGenesis &&
                !isAfterToday
                ? () => _showAmountTooltip(currentDate, purchasesOnDate)
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width < 400 ? 28 : 32,
                  height: MediaQuery.of(context).size.width < 400 ? 28 : 32,
                  decoration: BoxDecoration(
                    color: dateColor,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFFF7931A), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: MediaQuery.of(context).size.width < 400
                            ? 10
                            : 12,
                        color: isBeforeGenesis || isAfterToday
                            ? Colors.grey
                            : isSelected
                            ? Colors.black
                            : (isPurchaseDate || isPureSaleDate)
                            ? Colors.white
                            : widget.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                if (isSaleDate && isPurchaseDate)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 1,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    while (dayWidgets.length < 42) dayWidgets.add(Container());
    return dayWidgets;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(currentYear - 2009 + 1,
            (i) => 2009 + i);
    final List<String> monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: EdgeInsets.only(bottom: _bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text('Purchase Calendar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? Colors.grey[700] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: widget.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[400]!,
                              width: 1.5),
                        ),
                        child: DropdownButton<int>(
                          value: _currentDisplayedMonth.month,
                          items: List.generate(12, (index) {
                            return DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(monthNames[index],
                                  style: TextStyle(
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            );
                          }).toList(),
                          onChanged: (value) => _selectMonth(value!),
                          dropdownColor:
                          widget.isDarkMode ? Colors.grey[800] : Colors.white,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              size: 24),
                          isExpanded: true,
                          style: TextStyle(
                              color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? Colors.grey[700] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: widget.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[400]!,
                              width: 1.5),
                        ),
                        child: DropdownButton<int>(
                          value: _currentDisplayedMonth.year,
                          items: years.map((int year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString(),
                                  style: TextStyle(
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            );
                          }).toList(),
                          onChanged: (value) => _selectYear(value!),
                          dropdownColor:
                          widget.isDarkMode ? Colors.grey[800] : Colors.white,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              size: 24),
                          isExpanded: true,
                          style: TextStyle(
                              color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: widget.isDarkMode ? Colors.white : Colors.black,
                            size: 24),
                        onPressed: _previousMonth),
                    Text(
                        '${monthNames[_currentDisplayedMonth.month - 1]} ${_currentDisplayedMonth.year}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.isDarkMode ? Colors.white : Colors.black)),
                    IconButton(
                        icon: Icon(Icons.chevron_right,
                            color: widget.isDarkMode ? Colors.white : Colors.black,
                            size: 24),
                        onPressed: _nextMonth),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'DD/MM/YYYY',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: widget.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[400]!,
                              width: 1.5)),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                      labelStyle: TextStyle(
                          color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 14),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleDateInput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Go',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(children: _buildDayHeaders())),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth / 7;
              return Container(
                height: cellSize * 6,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: _buildDays(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}