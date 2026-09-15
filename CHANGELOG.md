# Changelog

## 1.0.4 (2026-09-15)

Android version code **10**.

- PIN, recovery, and JSON wrapping use PBKDF2 (600,000 iterations) and AES-256-GCM.
- Older PIN hashes and JSON v4 files still open, then upgrade on the next successful unlock.
- Recovery unlock no longer migrates before the Hive key is unwrapped.

## 1.0.3 (2026-09-15)

Android version code **9**.

- Portfolio chart: original purchase/sale marks, extra time ranges (2Y–10Y), dollar labels kept at the line, dates kept off the $ column.
- JSON backups are encrypted with a password saved in **Security Settings** (not the app PIN). Export/import use that password with the file picker only.
- After reinstall, enter the same JSON password in Security, then import the JSON file. CSV/PDF are plaintext reports, not the encrypted restore.
- Security Settings splits **App PIN** and **JSON password**.
- Overflow menu matches the app theme.

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
