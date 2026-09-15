# Privacy Policy for SatStack

**Last Updated:** September 15, 2026

## Our Promise
SatStack collects **ZERO** personal data. Your portfolio stays on your device.

## What We Don't Collect
- No personal information
- No portfolio data sent to us
- No transaction history uploaded
- No device identifiers
- No location data
- No analytics or tracking
- No crash reports

## Local Storage
- Trade data is stored in Hive boxes encrypted with AES (HiveAesCipher).
- The Hive key is kept in the device keystore via Flutter Secure Storage.
- When a PIN is set, that Hive key is wrapped with the PIN (and recovery answer). Boxes are not opened until unlock.
- Optional PIN is a lock **and** wraps the disk key. It is not a substitute for full-disk encryption of the phone.

## Exports
- JSON backups are **encrypted** with a password you save in Security Settings (kept in the device keystore). That password is **not** the app PIN.
- Anyone who has the JSON file **and** that password can restore your trades. Without the password the file is not readable.
- Uninstalling the app deletes the stored JSON password. After reinstall, enter the same password in Security Settings, then import the file. If you forget it, those JSON backups cannot be recovered.
- CSV and PDF reports are **plaintext**. Anyone with those files can read your trades. Treat them like financial documents.

## External Services
CoinGecko HTTPS is used only for Bitcoin prices. No portfolio data is sent. Android connections to `api.coingecko.com` check the TLS certificate (leaf pin plus Google Trust Services WE1 issuer).

## Your Rights
- Export data anytime (JSON, CSV, or PDF)
- Uninstall deletes local app data
- Inspect the source: https://github.com/dev21Ltd/satstack

## Contact
Open an issue on GitHub.

---
*Not financial advice. Always secure your own Bitcoin keys.*
