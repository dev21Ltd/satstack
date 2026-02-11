// home_screen.dart - COMPACT VERSION WITH COMPACT TRANSACTIONS TAB
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:fl_chart/fl_chart.dart';
import 'purchase_calendar.dart';
import 'charts.dart';
import 'app_state.dart';
import 'constants.dart';
import 'widgets.dart';
import 'services.dart';
import 'donation_widget.dart';
import 'import_export_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late TabController _tabController;
  Timer? _autoRefreshTimer;
  bool _isAppActive = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isPurchaseMode = true;
  int _currentTabIndex = 0;
  double _bottomPadding = 0;
  late AnimationController _successAnimationController;
  late AnimationController _importAnimationController;
  late AnimationController _saveAnimationController;
  final RefreshController _priceRefreshController = RefreshController(initialRefresh: false);
  final RefreshController _portfolioRefreshController = RefreshController(initialRefresh: false);

  @override void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _startAutoRefresh();
    _setupConnectivityMonitoring();
    WidgetsBinding.instance.addObserver(this);
    _successAnimationController = AnimationController(vsync: this, duration: 2500.ms);
    _importAnimationController = AnimationController(vsync: this, duration: 2500.ms);
    _saveAnimationController = AnimationController(vsync: this, duration: 2500.ms);
  }

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBottomPadding();
  }

  void _calculateBottomPadding() {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    setState(() { _bottomPadding = bottomPadding > 0 ? bottomPadding : 16; });
  }

  @override void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    _tabController.dispose();
    _autoRefreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _priceRefreshController.dispose();
    _portfolioRefreshController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _successAnimationController.dispose();
    _importAnimationController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() { _currentTabIndex = _tabController.index; });
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(5.minutes, (timer) {
      if (_isAppActive) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.fetchBtcPrices();
      }
    });
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _isOnline = result != ConnectivityResult.none);
      if (_isOnline) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.fetchBtcPrices();
      }
    });
  }

  void _onPriceRefresh() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try { await appState.fetchBtcPrices(); _priceRefreshController.refreshCompleted(); }
    catch (e) { _priceRefreshController.refreshFailed(); }
  }

  void _onPortfolioRefresh() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try { await appState.fetchBtcPrices(); _portfolioRefreshController.refreshCompleted(); }
    catch (e) { _portfolioRefreshController.refreshFailed(); }
  }

  void _showCurrencySettings(AppState appState) {
    showDialog(context: context, builder: (context) => CurrencySettingsDialog(
      favoriteCurrency: appState.favoriteCurrency, secondaryCurrency: appState.secondaryCurrency,
      denomination: appState.denomination, onSave: (favorite, secondary, denomination) {
      appState.setCurrencyPreferences(favorite, secondary); appState.setDenomination(denomination);
    }, isDarkMode: appState.isDarkMode,
    ));
  }

  void _showSecuritySettings(AppState appState) {
    showDialog(context: context, builder: (context) => SecuritySettingsDialog(isDarkMode: appState.isDarkMode));
  }

  void _showImportExportDialog() {
    final appState = Provider.of<AppState>(context, listen: false);
    showDialog(context: context, builder: (context) => ImportExportDialog(
      isDarkMode: appState.isDarkMode, onSavePdfReport: _savePdfReport, onSaveCsvReport: _saveCsvReport,
      onSaveJsonBackup: _saveJsonBackup, onShareFile: _shareFile, onImportFromFile: _importFromFile,
      onShowJsonImportDialog: _showJsonImportDialog, onOperationComplete: _handleOperationComplete,
    ));
  }

  void _handleOperationComplete(String operationType, String filePath) {
    switch (operationType) {
      case 'PDF Export': _showSuccessAnimation('PDF Report Saved!'); break;
      case 'CSV Export': _showSuccessAnimation('CSV Report Saved!'); break;
      case 'JSON Export': _showSuccessAnimation('JSON Backup Saved!'); break;
      case 'CSV Import': case 'JSON Import': _showImportAnimation('Data Imported!'); break;
    }
  }

  void _showSuccessAnimation(String message) {
    _successAnimationController.reset(); _successAnimationController.forward();
    _showAnimationDialog(SuccessAnimationOverlay(
      message: message, animationController: _successAnimationController, isDarkMode: Provider.of<AppState>(context, listen: false).isDarkMode,
    ));
  }

  void _showSaveAnimation(String message) {
    _saveAnimationController.reset(); _saveAnimationController.forward();
    _showAnimationDialog(SaveAnimationOverlay(
      message: message, animationController: _saveAnimationController, isDarkMode: Provider.of<AppState>(context, listen: false).isDarkMode,
    ));
  }

  void _showImportAnimation(String message) {
    _importAnimationController.reset(); _importAnimationController.forward();
    _showAnimationDialog(ImportAnimationOverlay(
      message: message, animationController: _importAnimationController, isDarkMode: Provider.of<AppState>(context, listen: false).isDarkMode,
    ));
  }

  void _showAnimationDialog(Widget dialog) {
    showDialog(context: context, barrierColor: Colors.transparent, barrierDismissible: false, builder: (context) => dialog);
    Future.delayed(3500.ms, () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  void _savePdfReport(BuildContext context) async {
    try {
      final storageService = StorageService();
      await storageService.exportData(format: 'pdf', shareAfterSave: false);
      await Future.delayed(100.ms);
      if (mounted) _showSuccessAnimation('PDF Report Saved!');
    } catch (e) {
      await Future.delayed(100.ms);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _saveCsvReport(BuildContext context) async {
    try {
      final storageService = StorageService();
      await storageService.exportData(format: 'csv', shareAfterSave: false);
      await Future.delayed(100.ms);
      if (mounted) _showSuccessAnimation('CSV Report Saved!');
    } catch (e) {
      await Future.delayed(100.ms);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _saveJsonBackup(BuildContext context) async {
    try {
      final storageService = StorageService();
      await storageService.exportData(format: 'json', shareAfterSave: false);
      await Future.delayed(100.ms);
      if (mounted) _showSuccessAnimation('JSON Backup Saved!');
    } catch (e) {
      await Future.delayed(100.ms);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _shareFile(BuildContext context, String format) async {
    try {
      final storageService = StorageService();
      await storageService.exportData(format: format, shareAfterSave: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  void _importFromFile(BuildContext context, String format) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final storageService = StorageService();
      print('Starting import with format: $format');
      await storageService.importData(format: format);
      print('Import completed, reloading app state...');
      await appState.reloadAllData();
      print('App state reloaded');
      _showImportAnimation('${format.toUpperCase()} Imported Successfully!');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Successfully imported ${appState.purchases.length} purchases and ${appState.sales.length} sales'),
        backgroundColor: Colors.green, duration: Duration(seconds: 4),
      ));
    } catch (e) {
      print('Import error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Import failed: ${e.toString()}'), backgroundColor: Colors.red, duration: Duration(seconds: 5),
      ));
    }
  }

  void _showJsonImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Paste JSON Data'),
      content: TextField(controller: controller, maxLines: 10, decoration: const InputDecoration(hintText: 'Paste exported JSON data here', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          try {
            final appState = Provider.of<AppState>(context, listen: false);
            final storageService = StorageService();
            await storageService.importDataFromJsonString(controller.text);
            await appState.reloadAllData();
            Navigator.pop(context);
            _showImportAnimation('JSON Imported Successfully!');
          } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: ${e.toString()}'))); }
        }, child: const Text('Import')),
      ],
    ));
  }

  void _addTransaction(AppState appState) {
    final amountText = _amountController.text.trim();
    final manualPrice = double.tryParse(_priceController.text.trim());
    double amountBTC;
    if (appState.denomination == Denomination.BTC) {
      amountBTC = double.tryParse(amountText) ?? 0;
    } else {
      final sats = int.tryParse(amountText.replaceAll(',', '')) ?? 0;
      amountBTC = satoshisToBtc(sats);
    }
    if (amountBTC <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid BTC amount')));
      return;
    }
    if (manualPrice == null || manualPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid price in ${currencyToString(appState.selectedCurrency)}')));
      return;
    }
    if (_isPurchaseMode) {
      appState.addPurchase(amountBTC, manualPrice);
    } else {
      if (amountBTC > appState.totalBTC) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough BTC to sell. Available: ${appState.formatBtcAmount(appState.totalBTC)}')));
        return;
      }
      appState.addSale(amountBTC, manualPrice);
    }
    _amountController.clear(); _priceController.clear();
  }

  Future<void> _pickDate(AppState appState) async {
    final picked = await showDatePicker(context: context, initialDate: appState.selectedDate, firstDate: DateTime(2010), lastDate: DateTime.now(),
        builder: (c, child) => Theme(
          data: appState.isDarkMode ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFFF7931A), onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
            dialogBackgroundColor: const Color(0xFF121212),
          ) : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: const Color(0xFFF7931A), onPrimary: Colors.black, surface: Colors.grey[200]!, onSurface: Colors.black),
            dialogBackgroundColor: Colors.grey[100],
          ), child: child!,
        ));
    if (picked != null && picked != appState.selectedDate) {
      appState.setSelectedDate(picked);
    }
  }

  String _formatUKDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0'), month = d.month.toString().padLeft(2, '0'), year = d.year.toString();
    return '$day/$month/$year';
  }

  String _formatNumber(double number) {
    if (number == 0) return '0';
    return NumberFormat('#,###.##').format(number);
  }

  // Helper method to convert currency using BTC as intermediary
  double _convertCurrency(double amount, Currency from, Currency to, Map<Currency, double> btcPrices) {
    if (from == to) return amount;

    final btcPriceFrom = btcPrices[from] ?? 0.0;
    final btcPriceTo = btcPrices[to] ?? 0.0;

    if (btcPriceFrom == 0 || btcPriceTo == 0) return amount;

    // Convert: amount (in 'from' currency) -> BTC -> amount (in 'to' currency)
    double amountInBTC = amount / btcPriceFrom;
    return amountInBTC * btcPriceTo;
  }

  @override Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    if (appState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(appState, isSmallScreen), centerTitle: true),
        body: Center(child: CircularProgressIndicator(color: const Color(0xFFF7931A))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(appState, isSmallScreen), centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.favorite, color: const Color(0xFFF7931A)), onPressed: () => DonationWidget.showDonationDialog(context, appState.isDarkMode), tooltip: 'Support Development'),
          IconButton(icon: Icon(appState.holdingsHidden ? Icons.visibility_off : Icons.visibility), onPressed: () => appState.toggleHoldingsVisibility(), tooltip: appState.holdingsHidden ? 'Show Holdings' : 'Hide Holdings'),
          IconButton(icon: const Icon(Icons.import_export), onPressed: _showImportExportDialog),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings), onSelected: (value) {
            if (value == 'currency') _showCurrencySettings(appState);
            if (value == 'security') _showSecuritySettings(appState);
          }, itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(value: 'currency', child: Text('Currency Settings')),
            const PopupMenuItem<String>(value: 'security', child: Text('Security Settings')),
          ],
          ),
          IconButton(icon: Icon(appState.isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: () => appState.toggleTheme(!appState.isDarkMode)),
        ],
      ),
      body: Padding(padding: EdgeInsets.only(bottom: bottomPadding), child: Column(children: [
        Container(decoration: BoxDecoration(color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))]),
          child: Column(children: [
            Container(height: 1, color: appState.isDarkMode ? Colors.grey[800] : Colors.grey[300]),
            TabBar(controller: _tabController, indicator: const BoxDecoration(), labelColor: const Color(0xFFF7931A), unselectedLabelColor: appState.isDarkMode ? Colors.white54 : Colors.black54,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmallScreen ? 12 : 14), tabs: const [Tab(text: 'Overview'), Tab(text: 'Portfolio'), Tab(text: 'Transactions')],
            ),
          ]),
        ),
        Expanded(child: TabBarView(controller: _tabController, children: [_buildOverviewTab(appState), _buildPortfolioTab(appState), _buildTransactionsTabCompact(appState)])),
      ])),
    );
  }

  Widget _buildAppBarTitle(AppState appState, bool isSmallScreen) {
    return Container(width: double.infinity, child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      FaIcon(FontAwesomeIcons.bitcoin, color: const Color(0xFFF7931A), size: isSmallScreen ? 20 : 22),
      SizedBox(width: isSmallScreen ? 6 : 8), Text('SatStack', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, color: appState.isDarkMode ? Colors.white : Colors.black)),
    ]));
  }

  Widget _buildOverviewTab(AppState appState) {
    return SmartRefresher(controller: _priceRefreshController, onRefresh: _onPriceRefresh,
      header: WaterDropHeader(waterDropColor: const Color(0xFFF7931A), complete: Icon(Icons.check, color: const Color(0xFFF7931A)), idleIcon: Icon(Icons.arrow_downward, color: appState.isDarkMode ? Colors.white54 : Colors.black54)),
      child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _buildLastUpdated(appState),
        CompactCurrencyDisplay(favoriteCurrency: appState.favoriteCurrency, secondaryCurrency: appState.secondaryCurrency, selectedCurrency: appState.selectedCurrency,
            prices: appState.btcPrices, onCurrencyChanged: (currency) => appState.setSelectedCurrency(currency), onSettingsPressed: () => _showCurrencySettings(appState),
            isRefreshing: appState.isRefreshing, isDarkMode: appState.isDarkMode),
        const SizedBox(height: 16),
        PortfolioChart(key: ValueKey('portfolio_chart_${appState.selectedCurrency}_${appState.purchases.length}_${appState.holdingsHidden}'),
            purchases: appState.purchases,
            sales: appState.sales,
            isDarkMode: appState.isDarkMode, currentBtcPrice: appState.getBtcPrice(appState.selectedCurrency), currency: appState.selectedCurrency, portfolioValue: appState.portfolioValue,
            totalInvestment: appState.totalInvestment, profitLoss: appState.profitLoss, profitLossPercentage: appState.profitLossPercentage, onEditPurchase: (updatedPurchase) => appState.updatePurchase(updatedPurchase),
            onDeletePurchase: (purchaseToDelete) => appState.deletePurchase(purchaseToDelete.id),
            onEditSale: (updatedSale) => appState.updateSale(updatedSale),
            onDeleteSale: (saleToDelete) => appState.deleteSale(saleToDelete.id),
            denomination: appState.denomination, btcPrices: appState.btcPrices, holdingsHidden: appState.holdingsHidden),
      ]))).animate(delay: 100.ms).slideX(duration: 300.ms, curve: Curves.easeOut, begin: _currentTabIndex == 0 ? -0.1 : 0.1).fadeIn(),
    );
  }

  Widget _buildPortfolioTab(AppState appState) {
    return SmartRefresher(controller: _portfolioRefreshController, onRefresh: _onPortfolioRefresh,
      header: WaterDropHeader(waterDropColor: const Color(0xFFF7931A), complete: Icon(Icons.check, color: const Color(0xFFF7931A)), idleIcon: Icon(Icons.arrow_downward, color: appState.isDarkMode ? Colors.white54 : Colors.black54)),
      child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLastUpdated(appState),
        CompactCurrencyDisplay(favoriteCurrency: appState.favoriteCurrency, secondaryCurrency: appState.secondaryCurrency, selectedCurrency: appState.selectedCurrency,
            prices: appState.btcPrices, onCurrencyChanged: (currency) => appState.setSelectedCurrency(currency), onSettingsPressed: () => _showCurrencySettings(appState),
            isRefreshing: appState.isRefreshing, isDarkMode: appState.isDarkMode),
        const SizedBox(height: 16), Text('Portfolio Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: appState.isDarkMode ? Colors.white : Colors.black)),
        const SizedBox(height: 16), _buildPortfolioGrid(appState), const SizedBox(height: 16), _buildPortfolioDetails(appState),
        const SizedBox(height: 16), _buildPortfolioAllocationChart(appState), const SizedBox(height: 16), _buildPerformanceMetrics(appState),
      ]))).animate(delay: 100.ms).slideX(duration: 300.ms, curve: Curves.easeOut, begin: _currentTabIndex == 1 ? -0.1 : 0.1).fadeIn(),
    );
  }

  // COMPACT TRANSACTIONS TAB
  Widget _buildTransactionsTabCompact(AppState appState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLastUpdated(appState),

          // BTC live price like other tabs
          CompactCurrencyDisplay(
            favoriteCurrency: appState.favoriteCurrency,
            secondaryCurrency: appState.secondaryCurrency,
            selectedCurrency: appState.selectedCurrency,
            prices: appState.btcPrices,
            onCurrencyChanged: (currency) => appState.setSelectedCurrency(currency),
            onSettingsPressed: () => _showCurrencySettings(appState),
            isRefreshing: appState.isRefreshing,
            isDarkMode: appState.isDarkMode,
          ),

          const SizedBox(height: 16),

          // Transaction type toggle with proper text
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isPurchaseMode = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPurchaseMode ? Colors.green : Colors.transparent,
                      foregroundColor: _isPurchaseMode ? Colors.white : (appState.isDarkMode ? Colors.white70 : Colors.black54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _isPurchaseMode ? Colors.green : (appState.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                          width: 2,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 18),
                        const SizedBox(width: 6),
                        Text('Buy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isPurchaseMode = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isPurchaseMode ? Colors.red : Colors.transparent,
                      foregroundColor: !_isPurchaseMode ? Colors.white : (appState.isDarkMode ? Colors.white70 : Colors.black54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: !_isPurchaseMode ? Colors.red : (appState.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                          width: 2,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart, size: 18),
                        const SizedBox(width: 6),
                        Text('Sell', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Compact transaction form
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPurchaseMode ? 'Add New Purchase' : 'Add New Sale',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appState.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // Amount and Price fields
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appState.denomination == Denomination.BTC ? 'BTC Amount' : 'Sats Amount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _amountController,
                            keyboardType: appState.denomination == Denomination.BTC
                                ? const TextInputType.numberWithOptions(decimal: true)
                                : TextInputType.number,
                            inputFormatters: appState.denomination == Denomination.SATS
                                ? [ThousandsSeparatorInputFormatter()]
                                : [],
                            decoration: InputDecoration(
                              hintText: appState.denomination == Denomination.BTC ? '0.000000' : '0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: appState.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: appState.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: appState.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price per BTC (${currencyToString(appState.selectedCurrency)})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: appState.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              filled: true,
                              fillColor: appState.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: appState.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Date and Add button row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            onPressed: () => _pickDate(appState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF7931A), // Bitcoin orange
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _formatUKDate(appState.selectedDate),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            onPressed: () => _addTransaction(appState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPurchaseMode ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: Icon(
                              _isPurchaseMode ? Icons.add_shopping_cart : Icons.remove_shopping_cart,
                              size: 18,
                            ),
                            label: Text(
                              _isPurchaseMode ? 'Add Purchase' : 'Add Sale',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Calendar section - simplified without title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PurchaseCalendar widget directly without title
                PurchaseCalendar(
                  purchases: appState.purchases,
                  sales: appState.sales,
                  onDateSelected: (date) => appState.setSelectedDate(date),
                  isDarkMode: appState.isDarkMode,
                  selectedDate: appState.selectedDate,
                  currentBtcPrice: appState.getBtcPrice(appState.selectedCurrency),
                  selectedCurrency: appState.selectedCurrency,
                  onEditPurchase: (updatedPurchase) => appState.updatePurchase(updatedPurchase),
                  onDeletePurchase: (purchaseToDelete) => appState.deletePurchase(purchaseToDelete.id),
                  onEditSale: (updatedSale) => appState.updateSale(updatedSale),
                  onDeleteSale: (saleToDelete) => appState.deleteSale(saleToDelete.id),
                  denomination: appState.denomination,
                  btcPrices: appState.btcPrices,
                  holdingsHidden: appState.holdingsHidden,
                ),
              ],
            ),
          ),

          // Quick stats
          if (appState.purchases.isNotEmpty || appState.sales.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        'Total Purchases',
                        style: TextStyle(
                          fontSize: 11,
                          color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        appState.purchases.length.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appState.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: appState.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        'Total BTC',
                        style: TextStyle(
                          fontSize: 11,
                          color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        appState.holdingsHidden ? '****' : appState.formatBtcAmount(appState.totalCrypto),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appState.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: appState.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        'Total Sales',
                        style: TextStyle(
                          fontSize: 11,
                          color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        appState.sales.length.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: 100.ms).slideX(duration: 300.ms, curve: Curves.easeOut, begin: _currentTabIndex == 1 ? -0.1 : 0.1).fadeIn();
  }

  Widget _buildLastUpdated(AppState appState) {
    String errorMessage = '';
    if (!_isOnline) errorMessage = 'No internet connection';
    else if (appState.hasPriceError) errorMessage = appState.lastPriceError;
    if (errorMessage.isNotEmpty) return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: Colors.orange, size: 16), const SizedBox(width: 4),
      Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center, maxLines: 2)),
    ]));
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Center(child: Text(
      appState.lastUpdated == null ? 'Prices loading...' : 'Updated: ${appState.lastUpdated!.hour.toString().padLeft(2, '0')}:${appState.lastUpdated!.minute.toString().padLeft(2, '0')}',
      style: TextStyle(color: appState.isRefreshing ? const Color(0xFFF7931A) : Colors.grey, fontSize: 12),
    )));
  }

  Widget _buildPortfolioGrid(AppState appState) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    if (screenWidth < 600) return GridView.count(crossAxisCount: 2, childAspectRatio: isSmallScreen ? 1.1 : 1.2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(isSmallScreen ? 8 : 12), mainAxisSpacing: isSmallScreen ? 8 : 12, crossAxisSpacing: isSmallScreen ? 8 : 12, children: [
          _buildPortfolioCard(context: context, title: 'BTC Holdings', value: appState.formatBtcAmount(appState.totalCrypto), subtitle: 'Total Bitcoin', icon: Icons.account_balance_wallet,
              isDarkMode: appState.isDarkMode, valueColor: const Color(0xFFF7931A), appState: appState),
          _buildPortfolioCard(context: context, title: 'Total Investment', value: appState.totalInvestment == 0 ? '-' : appState.formatSensitiveValue(appState.totalInvestment, currency: currencyToString(appState.selectedCurrency)),
              subtitle: 'Total Cash Spent', icon: Icons.attach_money, isDarkMode: appState.isDarkMode, valueColor: appState.isDarkMode ? Colors.white : Colors.black, appState: appState),
          _buildPortfolioCard(context: context, title: 'Current Value', value: appState.portfolioValue == 0 ? '-' : appState.formatSensitiveValue(appState.portfolioValue, currency: currencyToString(appState.selectedCurrency)),
              subtitle: 'Portfolio Value', icon: Icons.trending_up, isDarkMode: appState.isDarkMode, valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red, appState: appState),
          _buildPortfolioCard(context: context, title: 'P&L', value: appState.formatSensitiveValue(appState.profitLoss, currency: currencyToString(appState.selectedCurrency)),
              subtitle: appState.formatSensitivePercentage(appState.profitLossPercentage), icon: Icons.bar_chart, isDarkMode: appState.isDarkMode,
              valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red, appState: appState),
        ]);
    else return SizedBox(height: 140, child: ListView(scrollDirection: Axis.horizontal, children: [
      SizedBox(width: isSmallScreen ? 8 : 16), _buildPortfolioCard(context: context, title: 'BTC Holdings', value: appState.formatBtcAmount(appState.totalCrypto), subtitle: 'Total Bitcoin', icon: Icons.account_balance_wallet,
          isDarkMode: appState.isDarkMode, valueColor: const Color(0xFFF7931A), appState: appState),
      SizedBox(width: isSmallScreen ? 8 : 12), _buildPortfolioCard(context: context, title: 'Total Investment', value: appState.totalInvestment == 0 ? '-' : appState.formatSensitiveValue(appState.totalInvestment, currency: currencyToString(appState.selectedCurrency)),
          subtitle: 'Total Cash Spent', icon: Icons.attach_money, isDarkMode: appState.isDarkMode, valueColor: appState.isDarkMode ? Colors.white : Colors.black, appState: appState),
      SizedBox(width: isSmallScreen ? 8 : 12), _buildPortfolioCard(context: context, title: 'Current Value', value: appState.portfolioValue == 0 ? '-' : appState.formatSensitiveValue(appState.portfolioValue, currency: currencyToString(appState.selectedCurrency)),
          subtitle: 'Portfolio Value', icon: Icons.trending_up, isDarkMode: appState.isDarkMode, valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red, appState: appState),
      SizedBox(width: isSmallScreen ? 8 : 12), _buildPortfolioCard(context: context, title: 'P&L', value: appState.formatSensitiveValue(appState.profitLoss, currency: currencyToString(appState.selectedCurrency)),
          subtitle: appState.formatSensitivePercentage(appState.profitLossPercentage), icon: Icons.bar_chart, isDarkMode: appState.isDarkMode,
          valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red, appState: appState),
      SizedBox(width: isSmallScreen ? 8 : 16),
    ]));
  }

  Widget _buildPortfolioCard({required BuildContext context, required String title, required String value, required String subtitle, required IconData icon, required bool isDarkMode, required AppState appState, Color valueColor = Colors.white}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Container(width: isSmallScreen ? 150 : 160, decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: const Color(0xFFF7931A), size: isSmallScreen ? 18 : 20),
          Flexible(child: Text(title, style: TextStyle(fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : Colors.black54), overflow: TextOverflow.ellipsis)),
        ]), SizedBox(height: isSmallScreen ? 6 : 8),
        Text(value, style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.bold, color: valueColor), overflow: TextOverflow.ellipsis, maxLines: 2),
        SizedBox(height: isSmallScreen ? 2 : 4), Text(subtitle, style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: isDarkMode ? Colors.white54 : Colors.black54)),
      ]),
    );
  }

  Widget _buildPortfolioDetails(AppState appState) {
    return Container(width: double.infinity, decoration: BoxDecoration(color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.analytics, color: const Color(0xFFF7931A), size: 20), const SizedBox(width: 8),
          Text('Portfolio Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appState.isDarkMode ? Colors.white : Colors.black))]),
        const SizedBox(height: 16),
        _buildPortfolioDetailRow('Total Investment', appState.totalInvestment == 0 ? '-' : appState.formatSensitiveValue(appState.totalInvestment, currency: currencyToString(appState.selectedCurrency)), appState.isDarkMode),
        _buildPortfolioDetailRow('Current Value', appState.portfolioValue == 0 ? '-' : appState.formatSensitiveValue(appState.portfolioValue, currency: currencyToString(appState.selectedCurrency)), appState.isDarkMode),
        _buildPortfolioDetailRow('Total Return', appState.formatSensitiveValue(appState.profitLoss, currency: currencyToString(appState.selectedCurrency)), appState.isDarkMode, valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red),
        _buildPortfolioDetailRow('Return Percentage', appState.formatSensitivePercentage(appState.profitLossPercentage), appState.isDarkMode, valueColor: appState.profitLoss >= 0 ? Colors.green : Colors.red),
        _buildPortfolioDetailRow('Number of Purchases', '${appState.purchases.length}', appState.isDarkMode),
        _buildPortfolioDetailRow('Number of Sales', '${appState.sales.length}', appState.isDarkMode), // MOVED TO LAST
      ]),
    );
  }

  Widget _buildPortfolioDetailRow(String label, String value, bool isDarkMode, {Color? valueColor}) {
    final defaultColor = isDarkMode ? Colors.white : Colors.black;
    return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, width: 1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white70 : Colors.black54)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor ?? defaultColor)),
      ]),
    );
  }

  Widget _buildPortfolioAllocationChart(AppState appState) {
    if (appState.purchases.isEmpty) return const SizedBox();

    // Calculate both cash invested and current value per year
    final Map<int, double> yearlyInvestment = {};
    final Map<int, double> yearlyCurrentValue = {};
    final Map<int, double> yearlyBTC = {};

    for (final purchase in appState.purchases) {
      final purchaseYear = purchase.date.year;

      // Convert purchase value to selected currency
      final purchaseValue = _convertCurrency(
          purchase.totalCashSpent,
          purchase.cashCurrency,
          appState.selectedCurrency,
          appState.btcPrices
      );

      // Calculate current value of this purchase
      final currentValue = purchase.amountBTC * appState.getBtcPrice(appState.selectedCurrency);

      yearlyInvestment[purchaseYear] = (yearlyInvestment[purchaseYear] ?? 0) + purchaseValue;
      yearlyCurrentValue[purchaseYear] = (yearlyCurrentValue[purchaseYear] ?? 0) + currentValue;
      yearlyBTC[purchaseYear] = (yearlyBTC[purchaseYear] ?? 0) + purchase.amountBTC;
    }

    final List<_YearlyData> allocationData = yearlyInvestment.entries.map((entry) {
      final year = entry.key;
      final investment = entry.value;
      final currentValue = yearlyCurrentValue[year] ?? 0;
      final btcAmount = yearlyBTC[year] ?? 0;
      final profitLoss = currentValue - investment;
      final profitLossPercentage = investment > 0 ? (profitLoss / investment) * 100 : 0.0;

      return _YearlyData(
        year: year,
        investment: investment,
        currentValue: currentValue,
        btcAmount: btcAmount,
        profitLoss: profitLoss,
        profitLossPercentage: profitLossPercentage.toDouble(),
        color: _getColorForYear(year),
      );
    }).toList()..sort((a, b) => a.year.compareTo(b.year));

    if (allocationData.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: const Color(0xFFF7931A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Portfolio Allocation by Year',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appState.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pie chart
                    Container(
                      width: 160,
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sections: allocationData.map((data) => PieChartSectionData(
                                value: data.investment,
                                color: data.color,
                                title: '',
                                radius: 20,
                              )).toList(),
                              centerSpaceRadius: 50,
                              sectionsSpace: 2,
                              startDegreeOffset: -90,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Investment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              Text(
                                appState.holdingsHidden ? '****' : currencyToString(appState.selectedCurrency),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: appState.isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                'Allocation',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: appState.isDarkMode ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // List of years
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: allocationData.length,
                          itemBuilder: (context, index) {
                            final data = allocationData[index];
                            final currencySymbol = currencyToString(appState.selectedCurrency);

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: data.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${data.year}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: appState.isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),

                                        if (appState.holdingsHidden) ...[
                                          Text(
                                            '**** BTC · **** $currencySymbol',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            'Invested: **** $currencySymbol',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: appState.isDarkMode ? Colors.white60 : Colors.black45,
                                            ),
                                          ),
                                        ] else ...[
                                          Text(
                                            '${formatDenomination(data.btcAmount, appState.denomination)} · ${_formatNumber(data.currentValue)} $currencySymbol',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Invested: ',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: appState.isDarkMode ? Colors.white60 : Colors.black45,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '${_formatNumber(data.investment)} $currencySymbol',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' (${data.profitLossPercentage.toStringAsFixed(1)}%)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: data.profitLoss >= 0 ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sections: allocationData.map((data) => PieChartSectionData(
                                value: data.investment,
                                color: data.color,
                                title: '',
                                radius: 18,
                              )).toList(),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                              startDegreeOffset: -90,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Investment',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              Text(
                                currencyToString(appState.selectedCurrency),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: appState.isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                'Allocation',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: appState.isDarkMode ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Grid view for small screens
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: allocationData.map((data) {
                        final currencySymbol = currencyToString(appState.selectedCurrency);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: data.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${data.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: appState.isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),

                                    if (appState.holdingsHidden) ...[
                                      Text(
                                        '**** BTC',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        'Invested: ****',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: appState.isDarkMode ? Colors.white60 : Colors.black45,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        formatDenomination(data.btcAmount, appState.denomination),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${_formatNumber(data.investment)} $currencySymbol',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: appState.isDarkMode ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' (${data.profitLossPercentage.toStringAsFixed(1)}%)',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: data.profitLoss >= 0 ? Colors.green : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(AppState appState) {
    return Container(width: double.infinity, decoration: BoxDecoration(color: appState.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.leaderboard, color: const Color(0xFFF7931A), size: 20), const SizedBox(width: 8),
          Text('Performance Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appState.isDarkMode ? Colors.white : Colors.black))]),
        const SizedBox(height: 16),
        _buildMetricRow('ROI', appState.formatSensitivePercentage(appState.profitLossPercentage), appState.profitLossPercentage >= 0, appState.isDarkMode),
        _buildMetricRow('Total Return', appState.formatSensitiveValue(appState.profitLoss, currency: currencyToString(appState.selectedCurrency)), appState.profitLoss >= 0, appState.isDarkMode),
        _buildMetricRow('Avg. Cost Basis', appState.holdingsHidden ? '****' : '${appState.averagePrice.toStringAsFixed(2)} ${currencyToString(appState.selectedCurrency)}', true, appState.isDarkMode),
        _buildMetricRow('Current Price', '${appState.getBtcPrice(appState.selectedCurrency).toStringAsFixed(2)} ${currencyToString(appState.selectedCurrency)}', true, appState.isDarkMode),
        // REMOVED: 'Total Sales' row
      ]),
    );
  }

  Widget _buildMetricRow(String label, String value, bool isPositive, bool isDarkMode) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, width: 1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white54 : Colors.black54)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isPositive ? (isDarkMode ? Colors.green[300] : Colors.green[700]) : (isDarkMode ? Colors.red[300] : Colors.red[700]))),
      ]),
    );
  }

  Widget _buildTransactionForm(AppState appState) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      if (isWide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildAmountField(appState)), const SizedBox(width: 16),
        Expanded(child: _buildPriceField(appState)), const SizedBox(width: 16), _buildDatePicker(appState),
      ]);
      else return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildAmountField(appState), const SizedBox(height: 16), _buildPriceField(appState), const SizedBox(height: 16), _buildDatePicker(appState),
      ]);
    });
  }

  Widget _buildAmountField(AppState appState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(appState.denomination == Denomination.BTC ? 'BTC Amount' : 'Sats Amount', style: TextStyle(fontWeight: FontWeight.w600, color: appState.isDarkMode ? Colors.white70 : Colors.black54)),
      const SizedBox(height: 8),
      TextField(controller: _amountController, keyboardType: appState.denomination == Denomination.BTC ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
          inputFormatters: appState.denomination == Denomination.SATS ? [ThousandsSeparatorInputFormatter()] : [],
          decoration: InputDecoration(hintText: appState.denomination == Denomination.BTC ? '0.00000000' : '0', border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), filled: true, fillColor: appState.isDarkMode ? Colors.grey[800] : Colors.grey[100]),
          style: TextStyle(fontSize: 16, color: appState.isDarkMode ? Colors.white : Colors.black)),
    ]);
  }

  Widget _buildPriceField(AppState appState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Price per BTC (${currencyToString(appState.selectedCurrency)})', style: TextStyle(fontWeight: FontWeight.w600, color: appState.isDarkMode ? Colors.white70 : Colors.black54)),
      const SizedBox(height: 8),
      TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: '0.00', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              filled: true, fillColor: appState.isDarkMode ? Colors.grey[800] : Colors.grey[100]),
          style: TextStyle(fontSize: 16, color: appState.isDarkMode ? Colors.white : Colors.black)),
    ]);
  }

  Widget _buildDatePicker(AppState appState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Transaction Date', style: TextStyle(fontWeight: FontWeight.w600, color: appState.isDarkMode ? Colors.white70 : Colors.black54)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: () => _pickDate(appState), icon: const Icon(Icons.calendar_today, size: 20), label: Text(_formatUKDate(appState.selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      )),
    ]);
  }

  Color _getColorForYear(int year) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan, Colors.lightBlue, Colors.lightGreen, Colors.deepOrange, Colors.deepPurple, Colors.brown, Colors.blueGrey];
    return colors[year % colors.length];
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _isAppActive = state == AppLifecycleState.resumed);
    if (_isAppActive) { _startAutoRefresh(); Provider.of<AppState>(context, listen: false).fetchBtcPrices(); }
    else _autoRefreshTimer?.cancel();
  }
}

class _YearlyData {
  final int year;
  final double investment;
  final double currentValue;
  final double btcAmount;
  final double profitLoss;
  final double profitLossPercentage;
  final Color color;

  _YearlyData({
    required this.year,
    required this.investment,
    required this.currentValue,
    required this.btcAmount,
    required this.profitLoss,
    required this.profitLossPercentage,
    required this.color,
  });
}

// Helper widget for input formatter (if not already defined elsewhere)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove all non-digit characters
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Add thousands separators
    final formatter = NumberFormat('#,###');
    try {
      final number = int.parse(newText);
      newText = formatter.format(number);
    } catch (e) {
      // If parsing fails, return the old value
      return oldValue;
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}