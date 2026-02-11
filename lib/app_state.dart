// app_state.dart - COMPLETE FIXED VERSION WITH PRECISE CURRENCY CONVERSION
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'constants.dart';

class AppState with ChangeNotifier {
  final StorageService _storageService = StorageService();
  Map<Currency, double> _btcPrices = {
    Currency.USD: 0.0,
    Currency.GBP: 0.0,
    Currency.EUR: 0.0,
    Currency.CAD: 0.0,
    Currency.AUD: 0.0,
    Currency.JPY: 0.0,
    Currency.CNY: 0.0,
  };
  List<Purchase> _purchases = [];
  List<Sale> _sales = [];
  List<PriceDataPoint> _priceHistory = [];
  bool _isRefreshing = false;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTime? _lastUpdated;
  bool _isDarkMode = true;
  Currency _selectedCurrency = Currency.USD;
  Denomination _denomination = Denomination.BTC;
  TimeRange _selectedTimeRange = TimeRange.DAY;
  Currency _favoriteCurrency = Currency.USD;
  Currency _secondaryCurrency = Currency.GBP;
  String _lastError = '';
  String _lastPriceError = '';
  String _lastHistoricalError = '';
  bool _hasPriceError = false;
  bool _hasHistoricalError = false;
  Map<String, List<PriceDataPoint>> _historicalDataCache = {};
  Map<String, DateTime> _historicalDataCacheTimestamps = {};
  bool _holdingsHidden = false;

  // Getters
  Currency get selectedCurrency => _selectedCurrency;
  Denomination get denomination => _denomination;
  TimeRange get selectedTimeRange => _selectedTimeRange;
  Map<Currency, double> get btcPrices => _btcPrices;
  List<Purchase> get purchases => _purchases;
  List<Sale> get sales => _sales;
  List<PriceDataPoint> get priceHistory => _priceHistory;
  bool get isRefreshing => _isRefreshing;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isDarkMode => _isDarkMode;
  String get lastError => _lastError;
  String get lastPriceError => _lastPriceError;
  String get lastHistoricalError => _lastHistoricalError;
  bool get hasPriceError => _hasPriceError;
  bool get hasHistoricalError => _hasHistoricalError;
  Currency get favoriteCurrency => _favoriteCurrency;
  Currency get secondaryCurrency => _secondaryCurrency;
  bool get holdingsHidden => _holdingsHidden;

  // Calculate total BTC (purchases minus sales)
  double get totalBTC => _purchases.fold(0.0, (sum, p) => sum + p.amountBTC) -
      _sales.fold(0.0, (sum, s) => sum + s.amountBTC);

  // Calculate total crypto from purchases only
  double get totalCrypto => _purchases.fold(0.0, (sum, p) => sum + p.amountBTC);

  // FIXED: Total investment in selected currency
  double get totalInvestment {
    return _purchases.fold(0.0, (sum, purchase) {
      // Convert each purchase from its original currency to selected currency
      double purchaseValueInSelectedCurrency = _convertCurrency(
          purchase.totalCashSpent,
          purchase.cashCurrency,
          _selectedCurrency
      );
      return sum + purchaseValueInSelectedCurrency;
    });
  }

  // FIXED: Portfolio value in selected currency
  double get portfolioValue => totalBTC * getBtcPrice(_selectedCurrency);

  // FIXED: Average purchase price in selected currency
  double get averagePrice {
    if (totalCrypto == 0) return 0;

    double totalInvestmentInSelectedCurrency = _purchases.fold(0.0, (sum, purchase) {
      double purchaseValueInSelectedCurrency = _convertCurrency(
          purchase.totalCashSpent,
          purchase.cashCurrency,
          _selectedCurrency
      );
      return sum + purchaseValueInSelectedCurrency;
    });

    return totalInvestmentInSelectedCurrency / totalCrypto;
  }

  // FIXED: Profit/Loss in selected currency
  double get profitLoss {
    double currentValue = portfolioValue;
    double totalInvestmentValue = totalInvestment;

    // FIXED: Sales value in selected currency with proper conversion
    double totalSalesValueInSelectedCurrency = _sales.fold(0.0, (sum, sale) {
      double saleValueInSelectedCurrency = _convertCurrency(
          sale.amountBTC * sale.price,
          sale.originalCurrency,
          _selectedCurrency
      );
      return sum + saleValueInSelectedCurrency;
    });

    return currentValue + totalSalesValueInSelectedCurrency - totalInvestmentValue;
  }

  // FIXED: Profit/Loss percentage
  double get profitLossPercentage {
    double investment = totalInvestment;
    if (investment == 0) return 0;
    return (profitLoss / investment) * 100;
  }

  // FIXED: Get sales value in selected currency
  double get totalSalesValue => _sales.fold(0.0, (sum, sale) {
    double saleValueInSelectedCurrency = _convertCurrency(
        sale.amountBTC * sale.price,
        sale.originalCurrency,
        _selectedCurrency
    );
    return sum + saleValueInSelectedCurrency;
  });

  // NEW: Format sensitive values based on holdings hidden state
  String formatSensitiveValue(double value, {String? currency, bool isBtc = false}) {
    if (_holdingsHidden) {
      if (isBtc) {
        return '**** BTC';
      } else if (currency != null) {
        return '**** $currency';
      }
      return '****';
    }

    if (isBtc) {
      return formatDenomination(value, _denomination);
    } else if (currency != null) {
      return '${_formatNumber(value)} $currency';
    }
    return _formatNumber(value);
  }

  // NEW: Format sensitive percentage
  String formatSensitivePercentage(double value) {
    if (_holdingsHidden) return '****%';
    return '${value.toStringAsFixed(2)}%';
  }

  // NEW: Toggle holdings visibility with persistence
  void toggleHoldingsVisibility() {
    _holdingsHidden = !_holdingsHidden;
    _saveHoldingsHiddenPreference();
    notifyListeners();
  }

  // Helper method to format numbers
  String _formatNumber(double number) {
    if (number == 0) return '0';
    return NumberFormat('#,###.##').format(number);
  }

  AppState() {
    print('AppState initialized - starting data load');
    _loadInitialData();
    _loadThemePreference();
    _loadDenominationPreference();
  }

  Future<void> reloadAllData() async {
    try {
      print('Reloading all data...');
      await _loadPurchases();
      await _loadSales();
      await _loadThemePreference();
      await _loadDenominationPreference();
      await _loadCurrencyPreferences();
      await _loadHoldingsHiddenPreference();
      await fetchBtcPrices();
      await fetchHistoricalData();
      print('Data reload completed successfully');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to reload data: ${e.toString()}';
      print('Error reloading data: $e');
      notifyListeners();
    }
  }

  Future<void> retryFailedOperations() async {
    if (_hasPriceError) await fetchBtcPrices();
    if (_hasHistoricalError) await fetchHistoricalData();
  }

  double getBtcPrice(Currency currency) => _btcPrices[currency] ?? 0.0;

  String formatBtcAmount(double btcAmount) {
    if (_holdingsHidden) return '****';
    return _denomination == Denomination.BTC
        ? '${btcAmount.toStringAsFixed(8)} BTC'
        : '${btcToSatoshis(btcAmount).toString()} sats';
  }

  Future<void> _loadThemePreference() async {
    final box = Hive.box('preferences');
    _isDarkMode = box.get('isDarkMode', defaultValue: true);
    notifyListeners();
  }

  Future<void> _loadDenominationPreference() async {
    final box = Hive.box('preferences');
    int index = box.get('denomination', defaultValue: 0);
    _denomination = Denomination.values[index];
    notifyListeners();
  }

  // NEW: Load holdings hidden preference
  Future<void> _loadHoldingsHiddenPreference() async {
    final box = Hive.box('preferences');
    _holdingsHidden = box.get('holdingsHidden', defaultValue: false);
    notifyListeners();
  }

  // NEW: Save holdings hidden preference
  Future<void> _saveHoldingsHiddenPreference() async {
    final box = Hive.box('preferences');
    await box.put('holdingsHidden', _holdingsHidden);
  }

  Future<void> _loadInitialData() async {
    try {
      print('Loading initial data...');
      await _loadPurchases();
      await _loadSales();
      await _loadCurrencyPreferences();
      await _loadHoldingsHiddenPreference();
      await fetchBtcPrices();
      await fetchHistoricalData();
      _isLoading = false;
      print('Initial data load completed');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _lastError = 'Failed to load initial data: ${e.toString()}';
      print('Error loading initial data: $e');
      notifyListeners();
    }
  }

  Future<void> _loadPurchases() async {
    try {
      _purchases = await _storageService.loadPurchases();
      print('Loaded ${_purchases.length} purchases in AppState');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to load purchases: ${e.toString()}';
      print('Error loading purchases: $e');
      notifyListeners();
    }
  }

  Future<void> _loadSales() async {
    try {
      _sales = await _storageService.loadSales();
      print('Loaded ${_sales.length} sales in AppState');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to load sales: ${e.toString()}';
      print('Error loading sales: $e');
      notifyListeners();
    }
  }

  Future<void> _savePurchases() async {
    try {
      await _storageService.savePurchases(_purchases);
    } catch (e) {
      _lastError = 'Failed to save purchases: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _saveSales() async {
    try {
      await _storageService.saveSales(_sales);
    } catch (e) {
      _lastError = 'Failed to save sales: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> fetchBtcPrices() async {
    if (_isRefreshing) return;
    if (_lastUpdated != null && DateTime.now().difference(_lastUpdated!) < const Duration(minutes: 1)) return;

    try {
      _isRefreshing = true;
      _hasPriceError = false;
      _lastPriceError = '';
      _lastError = '';
      notifyListeners();

      final prices = await ApiService.fetchBtcPrices();
      _btcPrices = {
        Currency.USD: prices['usd'] ?? 0,
        Currency.GBP: prices['gbp'] ?? 0,
        Currency.EUR: prices['eur'] ?? 0,
        Currency.CAD: prices['cad'] ?? 0,
        Currency.AUD: prices['aud'] ?? 0,
        Currency.JPY: prices['jpy'] ?? 0,
        Currency.CNY: prices['cny'] ?? 0,
      };
      _lastUpdated = DateTime.now();
    } on RateLimitException {
      _hasPriceError = true;
      _lastPriceError = 'Too many requests. Please wait a minute.';
    } on NetworkException {
      _hasPriceError = true;
      _lastPriceError = 'Network issue';
    } on ApiTimeoutException {
      _hasPriceError = true;
      _lastPriceError = 'Request timed out';
    } on ApiException {
      _hasPriceError = true;
      _lastPriceError = 'API error';
    } catch (e) {
      _hasPriceError = true;
      _lastPriceError = 'Unexpected error';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistoricalData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _hasHistoricalError = false;
    _lastHistoricalError = '';
    notifyListeners();

    try {
      final days = _getDaysForTimeRange(_selectedTimeRange);
      final currency = currencyToString(_selectedCurrency).toLowerCase();
      final cacheKey = '$currency-$days';
      final now = DateTime.now();

      if (_historicalDataCache.containsKey(cacheKey) &&
          _historicalDataCacheTimestamps.containsKey(cacheKey) &&
          now.difference(_historicalDataCacheTimestamps[cacheKey]!) < Duration(minutes: 5)) {
        _priceHistory = _historicalDataCache[cacheKey]!;
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      List<PriceDataPoint> priceData = await ApiService.fetchHistoricalData(currency, days);
      _historicalDataCache[cacheKey] = priceData;
      _historicalDataCacheTimestamps[cacheKey] = DateTime.now();
      _priceHistory = priceData;
    } on RateLimitException {
      _hasHistoricalError = true;
      _lastHistoricalError = 'Rate limited';
      final currency = currencyToString(_selectedCurrency).toLowerCase();
      final days = _getDaysForTimeRange(_selectedTimeRange);
      final cacheKey = '$currency-$days';
      if (_historicalDataCache.containsKey(cacheKey)) {
        _priceHistory = _historicalDataCache[cacheKey]!;
        _hasHistoricalError = false;
      }
    } on NetworkException {
      _hasHistoricalError = true;
      _lastHistoricalError = 'Network issue';
    } on ApiTimeoutException {
      _hasHistoricalError = true;
      _lastHistoricalError = 'Request timed out';
    } catch (e) {
      _hasHistoricalError = true;
      _lastHistoricalError = 'Unexpected error';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  int _getDaysForTimeRange(TimeRange timeRange) {
    switch (timeRange) {
      case TimeRange.DAY: return 1;
      case TimeRange.WEEK: return 7;
      case TimeRange.MONTH: return 30;
      case TimeRange.YEAR: return 365;
    }
  }

  void addPurchase(double amountBTC, double pricePerBTC) {
    try {
      final newPurchase = Purchase(
        date: _selectedDate,
        amountBTC: amountBTC,
        pricePerBTC: pricePerBTC,
        cashCurrency: _selectedCurrency,
      );
      _purchases = [..._purchases, newPurchase];
      _savePurchases();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to add purchase: ${e.toString()}';
      notifyListeners();
    }
  }

  // FIXED: Add sale with proper currency handling
  void addSale(double amount, double manualPrice) {
    try {
      if (amount > totalBTC) {
        _lastError = 'Not enough BTC to sell';
        notifyListeners();
        return;
      }

      final newSale = Sale(
        date: _selectedDate,
        amountBTC: amount,
        price: manualPrice,
        originalCurrency: _selectedCurrency, // Store the actual selected currency
      );

      _sales = [..._sales, newSale];
      _saveSales();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to add sale: ${e.toString()}';
      notifyListeners();
    }
  }

  void deletePurchase(String id) {
    try {
      _purchases = _purchases.where((p) => p.id != id).toList();
      _savePurchases();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to delete purchase: ${e.toString()}';
      notifyListeners();
    }
  }

  void deleteSale(String id) {
    try {
      _sales = _sales.where((s) => s.id != id).toList();
      _saveSales();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to delete sale: ${e.toString()}';
      notifyListeners();
    }
  }

  void setSelectedCurrency(Currency currency) {
    _selectedCurrency = currency;
    fetchHistoricalData();
    notifyListeners();
  }

  void setDenomination(Denomination denomination) {
    _denomination = denomination;
    _storageService.saveDenominationPreference(denomination);
    notifyListeners();
  }

  void setSelectedTimeRange(TimeRange timeRange) {
    _selectedTimeRange = timeRange;
    fetchHistoricalData();
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void toggleTheme(bool isDarkMode) {
    try {
      _isDarkMode = isDarkMode;
      Hive.box('preferences').put('isDarkMode', isDarkMode);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to save theme preference: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _loadCurrencyPreferences() async {
    final box = Hive.box('preferences');
    _favoriteCurrency = Currency.values[box.get('favoriteCurrency', defaultValue: 0)];
    _secondaryCurrency = Currency.values[box.get('secondaryCurrency', defaultValue: 1)];
    _selectedCurrency = _favoriteCurrency;
    notifyListeners();
  }

  Future<void> setCurrencyPreferences(Currency favorite, Currency secondary) async {
    _favoriteCurrency = favorite;
    _secondaryCurrency = secondary;
    _selectedCurrency = favorite;
    await _storageService.saveCurrencyPreferences(favorite.index, secondary.index);
    notifyListeners();
  }

  void updatePurchase(Purchase updatedPurchase) {
    try {
      final index = _purchases.indexWhere((p) => p.id == updatedPurchase.id);
      if (index != -1) {
        _purchases = [
          ..._purchases.sublist(0, index),
          updatedPurchase,
          ..._purchases.sublist(index + 1)
        ];
        _savePurchases();
        notifyListeners();
      }
    } catch (e) {
      _lastError = 'Failed to update purchase: ${e.toString()}';
      notifyListeners();
    }
  }

  void updateSale(Sale updatedSale) {
    try {
      final index = _sales.indexWhere((s) => s.id == updatedSale.id);
      if (index != -1) {
        _sales = [
          ..._sales.sublist(0, index),
          updatedSale,
          ..._sales.sublist(index + 1)
        ];
        _saveSales();
        notifyListeners();
      }
    } catch (e) {
      _lastError = 'Failed to update sale: ${e.toString()}';
      notifyListeners();
    }
  }

  // FIXED: Proper currency conversion using BTC as intermediary
  double _convertCurrency(double amount, Currency from, Currency to) {
    // Return original amount if currencies are the same
    if (from == to) return amount;

    final btcPriceFrom = _btcPrices[from] ?? 0.0;
    final btcPriceTo = _btcPrices[to] ?? 0.0;

    if (btcPriceFrom == 0 || btcPriceTo == 0) return amount;

    // Convert: amount (in 'from' currency) -> BTC -> amount (in 'to' currency)
    double amountInBTC = amount / btcPriceFrom;
    return amountInBTC * btcPriceTo;
  }

  // Helper method to get purchase value in selected currency
  double getPurchaseValueInSelectedCurrency(Purchase purchase) {
    return _convertCurrency(
        purchase.totalCashSpent,
        purchase.cashCurrency,
        _selectedCurrency
    );
  }

  // Helper method to get purchase price per BTC in selected currency
  double getPurchasePricePerBTCInSelectedCurrency(Purchase purchase) {
    return _convertCurrency(
        purchase.pricePerBTC,
        purchase.cashCurrency,
        _selectedCurrency
    );
  }

  // Helper method to get sale value in selected currency
  double getSaleValueInSelectedCurrency(Sale sale) {
    return _convertCurrency(
        sale.amountBTC * sale.price,
        sale.originalCurrency,
        _selectedCurrency
    );
  }
}