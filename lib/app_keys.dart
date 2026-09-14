import 'package:flutter/material.dart';

/// Shared navigator key. Must be a single instance so StorageService
/// snackbars and MaterialApp share the same overlay.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
