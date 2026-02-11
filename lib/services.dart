// services.dart - COMPLETE FIXED VERSION WITH PROPER MIGRATION
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'constants.dart';
import 'dart:io';
import 'security_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class RateLimitException implements Exception {
  @override String toString() => 'Rate limit exceeded';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override String toString() => 'Network error: $message';
}

class ApiTimeoutException implements Exception {
  @override String toString() => 'API request timed out';
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override String toString() => 'API error: $message (Status code: $statusCode)';
}

class ApiService {
  static Future<Map<String, double>> fetchBtcPrices() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd,gbp,eur,cad,aud,jpy,cny'),
        headers: {'User-Agent': 'YourApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'usd': (data['bitcoin']['usd'] as num).toDouble(),
          'gbp': (data['bitcoin']['gbp'] as num).toDouble(),
          'eur': (data['bitcoin']['eur'] as num).toDouble(),
          'cad': (data['bitcoin']['cad'] as num).toDouble(),
          'aud': (data['bitcoin']['aud'] as num).toDouble(),
          'jpy': (data['bitcoin']['jpy'] as num).toDouble(),
          'cny': (data['bitcoin']['cny'] as num).toDouble(),
        };
      } else if (response.statusCode == 429) {
        throw RateLimitException();
      } else {
        throw ApiException('API returned status code: ${response.statusCode}', response.statusCode);
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (_) {
      throw ApiTimeoutException();
    } catch (e) {
      throw ApiException('Failed to load BTC prices: ${e.toString()}', -1);
    }
  }

  static Future<List<PriceDataPoint>> fetchHistoricalData(String currency, int days) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=${currency.toLowerCase()}&days=$days'),
        headers: {'User-Agent': 'YourApp/1.0'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prices = data['prices'] as List;
        return prices.map((e) {
          return PriceDataPoint(
            DateTime.fromMillisecondsSinceEpoch(e[0]),
            (e[1] as num).toDouble(),
          );
        }).toList();
      } else {
        throw ApiException('API returned status code: ${response.statusCode}', response.statusCode);
      }
    } on TimeoutException catch (_) {
      throw ApiTimeoutException();
    } catch (e) {
      throw ApiException('Failed to load historical data: ${e.toString()}', -1);
    }
  }
}

class StorageService {
  Future<List<Purchase>> loadPurchases() async {
    try {
      final encryptionKey = await SecurityService().getEncryptionKey();
      final box = await Hive.openBox('btc_purchases', encryptionKey: encryptionKey);
      final rawList = box.get('purchases', defaultValue: <dynamic>[]);
      final purchases = rawList.map<Purchase>((item) => Purchase.fromMap(Map<String, dynamic>.from(item))).toList();
      print('Loaded ${purchases.length} purchases from storage');
      return purchases;
    } catch (e) {
      print('Error loading purchases: $e');
      return [];
    }
  }

  // FIXED: Use FilePicker.saveFile with bytes parameter - Google Play compliant
  // NEW: Automatically saves to app's "My Files" storage in addition to user-selected location
  Future<String> saveFileToLocation(Uint8List bytes, String fileName) async {
    String? externalSaveResult;

    try {
      if (kIsWeb) {
        // Web implementation
        return await saveFileLocally(bytes, fileName);
      } else {
        // Mobile implementation - use FilePicker to get the save location with bytes
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save File As',
          fileName: fileName,
          type: FileType.any,
          bytes: bytes, // Required parameter for Android/iOS
        );

        if (outputFile != null) {
          // FilePicker automatically saves the file when bytes are provided
          externalSaveResult = 'File saved to: $outputFile';
        } else {
          // User canceled the operation
          externalSaveResult = 'Save operation canceled';
        }
      }
    } catch (e) {
      print('Error saving file to external location: $e');
      externalSaveResult = 'External save failed: ${e.toString()}';
    }

    // NEW: ALWAYS save a copy to app's internal "My Files" storage
    String internalSaveResult;
    try {
      internalSaveResult = await _saveToAppStorage(bytes, fileName);
    } catch (e) {
      print('Error saving file to app storage: $e');
      internalSaveResult = 'App storage save failed: ${e.toString()}';
    }

    // Combine results
    if (externalSaveResult != null && externalSaveResult.contains('saved to:')) {
      return '$externalSaveResult | $internalSaveResult';
    } else {
      return internalSaveResult; // Return app storage result if external failed or was canceled
    }
  }

  // NEW: Helper method to always save files to app storage for "My Files" functionality
  Future<String> _saveToAppStorage(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stackTrackDir = Directory('${directory.path}/SatStack');
      if (!await stackTrackDir.exists()) {
        await stackTrackDir.create(recursive: true);
      }

      final internalPath = '${stackTrackDir.path}/$fileName';
      final File file = File(internalPath);
      await file.writeAsBytes(bytes, flush: true);

      print('File automatically saved to app storage: $internalPath');
      return 'File saved to app storage: $internalPath';
    } catch (e) {
      print('Error saving to app storage: $e');
      throw Exception('Failed to save file to app storage: ${e.toString()}');
    }
  }

  // UPDATED: Load sales with migration support
  Future<List<Sale>> loadSales() async {
    try {
      final encryptionKey = await SecurityService().getEncryptionKey();
      final box = await Hive.openBox('btc_sales', encryptionKey: encryptionKey);
      final rawList = box.get('sales', defaultValue: <dynamic>[]);
      final sales = rawList.map<Sale>((item) => Sale.fromMap(Map<String, dynamic>.from(item))).toList();
      print('Loaded ${sales.length} sales from storage');
      return sales;
    } catch (e) {
      print('Error loading sales: $e');
      return [];
    }
  }

  // FIXED: Migrate sales to new format
  Future<void> migrateSalesToNewFormat() async {
    try {
      final oldSales = await loadSales();
      if (oldSales.isEmpty) return;

      print('Checking ${oldSales.length} sales for migration...');

      // Check if migration is needed
      bool needsMigration = false;
      for (final sale in oldSales) {
        final saleMap = sale.toMap();
        // Check if this is an old format sale (missing originalCurrency or has old price fields)
        if (!saleMap.containsKey('originalCurrency') || saleMap['originalCurrency'] == null) {
          needsMigration = true;
          break;
        }
      }

      if (needsMigration) {
        print('Migrating sales to new format...');
        final migratedSales = oldSales.map((oldSale) {
          final oldMap = oldSale.toMap();

          // Extract data from old format
          double price = 0.0;
          Currency currency = Currency.USD; // Default to USD for old sales

          // Try to get price from various possible fields
          if (oldMap.containsKey('price') && oldMap['price'] != null) {
            price = (oldMap['price'] as num).toDouble();
          } else if (oldMap.containsKey('priceUSD') && oldMap['priceUSD'] != null) {
            price = (oldMap['priceUSD'] as num).toDouble();
          }

          // Try to get currency if it exists
          if (oldMap.containsKey('originalCurrency') && oldMap['originalCurrency'] != null) {
            currency = Currency.values[oldMap['originalCurrency']];
          }

          return Sale(
            id: oldSale.id,
            date: oldSale.date,
            amountBTC: oldSale.amountBTC,
            price: price,
            originalCurrency: currency,
          );
        }).toList();

        await saveSales(migratedSales);
        print('Successfully migrated ${migratedSales.length} sales to new format');
      } else {
        print('Sales are already in new format, no migration needed');
      }
    } catch (e) {
      print('Sales migration error: $e');
      // Don't throw - we want the app to work even if migration fails
    }
  }

  Future<void> savePurchases(List<Purchase> purchases) async {
    try {
      final encryptionKey = await SecurityService().getEncryptionKey();
      final box = await Hive.openBox('btc_purchases', encryptionKey: encryptionKey);
      await box.put('purchases', purchases.map((p) => p.toMap()).toList());
      print('Saved ${purchases.length} purchases to storage');
    } catch (e) {
      print('Error saving purchases: $e');
      throw Exception('Failed to save purchases: $e');
    }
  }

  Future<void> saveSales(List<Sale> sales) async {
    try {
      final encryptionKey = await SecurityService().getEncryptionKey();
      final box = await Hive.openBox('btc_sales', encryptionKey: encryptionKey);
      await box.put('sales', sales.map((s) => s.toMap()).toList());
      print('Saved ${sales.length} sales to storage');
    } catch (e) {
      print('Error saving sales: $e');
      throw Exception('Failed to save sales: $e');
    }
  }

  Future<Map<String, int>> getCurrencyPreferences() async {
    final box = Hive.box('preferences');
    return {
      'favorite': box.get('favoriteCurrency', defaultValue: 0),
      'secondary': box.get('secondaryCurrency', defaultValue: 1),
    };
  }

  Future<void> saveCurrencyPreferences(int favoriteIndex, int secondaryIndex) async {
    final box = Hive.box('preferences');
    await box.put('favoriteCurrency', favoriteIndex);
    await box.put('secondaryCurrency', secondaryIndex);
  }

  Future<void> saveDenominationPreference(Denomination denomination) async {
    final box = Hive.box('preferences');
    await box.put('denomination', denomination.index);
  }

  Future<void> exportData({String format = 'csv', bool shareAfterSave = false}) async {
    try {
      final purchases = await loadPurchases();
      final sales = await loadSales();
      final preferencesBox = Hive.box('preferences');
      if (format == 'csv') {
        await _exportToCsv(purchases, sales, shareAfterSave);
      } else if (format == 'pdf') {
        await _exportToPdf(purchases, sales, shareAfterSave);
      } else if (format == 'json') {
        await _exportToJson(purchases, sales, preferencesBox, shareAfterSave);
      }
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  Future<void> _exportToCsv(List<Purchase> purchases, List<Sale> sales, bool shareAfterSave) async {
    final List<List<dynamic>> csvData = [];
    final utf8Bom = [0xEF, 0xBB, 0xBF];
    csvData.add(['SatStack Portfolio Export']);
    csvData.add(['Export Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
    csvData.add(['Total Purchases', purchases.length]);
    csvData.add(['Total Sales', sales.length]);
    csvData.add([]);
    csvData.add(['PURCHASES']);
    csvData.add(['Type', 'ID', 'Date', 'Amount BTC', 'Price per BTC', 'Currency', 'Total Value', 'Timestamp']);
    for (final purchase in purchases) {
      csvData.add(['PURCHASE', purchase.id, DateFormat('yyyy-MM-dd').format(purchase.date), purchase.amountBTC, purchase.pricePerBTC, currencyToString(purchase.cashCurrency), purchase.totalCashSpent, purchase.id]);
    }
    csvData.add([]);
    if (sales.isNotEmpty) {
      csvData.add(['SALES']);
      csvData.add(['Type', 'ID', 'Date', 'Amount BTC', 'Price', 'Currency', 'Total Value', 'Timestamp']);
      for (final sale in sales) {
        csvData.add(['SALE', sale.id, DateFormat('yyyy-MM-dd').format(sale.date), sale.amountBTC, sale.price, currencyToString(sale.originalCurrency), (sale.amountBTC * sale.price), sale.id]);
      }
    }
    csvData.add([]);
    csvData.add(['PORTFOLIO SUMMARY']);
    final double totalBTC = purchases.fold(0.0, (sum, p) => sum + p.amountBTC) - sales.fold(0.0, (sum, s) => sum + s.amountBTC);
    final double totalInvestment = purchases.fold(0.0, (sum, p) => sum + p.totalCashSpent);
    csvData.add(['Total BTC Holdings', totalBTC]);
    csvData.add(['Total Investment', totalInvestment]);
    if (purchases.isNotEmpty) {
      csvData.add(['Average Purchase Price', totalInvestment / purchases.fold(0.0, (sum, p) => sum + p.amountBTC)]);
    }
    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = utf8Bom + utf8.encode(csvString);
    final fileName = 'satstack_portfolio_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    if (shareAfterSave) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'SatStack Portfolio Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');

      // NEW: Also save to app storage when sharing
      await _saveToAppStorage(Uint8List.fromList(bytes), fileName);
    } else {
      // Use the new saveFileToLocation method which automatically saves to app storage
      final result = await saveFileToLocation(Uint8List.fromList(bytes), fileName);

      if (result.contains('saved to:') || result.contains('app storage')) {
        Future.microtask(() {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('CSV file saved successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4)
                )
            );
          }
        });
      }
    }
  }

  Future<void> _exportToPdf(List<Purchase> purchases, List<Sale> sales, bool shareAfterSave) async {
    final PdfDocument document = PdfDocument();
    final List<PdfPage> pages = [];
    PdfPage currentPage = document.pages.add();
    PdfGraphics graphics = currentPage.graphics;
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    double currentY = 40;
    final double pageWidth = currentPage.size.width;
    final double pageHeight = currentPage.size.height;
    final double margin = 40;
    final double contentWidth = pageWidth - (2 * margin);
    graphics.drawString('SatStack Portfolio Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', titleFont, bounds: Rect.fromLTWH(0, currentY, pageWidth, 30), format: PdfStringFormat(alignment: PdfTextAlignment.center));
    currentY += 50;
    final double totalBTC = purchases.fold(0.0, (sum, p) => sum + p.amountBTC) - sales.fold(0.0, (sum, s) => sum + s.amountBTC);
    final List<String> summaryLines = ['Total BTC Holdings: ${totalBTC.toStringAsFixed(8)}', 'Total Purchases: ${purchases.length}', 'Total Sales: ${sales.length}', 'Export Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'];
    for (String line in summaryLines) {
      graphics.drawString(line, font, bounds: Rect.fromLTWH(margin, currentY, contentWidth, 20));
      currentY += 25;
    }
    currentY += 20;
    bool needsNewPage(double requiredHeight) {
      return currentY + requiredHeight > pageHeight - margin;
    }
    void createNewPage() {
      currentPage = document.pages.add();
      graphics = currentPage.graphics;
      currentY = margin;
    }
    if (purchases.isNotEmpty) {
      if (needsNewPage(60)) createNewPage();
      graphics.drawString('Purchases', headerFont, bounds: Rect.fromLTWH(margin, currentY, contentWidth, 30));
      currentY += 40;
      final PdfGrid purchaseGrid = _createPurchasesGrid(purchases);
      final double gridHeight = purchaseGrid.rows.count * 20 + 40;
      if (needsNewPage(gridHeight)) createNewPage();
      purchaseGrid.draw(page: currentPage, bounds: Rect.fromLTWH(margin, currentY, contentWidth, gridHeight));
      currentY += gridHeight + 30;
    }
    if (sales.isNotEmpty) {
      if (needsNewPage(60)) createNewPage();
      graphics.drawString('Sales', headerFont, bounds: Rect.fromLTWH(margin, currentY, contentWidth, 30));
      currentY += 40;
      final PdfGrid salesGrid = _createSalesGrid(sales);
      final double gridHeight = salesGrid.rows.count * 20 + 40;
      if (needsNewPage(gridHeight)) createNewPage();
      salesGrid.draw(page: currentPage, bounds: Rect.fromLTWH(margin, currentY, contentWidth, gridHeight));
      currentY += gridHeight + 30;
    }
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pageGraphics = page.graphics;
      pageGraphics.drawString('Page ${i + 1} of ${document.pages.count} - Generated by StackTrack', PdfStandardFont(PdfFontFamily.helvetica, 10), bounds: Rect.fromLTWH(0, pageHeight - 30, pageWidth, 20), format: PdfStringFormat(alignment: PdfTextAlignment.center));
    }
    final List<int> bytes = await document.save();
    document.dispose();
    final fileName = 'satstack_portfolio_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    if (shareAfterSave) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'StackTrack Portfolio Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');

      // NEW: Also save to app storage when sharing
      await _saveToAppStorage(Uint8List.fromList(bytes), fileName);
    } else {
      // Use the new saveFileToLocation method which automatically saves to app storage
      final result = await saveFileToLocation(Uint8List.fromList(bytes), fileName);

      if (result.contains('saved to:') || result.contains('app storage')) {
        Future.microtask(() {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('PDF file saved successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4)
                )
            );
          }
        });
      }
    }
  }

  PdfGrid _createPurchasesGrid(List<Purchase> purchases) {
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 6);
    grid.headers.add(1);
    final PdfGridRow headerRow = grid.headers[0];
    headerRow.cells[0].value = 'Date';
    headerRow.cells[1].value = 'Amount (BTC)';
    headerRow.cells[2].value = 'Price/BTC';
    headerRow.cells[3].value = 'Currency';
    headerRow.cells[4].value = 'Total Value';
    headerRow.cells[5].value = 'ID';
    headerRow.style.backgroundBrush = PdfSolidBrush(PdfColor(200, 200, 200));
    headerRow.style.font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    for (final purchase in purchases) {
      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = DateFormat('yyyy-MM-dd').format(purchase.date);
      row.cells[1].value = purchase.amountBTC.toStringAsFixed(8);
      row.cells[2].value = purchase.pricePerBTC.toStringAsFixed(2);
      row.cells[3].value = currencyToString(purchase.cashCurrency);
      row.cells[4].value = purchase.totalCashSpent.toStringAsFixed(2);
      row.cells[5].value = purchase.id.substring(0, 8);
      row.style.font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    }
    grid.style.cellPadding = PdfPaddings(left: 5, right: 5, top: 5, bottom: 5);
    return grid;
  }

  // UPDATED: Sales grid to show new format
  PdfGrid _createSalesGrid(List<Sale> sales) {
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 6);
    grid.headers.add(1);
    final PdfGridRow headerRow = grid.headers[0];
    headerRow.cells[0].value = 'Date';
    headerRow.cells[1].value = 'Amount (BTC)';
    headerRow.cells[2].value = 'Price';
    headerRow.cells[3].value = 'Currency';
    headerRow.cells[4].value = 'Total Value';
    headerRow.cells[5].value = 'ID';
    headerRow.style.backgroundBrush = PdfSolidBrush(PdfColor(200, 200, 200));
    headerRow.style.font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    for (final sale in sales) {
      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = DateFormat('yyyy-MM-dd').format(sale.date);
      row.cells[1].value = sale.amountBTC.toStringAsFixed(8);
      row.cells[2].value = sale.price.toStringAsFixed(2);
      row.cells[3].value = currencyToString(sale.originalCurrency);
      row.cells[4].value = (sale.amountBTC * sale.price).toStringAsFixed(2);
      row.cells[5].value = sale.id.substring(0, 8);
      row.style.font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    }
    grid.style.cellPadding = PdfPaddings(left: 5, right: 5, top: 5, bottom: 5);
    return grid;
  }

  Future<void> _exportToJson(List<Purchase> purchases, List<Sale> sales, Box preferencesBox, bool shareAfterSave) async {
    final jsonData = {
      'version': 3, // Updated version for new sales format
      'exportDate': DateTime.now().toIso8601String(),
      'purchases': purchases.map((p) => p.toMap()).toList(),
      'sales': sales.map((s) => s.toMap()).toList(),
      'preferences': {
        'isDarkMode': preferencesBox.get('isDarkMode', defaultValue: true),
        'favoriteCurrency': preferencesBox.get('favoriteCurrency', defaultValue: 0),
        'secondaryCurrency': preferencesBox.get('secondaryCurrency', defaultValue: 1),
        'denomination': preferencesBox.get('denomination', defaultValue: 0),
      }
    };
    final jsonString = jsonEncode(jsonData);
    final fileName = 'satstack_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final bytes = utf8.encode(jsonString);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..setAttribute('download', fileName)..click();
      html.Url.revokeObjectUrl(url);
    } else {
      if (shareAfterSave) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(tempFile.path)], text: 'SatStack Backup - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');

        // NEW: Also save to app storage when sharing
        await _saveToAppStorage(Uint8List.fromList(bytes), fileName);
      } else {
        // Use the new saveFileToLocation method which automatically saves to app storage
        final result = await saveFileToLocation(Uint8List.fromList(bytes), fileName);

        if (result.contains('saved to:') || result.contains('app storage')) {
          Future.microtask(() {
            final context = navigatorKey.currentContext;
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('JSON backup saved successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4)
                  )
              );
            }
          });
        }
      }
    }
  }

  Future<void> importDataFromCsv(String csvString) async {
    try {
      print('Starting CSV import...');
      if (csvString.startsWith('\uFEFF')) csvString = csvString.substring(1);
      String delimiter = _detectDelimiter(csvString);
      print('Detected delimiter: $delimiter');
      final csvConverter = CsvToListConverter(fieldDelimiter: delimiter, shouldParseNumbers: false, allowInvalid: true);
      final List<List<dynamic>> csvData = csvConverter.convert(csvString);
      if (csvData.isEmpty) throw Exception('Empty CSV file');
      print('CSV data loaded with ${csvData.length} rows');
      final List<Purchase> purchases = [];
      final List<Sale> sales = [];
      for (int i = 0; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.isEmpty) continue;
        if (_isHeaderRow(row)) continue;
        try {
          final purchase = _parsePurchaseFromRow(row);
          if (purchase != null) {
            purchases.add(purchase);
            print('Successfully parsed purchase: ${purchase.amountBTC} BTC on ${purchase.date}');
            continue;
          }
        } catch (e) { print('Failed to parse row $i as purchase: $e'); }
        try {
          final sale = _parseSaleFromRow(row);
          if (sale != null) {
            sales.add(sale);
            print('Successfully parsed sale: ${sale.amountBTC} BTC on ${sale.date}');
            continue;
          }
        } catch (e) { print('Failed to parse row $i as sale: $e'); }
        print('Could not parse row $i: $row');
      }
      print('Successfully parsed ${purchases.length} purchases and ${sales.length} sales');
      if (purchases.isNotEmpty || sales.isNotEmpty) {
        if (purchases.isNotEmpty) {
          await savePurchases(purchases);
          print('Saved ${purchases.length} purchases to storage');
        }
        if (sales.isNotEmpty) {
          await saveSales(sales);
          print('Saved ${sales.length} sales to storage');
        }
      } else {
        throw Exception('No valid purchase or sale data found in CSV. Please check the file format.');
      }
    } catch (e) {
      print('CSV import error: $e');
      throw Exception('Failed to import CSV: ${e.toString()}');
    }
  }

  bool _isHeaderRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    final firstCell = row[0].toString().toLowerCase();
    return firstCell.contains('stacktrack') || firstCell.contains('export') || firstCell.contains('type') || firstCell.contains('date') && firstCell.contains('amount') || firstCell.contains('purchase') && firstCell.contains('sale');
  }

  Purchase? _parsePurchaseFromRow(List<dynamic> row) {
    try {
      if (row.length < 3) return null;
      DateTime date = DateTime.now();
      double amountBTC = 0;
      double pricePerBTC = 0;
      Currency currency = Currency.USD;
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().trim();
        if (cell.isEmpty) continue;
        if (_looksLikeDate(cell)) {
          date = _parseDate(cell);
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().replaceAll(',', '');
        final amount = double.tryParse(cell);
        if (amount != null && amount > 0 && amount < 100) {
          amountBTC = amount;
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().replaceAll(',', '');
        final price = double.tryParse(cell);
        if (price != null && price > 100 && price < 1000000) {
          pricePerBTC = price;
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().toUpperCase();
        if (cell == 'USD' || cell == 'GBP' || cell == 'EUR' || cell == 'CAD' || cell == 'AUD' || cell == 'JPY' || cell == 'CNY') {
          currency = _parseCurrency(cell);
          break;
        }
      }
      if (amountBTC > 0 && pricePerBTC > 0) {
        return Purchase(date: date, amountBTC: amountBTC, pricePerBTC: pricePerBTC, cashCurrency: currency);
      }
      return null;
    } catch (e) {
      print('Purchase parsing error: $e');
      return null;
    }
  }

  // UPDATED: Sale parsing for new format
  Sale? _parseSaleFromRow(List<dynamic> row) {
    try {
      if (row.length < 3) return null;
      DateTime date = DateTime.now();
      double amountBTC = 0;
      double price = 0;
      Currency currency = Currency.USD;
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().trim();
        if (cell.isEmpty) continue;
        if (_looksLikeDate(cell)) {
          date = _parseDate(cell);
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().replaceAll(',', '');
        final amount = double.tryParse(cell);
        if (amount != null && amount > 0 && amount < 100) {
          amountBTC = amount;
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().replaceAll(',', '');
        final salePrice = double.tryParse(cell);
        if (salePrice != null && salePrice > 100 && salePrice < 1000000) {
          price = salePrice;
          break;
        }
      }
      for (int i = 0; i < row.length; i++) {
        final cell = row[i].toString().toUpperCase();
        if (cell == 'USD' || cell == 'GBP' || cell == 'EUR' || cell == 'CAD' || cell == 'AUD' || cell == 'JPY' || cell == 'CNY') {
          currency = _parseCurrency(cell);
          break;
        }
      }
      if (amountBTC > 0 && price > 0) {
        return Sale(
            date: date,
            amountBTC: amountBTC,
            price: price,
            originalCurrency: currency
        );
      }
      return null;
    } catch (e) {
      print('Sale parsing error: $e');
      return null;
    }
  }

  bool _looksLikeDate(String value) {
    return value.contains('/') || value.contains('-') || value.contains('Jan') || value.contains('Feb') || value.contains('Mar') || value.contains('Apr') || value.contains('May') || value.contains('Jun') || value.contains('Jul') || value.contains('Aug') || value.contains('Sep') || value.contains('Oct') || value.contains('Nov') || value.contains('Dec');
  }

  DateTime _parseDate(String dateString) {
    try {
      if (dateString.contains('-') && dateString.length >= 8) {
        if (dateString.contains('T')) {
          return DateTime.parse(dateString);
        } else {
          return DateTime.parse(dateString + 'T00:00:00Z');
        }
      }
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          return DateTime(year, month, day);
        }
      }
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          int month = int.parse(parts[0]);
          int day = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          return DateTime(year, month, day);
        }
      }
      try {
        return DateFormat('MMM dd, yyyy').parse(dateString);
      } catch (e) {
        try {
          return DateFormat('dd MMM yyyy').parse(dateString);
        } catch (e) {
          return DateTime.now();
        }
      }
    } catch (e) {
      print('Date parsing error for "$dateString": $e');
      return DateTime.now();
    }
  }

  String _detectDelimiter(String csvString) {
    final lines = csvString.split('\n').take(5).toList();
    int commaCount = 0, semicolonCount = 0, tabCount = 0;
    for (final line in lines) {
      commaCount += line.split(',').length - 1;
      semicolonCount += line.split(';').length - 1;
      tabCount += line.split('\t').length - 1;
    }
    if (tabCount > commaCount && tabCount > semicolonCount) return '\t';
    if (semicolonCount > commaCount && semicolonCount > tabCount) return ';';
    return ',';
  }

  Future<void> importData({String format = 'auto'}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('Selected file: ${file.name}, size: ${file.size} bytes');
        String detectedFormat = format;
        if (format == 'auto') {
          if (file.name.toLowerCase().endsWith('.csv') || _looksLikeCsv(await _readFileContent(file))) {
            detectedFormat = 'csv';
          } else if (file.name.toLowerCase().endsWith('.json') || _looksLikeJson(await _readFileContent(file))) {
            detectedFormat = 'json';
          } else {
            throw Exception('Unable to detect file format. Please use CSV or JSON.');
          }
        }
        print('Detected format: $detectedFormat');
        if (detectedFormat == 'csv') {
          final fileContent = await _readFileContent(file);
          await importDataFromCsv(fileContent);
        } else if (detectedFormat == 'json') {
          final fileContent = await _readFileContent(file);
          await importDataFromJsonString(fileContent);
        }
      } else {
        throw Exception('No file selected');
      }
    } catch (e) {
      print('Import error: $e');
      throw Exception('Failed to import data: ${e.toString()}');
    }
  }

  Future<String> _readFileContent(PlatformFile file) async {
    if (kIsWeb) return String.fromCharCodes(file.bytes!);
    else return await File(file.path!).readAsString();
  }

  bool _looksLikeJson(String content) {
    try {
      final trimmed = content.trim();
      return (trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'));
    } catch (e) {
      return false;
    }
  }

  bool _looksLikeCsv(String content) {
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) return false;
    final firstLine = lines.first;
    return firstLine.contains(',') || firstLine.contains(';') || firstLine.contains('\t');
  }

  Future<void> importDataFromJsonString(String jsonString) async {
    try {
      Map<String, dynamic> data = jsonDecode(jsonString);
      if (data['purchases'] is List) {
        List<Purchase> purchases = (data['purchases'] as List).map((item) => Purchase.fromMap(Map<String, dynamic>.from(item))).toList();
        await savePurchases(purchases);
        print('Imported ${purchases.length} purchases from JSON');
      }
      if (data['sales'] is List) {
        List<Sale> sales = (data['sales'] as List).map((item) => Sale.fromMap(Map<String, dynamic>.from(item))).toList();
        await saveSales(sales);
        print('Imported ${sales.length} sales from JSON');
      }
      if (data['preferences'] is Map) {
        final preferences = data['preferences'] as Map;
        final box = Hive.box('preferences');
        await box.put('isDarkMode', preferences['isDarkMode'] ?? true);
        await box.put('favoriteCurrency', preferences['favoriteCurrency'] ?? 0);
        await box.put('secondaryCurrency', preferences['secondaryCurrency'] ?? 1);
        await box.put('denomination', preferences['denomination'] ?? 0);
        print('Imported preferences from JSON');
      }
    } catch (e) {
      throw Exception('Invalid JSON format: $e');
    }
  }

  Currency _parseCurrency(String currencyStr) {
    switch (currencyStr.toUpperCase()) {
      case 'USD': return Currency.USD;
      case 'GBP': return Currency.GBP;
      case 'EUR': return Currency.EUR;
      case 'CAD': return Currency.CAD;
      case 'AUD': return Currency.AUD;
      case 'JPY': return Currency.JPY;
      case 'CNY': return Currency.CNY;
      default: return Currency.USD;
    }
  }

  Future<String> saveFileLocally(List<int> bytes, String fileName) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..setAttribute('download', fileName)..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $fileName';
      } else {
        // Use the new _saveToAppStorage method for consistency
        return await _saveToAppStorage(Uint8List.fromList(bytes), fileName);
      }
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';
      final File file = File(savePath);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(savePath)]);
      return 'File shared instead: $savePath';
    }
  }

  Future<bool> checkFileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getExportedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stackTrackDir = Directory('${directory.path}/SatStack');
      if (!await stackTrackDir.exists()) return [];
      final files = await stackTrackDir.list().toList();
      final List<Map<String, dynamic>> fileList = [];
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          fileList.add({
            'name': file.uri.pathSegments.last, 'path': file.path, 'size': stat.size,
            'modified': stat.modified, 'type': _getFileType(file.uri.pathSegments.last),
          });
        }
      }
      fileList.sort((a, b) => b['modified'].compareTo(a['modified']));
      return fileList;
    } catch (e) {
      throw Exception('Failed to get files: $e');
    }
  }

  String _getFileType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.csv')) return 'CSV';
    if (lowerName.endsWith('.pdf')) return 'PDF';
    if (lowerName.endsWith('.json')) return 'JSON';
    return 'Unknown';
  }

  Future<void> deleteExportedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      switch (result.type) {
        case ResultType.done: break;
        case ResultType.noAppToOpen: throw Exception('No app available to open this file type');
        case ResultType.fileNotFound: throw Exception('File not found: $filePath');
        case ResultType.permissionDenied: throw Exception('Permission denied to open file');
        case ResultType.error: throw Exception('Error opening file: ${result.message}');
      }
    } catch (e) {
      throw Exception('Failed to open file: ${e.toString()}');
    }
  }

  Future<void> openFileWithPicker(String filePath) async {
    try {
      await openFile(filePath);
    } catch (e) {
      print('Direct open failed: $e');
      final file = File(filePath);
      if (await file.exists()) {
        final fileName = file.uri.pathSegments.last.toLowerCase();
        if (fileName.endsWith('.csv')) {
          try {
            final content = await file.readAsString();
            await Share.share(content, subject: 'CSV File Content');
          } catch (shareError) {
            await shareFile(filePath);
          }
        } else {
          await shareFile(filePath);
        }
      } else {
        throw Exception('File not found: $filePath');
      }
    }
  }
}