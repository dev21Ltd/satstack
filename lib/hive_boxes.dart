import 'dart:typed_data';

import 'package:hive/hive.dart';

class HiveBoxes {
  static const purchases = 'btc_purchases';
  static const sales = 'btc_sales';
  static const preferences = 'preferences';
  static const purchasesKey = 'purchases';
  static const salesKey = 'sales';

  static HiveAesCipher cipher(Uint8List key) => HiveAesCipher(key);

  static Future<Box> openPurchases(Uint8List key) {
    return _openEncrypted(purchases, purchasesKey, key);
  }

  static Future<Box> openSales(Uint8List key) {
    return _openEncrypted(sales, salesKey, key);
  }

  static Future<Box> purchasesBox(Uint8List key) async {
    if (Hive.isBoxOpen(purchases)) return Hive.box(purchases);
    return openPurchases(key);
  }

  static Future<Box> salesBox(Uint8List key) async {
    if (Hive.isBoxOpen(sales)) return Hive.box(sales);
    return openSales(key);
  }

  static Future<Box> openPreferences(Uint8List key) {
    return _openEncryptedAllKeys(preferences, key);
  }

  static Future<void> resetAll() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk(purchases);
    await Hive.deleteBoxFromDisk(sales);
    await Hive.deleteBoxFromDisk(preferences);
  }

  /// Open [name] with AES. If the on-disk box is the old unencrypted format,
  /// copy its list at [dataKey] into a new encrypted box.
  ///
  /// Does not open an unencrypted box first — that is what previously left
  /// first-run installs unencrypted.
  static Future<Box> _openEncrypted(
    String name,
    String dataKey,
    Uint8List key,
  ) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).close();
    }

    try {
      return await Hive.openBox(name, encryptionCipher: cipher(key));
    } catch (_) {
      // Cipher mismatch or legacy unencrypted file. Try a plaintext open.
    }

    List<dynamic> data = [];
    try {
      final old = await Hive.openBox(name);
      final raw = old.get(dataKey, defaultValue: <dynamic>[]);
      if (raw is List) {
        data = List<dynamic>.from(raw);
      }
      await old.close();
    } catch (e) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
      rethrow;
    }

    await Hive.deleteBoxFromDisk(name);
    final box = await Hive.openBox(name, encryptionCipher: cipher(key));
    if (data.isNotEmpty) {
      await box.put(dataKey, data);
    }
    return box;
  }

  static Future<Box> _openEncryptedAllKeys(String name, Uint8List key) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).close();
    }

    try {
      return await Hive.openBox(name, encryptionCipher: cipher(key));
    } catch (_) {}

    Map<dynamic, dynamic> data = {};
    try {
      final old = await Hive.openBox(name);
      data = Map<dynamic, dynamic>.from(old.toMap());
      await old.close();
    } catch (e) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
      rethrow;
    }

    await Hive.deleteBoxFromDisk(name);
    final box = await Hive.openBox(name, encryptionCipher: cipher(key));
    if (data.isNotEmpty) {
      await box.putAll(data);
    }
    return box;
  }
}
