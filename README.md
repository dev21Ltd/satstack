# SatStack 🔐

**Privacy-first Bitcoin Portfolio Tracker**

SatStack is an open source, privacy-focused Bitcoin portfolio tracker. All data stays on your device - no accounts, no tracking, no cloud storage.

## What's new in 1.0.5

- Faster PIN unlock
- Full-screen chart with pinch-zoom
- Per-range ROI (1M–Max)

## What's new in 1.0.4

- Stronger PIN and JSON wrapping (PBKDF2 + AES-GCM)
- Recovery unlock fix

## What's new in 1.0.3

- JSON backups use the password in Security Settings (not the app PIN). After reinstall, enter that password, then import JSON. CSV/PDF stay plaintext.
- Chart: original trade marks, 1M–10Y + Max ranges.
- App PIN and JSON password are separate in Security Settings.

## What's new in 1.0.2

- Stronger on-device security: hashed PIN, lockout, Hive boxes stay closed until unlock, Android backup off, screenshots blocked.
- Clearer portfolio chart (calendar dates, clusters, 3-year range) and trade-date currency conversion when history is available.
- JSON backups are encrypted with the password saved in Security Settings (not the app PIN). CSV and PDF stay plaintext.

Full notes: [CHANGELOG.md](CHANGELOG.md)

## ✨ Features

- 🔒 **Privacy First**: No data collection, local-only storage
- 📊 **Portfolio Tracking**: Track Bitcoin purchases & sales
- 💰 **Multiple Currencies**: USD, GBP, EUR, CAD, AUD, JPY, CNY
- 📈 **Real-time Prices**: Live Bitcoin price updates
- 🔐 **Security**: PIN wraps the Hive AES key; boxes stay closed until unlock
- 📱 **Platforms**: Android (supported). Web compiles. iOS is not maintained in this tree.
- 📤 **Export**: Encrypted JSON backups; plaintext CSV/PDF reports
- 🎨 **Themes**: Dark/Light mode

## 📱 Download

- **Google Play:** [https://play.google.com/store/apps/details?id=com.dev21ltd.satstack](https://play.google.com/store/apps/details?id=com.dev21ltd.satstack)
- **GitHub Releases:** https://github.com/dev21Ltd/satstack/releases
- **Source:** clone this repo and run with Flutter
- iOS / App Store is not maintained in this tree

## 🚀 Getting Started

### For Users
Android is the supported app. Get it on [Google Play](https://play.google.com/store/apps/details?id=com.dev21ltd.satstack) or watch [Releases](https://github.com/dev21Ltd/satstack/releases).


### For Developers
```bash
# Clone the repository
git clone https://github.com/dev21Ltd/satstack.git

# Install dependencies
cd satstack
flutter pub get

# Run the app
flutter run
```

## 🏗️ Project Structure
```
satstack/
├── lib/                    # App source
│   ├── main.dart
│   ├── home_screen.dart
│   ├── security_service.dart
│   ├── pin_crypto.dart
│   ├── hive_boxes.dart
│   ├── charts.dart
│   └── ...
├── android/                # Android (supported)
├── test/                   # Unit and widget tests
├── store/                  # Play Store "what's new" copy
├── CHANGELOG.md
├── PRIVACY.md
├── TERMS.md
└── CONTRIBUTING.md
```


## 🔐 Security & Privacy

### What We DON'T Do:
❌ No data collection

❌ No analytics or tracking

❌ No cloud storage

❌ No third-party sharing

### What We Do:
✅ Hive AES encryption of purchases, sales, and preferences

✅ PIN hashes (not plaintext) plus lockout

✅ PIN wraps the Hive key; storage is not opened until unlock

✅ Auto-lock closes encrypted boxes

JSON backups are password-encrypted. CSV and PDF exports are plaintext.

✅ Open source for auditability

## 🤝 Contributing
Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

Copyright © 2026 dev21Ltd. All rights reserved.

The SatStack name and logo are trademarks.

## 🔗 Links
- [GitHub Repository](https://github.com/dev21Ltd/satstack)
- [Changelog](CHANGELOG.md)
- [Privacy Policy](PRIVACY.md)
- [Terms of Service](TERMS.md)
- [Contributing](CONTRIBUTING.md)
- [Issue Tracker](https://github.com/dev21Ltd/satstack/issues)

## ⚠️ Disclaimer
SatStack is a portfolio tracking tool, not financial advice. Bitcoin is volatile - invest responsibly. Always secure your own private keys.

Made with ❤️ for the Bitcoin community.