# Contributing

Thanks for helping improve SatStack.

## Before you start
- Android is the supported mobile target. Web should keep compiling. iOS is not maintained in this tree.
- Do not commit signing secrets (`android/keystore.properties`, `*.jks`, Play service-account JSON).
- Do not add analytics, accounts, or cloud sync.

## How to contribute
1. Open an issue first for behaviour changes: https://github.com/dev21Ltd/satstack/issues
2. Fork and branch from `master`.
3. Keep changes focused. Match the existing Dart style.
4. Run tests:

```bash
flutter pub get
flutter test
```

5. Open a pull request against `master` and describe what changed and how you tested it.

## Security and privacy
Exported JSON, CSV, and PDF files are plaintext. Do not add copy that says otherwise. A PIN wraps local Hive storage; it is not full-phone encryption.
