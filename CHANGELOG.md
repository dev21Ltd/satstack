# Changelog

## 1.0.2 (2026-09-14)

Android version code **8**.

### Security
- Purchases, sales, and preferences are stored in Hive with AES. The key is kept in the device keystore.
- A PIN (and recovery answer) wraps that key. Encrypted boxes are not opened until unlock.
- PIN values are hashed, with lockout after failed attempts. They are not stored as plain digits.
- Locking the app closes the boxes and drops session data.
- Android backup of app data is disabled. Screenshots of the app are blocked.
- A PIN is not a substitute for encrypting the whole phone. Use a device lock as well.

### Exports
- JSON, CSV, and PDF exports are **plaintext**. Anyone with the file can read your trades.
- The Export and Guide screens, plus PIN setup, state this in the app.
- JSON import/export is a plain file again (no backup password). You can save a JSON backup or pick a JSON file to restore.

### Portfolio
- Chart uses calendar dates, clearer Y-axis values, trade clusters, and an activity strip.
- 3-year range is included.
- Trade-date currency conversion uses historical Bitcoin prices when they are available, with live prices as fallback.

### Other
- Layout fixes for narrow phones (including Pixel 9 Pro).
- CoinGecko price requests use HTTPS certificate checks.
- Web build no longer depends on `dart:io` directly.

## 1.0.1

Previous Play Store / GitHub release (version code 4 and later local builds).
