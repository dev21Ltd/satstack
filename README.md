# SatStack 🔐

**Privacy-first Bitcoin Portfolio Tracker**

SatStack is an open source, privacy-focused Bitcoin portfolio tracker. All data stays on your device - no accounts, no tracking, no cloud storage.

## What's new in 1.0.2

- Stronger on-device security: hashed PIN, lockout, Hive boxes stay closed until unlock, Android backup off, screenshots blocked.
- Clearer portfolio chart (calendar dates, clusters, 3-year range) and trade-date currency conversion when history is available.
- JSON, CSV, and PDF exports are plaintext. The app warns that anyone with the file can read your trades.
- JSON backup is a simple file again (save / import, no extra password).

Full notes: [CHANGELOG.md](CHANGELOG.md)

## ✨ Features

- 🔒 **Privacy First**: No data collection, local-only storage
- 📊 **Portfolio Tracking**: Track Bitcoin purchases & sales
- 💰 **Multiple Currencies**: USD, GBP, EUR, CAD, AUD, JPY, CNY
- 📈 **Real-time Prices**: Live Bitcoin price updates
- 🔐 **Security**: PIN wraps the Hive AES key; boxes stay closed until unlock
- 📱 **Platforms**: Android is the supported mobile target in this tree. Web compiles. iOS is not maintained here.
- 📤 **Export**: CSV, PDF, JSON exports
- 🎨 **Themes**: Dark/Light mode

## 📱 Download

- [Google Play](#) (Coming soon)
- [App Store](#) (Coming soon)
- [Direct APK](#) (Check Releases)

## 🚀 Getting Started

### For Users
Download from your preferred app store and start tracking your Bitcoin portfolio privately.

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
├── lib/
│   ├── main.dart           # App entry point
│   ├── home_screen.dart    # Main dashboard
│   ├── app_state.dart      # State management
│   ├── models.dart         # Data models
│   ├── services.dart       # Storage & API
│   ├── security_service.dart # Encryption
│   ├── widgets.dart        # UI components
│   ├── charts.dart         # Charts
│   ├── purchase_calendar.dart
│   └── import_export_widget.dart
├── android/                # Android config
├── ios/                   # iOS config
├── pubspec.yaml           # Dependencies
└── README.md              # This file
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

JSON/CSV/PDF exports are plaintext files.

✅ Open source for auditability

## 🤝 Contributing
Contributions are welcome! Please read our Contributing Guidelines first.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

Copyright © 2026 dev21Ltd. All rights reserved.

The SatStack name and logo are trademarks.

## 🔗 Links
- [GitHub Repository](https://github.com/dev21Ltd/satstack)
- [Privacy Policy](PRIVACY.md)
- [Issue Tracker](https://github.com/dev21Ltd/satstack/issues)

## ⚠️ Disclaimer
SatStack is a portfolio tracking tool, not financial advice. Bitcoin is volatile - invest responsibly. Always secure your own private keys.

Made with ❤️ for the Bitcoin community.