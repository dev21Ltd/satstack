// main.dart - COMPLETE FIXED VERSION WITH BOTH LOGIN AND AUTO-LOCK
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'models.dart';
import 'home_screen.dart';
import 'app_state.dart';
import 'security_service.dart';
import 'widgets.dart';
import 'services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('Initializing Hive...');
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(PurchaseAdapter());
    Hive.registerAdapter(SaleAdapter());

    final securityService = SecurityService();
    final encryptionKey = await securityService.getEncryptionKey();

    print('Starting migration process...');
    await _migrateToEncryptedStorage(securityService, encryptionKey);

    // Open boxes with encryption
    print('Opening Hive boxes...');
    await Hive.openBox('btc_purchases', encryptionKey: encryptionKey);
    await Hive.openBox('btc_sales', encryptionKey: encryptionKey);
    await Hive.openBox('preferences');

    print('Hive initialization completed successfully');

    runApp(const MyApp());
  } catch (e) {
    print('Error during initialization: $e');
    // Fallback: try to initialize without migration
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(PurchaseAdapter());
      Hive.registerAdapter(SaleAdapter());

      await Hive.openBox('btc_purchases');
      await Hive.openBox('btc_sales');
      await Hive.openBox('preferences');

      runApp(const MyApp());
    } catch (fallbackError) {
      print('Fallback initialization also failed: $fallbackError');
      runApp(const ErrorApp());
    }
  }
}

Future<void> _migrateToEncryptedStorage(SecurityService securityService, Uint8List encryptionKey) async {
  final migrationCompleted = await securityService.isMigrationCompleted();

  if (!migrationCompleted) {
    print('Starting full migration process...');
    try {
      // Step 1: Migrate from unencrypted to encrypted storage
      final oldPurchasesBox = await Hive.openBox('btc_purchases');
      final oldSalesBox = await Hive.openBox('btc_sales');

      final newPurchasesBox = await Hive.openBox('btc_purchases', encryptionKey: encryptionKey);
      final newSalesBox = await Hive.openBox('btc_sales', encryptionKey: encryptionKey);

      // Migrate purchases if needed
      if (oldPurchasesBox.isNotEmpty && newPurchasesBox.isEmpty) {
        final purchases = oldPurchasesBox.get('purchases', defaultValue: []);
        if (purchases.isNotEmpty) {
          await newPurchasesBox.put('purchases', purchases);
          print('Migrated ${purchases.length} purchases to encrypted storage');
        }
      }

      // Migrate sales if needed
      if (oldSalesBox.isNotEmpty && newSalesBox.isEmpty) {
        final sales = oldSalesBox.get('sales', defaultValue: []);
        if (sales.isNotEmpty) {
          await newSalesBox.put('sales', sales);
          print('Migrated ${sales.length} sales to encrypted storage');
        }
      }

      // Close old boxes
      await oldPurchasesBox.close();
      await oldSalesBox.close();

      print('Encryption migration completed successfully');

    } catch (e) {
      print('Error during encryption migration: $e');
      // Continue with sales format migration even if encryption migration fails
    }
  } else {
    print('Encryption migration already completed');
  }

  // Step 2: Always run sales format migration (even if encryption migration was already done)
  try {
    print('Checking sales format migration...');
    final storageService = StorageService();
    await storageService.migrateSalesToNewFormat();
    print('Sales format migration check completed');
  } catch (e) {
    print('Sales format migration check failed: $e');
    // Don't throw here - we want the app to start even if migration fails
  }

  // Mark migration as completed
  try {
    await securityService.setMigrationCompleted();
    print('Migration process marked as completed');
  } catch (e) {
    print('Error setting migration completed flag: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const Color bitcoinOrange = Color(0xFFF7931A);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SatStack',
            theme: appState.isDarkMode
                ? ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: bitcoinOrange,
              ),
              cardColor: const Color(0xFF1E1E1E),
              textTheme: TextTheme(
                bodyLarge: TextStyle(fontSize: 16.0),
                bodyMedium: TextStyle(fontSize: 14.0),
                titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
                labelLarge: TextStyle(fontSize: 14.0),
              ),
            )
                : ThemeData.light().copyWith(
              scaffoldBackgroundColor: Colors.grey[100],
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: bitcoinOrange,
              ),
              cardColor: Colors.grey[200],
              textTheme: TextTheme(
                bodyLarge: TextStyle(fontSize: 16.0),
                bodyMedium: TextStyle(fontSize: 14.0),
                titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
                labelLarge: TextStyle(fontSize: 14.0),
              ),
            ),
            home: const AppStartupScreen(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaleFactor: mediaQuery.textScaleFactor.clamp(0.8, 1.2).toDouble(),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

// App Startup Screen that handles both loading and security
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({Key? key}) : super(key: key);

  @override
  _AppStartupScreenState createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> with SingleTickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  String _securityType = SecurityService.noSecurity;
  bool _isLoading = true;
  bool _isAppReady = false;
  bool _showLoadingScreen = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller immediately
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation immediately
    _animationController.forward();

    // Start app initialization
    _initializeApp();

    // Add a safety timer in case something goes wrong
    Timer(const Duration(seconds: 10), () {
      if (mounted && _showLoadingScreen) {
        print('Safety timer triggered - forcing app transition');
        setState(() {
          _isLoading = false;
          _isAppReady = true;
          _showLoadingScreen = false;
        });
      }
    });
  }

  void _initializeApp() async {
    try {
      // Check security type first
      _securityType = await _securityService.getSecurityType();
      print('Security type detected: $_securityType');

      // Always show loading screen for at least 5 seconds for good UX
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Start a timer to ensure minimum loading time
          _loadingTimer = Timer(const Duration(milliseconds: 5000), () {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isAppReady = true;
                _showLoadingScreen = false;
              });
            }
          });
        }
      });
    } catch (e) {
      print('Error during app initialization: $e');
      if (mounted) {
        // Still show minimum loading time even on error
        Timer(const Duration(milliseconds: 5000), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAppReady = true;
              _showLoadingScreen = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If still showing loading screen
    if (_showLoadingScreen) {
      return _buildEnhancedLoadingScreen();
    }

    // If app is ready, show the main app with proper security flow
    if (_isAppReady) {
      return Consumer<AppState>(
        builder: (context, appState, child) {
          // Show login screen only if security is enabled
          if (_securityType != SecurityService.noSecurity) {
            return LoginScreen(
              isDarkMode: appState.isDarkMode,
              child: AutoLockWrapper(
                isDarkMode: appState.isDarkMode,
                child: const HomeScreen(),
              ),
            );
          } else {
            // No security, go directly to app
            return AutoLockWrapper(
              isDarkMode: appState.isDarkMode,
              child: const HomeScreen(),
            );
          }
        },
      );
    }

    // This should not happen, but as fallback
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFFF7931A)),
      ),
    );
  }

  Widget _buildEnhancedLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      Colors.black,
                      const Color(0xFF121212),
                      Colors.black,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Bitcoin logo with glow effect
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF7931A).withOpacity(_progressAnimation.value * 0.5),
                                blurRadius: 30 + (30 * _progressAnimation.value),
                                spreadRadius: 5 + (5 * _progressAnimation.value),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ring
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF7931A).withOpacity(0.3 + (0.5 * _progressAnimation.value)),
                                    width: 2,
                                  ),
                                ),
                              ),

                              // Bitcoin symbol
                              const Icon(
                                Icons.account_balance_wallet,
                                size: 80,
                                color: Color(0xFFF7931A),
                              ),

                              // Rotating rings
                              if (_progressAnimation.value > 0.3)
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFF7931A).withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Transform.rotate(
                                    angle: _progressAnimation.value * 2 * 3.14159,
                                    child: CustomPaint(
                                      painter: _DashedCirclePainter(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // App title with animation
                        Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFF7931A),
                                  ],
                                  stops: [0.0, _progressAnimation.value],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'SatStack',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'YOUR BITCOIN JOURNEY',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF7931A),
                                letterSpacing: 4.0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // Animated progress bar
                        Container(
                          width: 250,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 250 * _progressAnimation.value,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF7931A),
                                          Color(0xFFFFB366),
                                          Color(0xFFF7931A),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF7931A).withOpacity(0.5),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Loading text with dynamic content
                        _buildLoadingText(),

                        const SizedBox(height: 40),

                        // Security status
                        if (_securityType != SecurityService.noSecurity)
                          _buildSecurityStatus(),

                        const SizedBox(height: 30),

                        // Features list that appears gradually
                        if (_progressAnimation.value > 0.6)
                          AnimatedOpacity(
                            opacity: (_progressAnimation.value - 0.6) / 0.4,
                            duration: const Duration(milliseconds: 500),
                            child: _buildFeaturesList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Particles in background
          if (_progressAnimation.value > 0.2)
            _buildBackgroundParticles(),
        ],
      ),
    );
  }

  Widget _buildLoadingText() {
    String text;
    if (_progressAnimation.value < 0.2) {
      text = 'INITIALIZING APP...';
    } else if (_progressAnimation.value < 0.4) {
      text = 'LOADING SECURE STORAGE...';
    } else if (_progressAnimation.value < 0.6) {
      text = 'LOADING PORTFOLIO DATA...';
    } else if (_progressAnimation.value < 0.8) {
      text = 'CONNECTING TO BLOCKCHAIN...';
    } else if (_progressAnimation.value < 0.9) {
      text = 'READY TO STACK SATS...';
    } else {
      text = _securityType == SecurityService.noSecurity ? 'LAUNCHING APP...' : 'PREPARING SECURITY...';
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF7931A),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSecurityStatus() {
    String statusText;
    Color statusColor;

    if (_securityType == SecurityService.noSecurity) {
      statusText = 'APP IS UNLOCKED';
      statusColor = Colors.green;
    } else if (_securityType == SecurityService.pinSecurity) {
      statusText = 'PIN SECURITY ENABLED';
      statusColor = Colors.orange;
    } else {
      statusText = 'SECURED';
      statusColor = const Color(0xFFF7931A);
    }

    return AnimatedOpacity(
      opacity: _progressAnimation.value > 0.4 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _securityType == SecurityService.noSecurity ? Icons.lock_open : Icons.security,
              size: 16,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.security, 'title': 'Sovereign Security', 'subtitle': 'Self-custody encryption'},
      {'icon': Icons.trending_up, 'title': 'Real-Time Tracking', 'subtitle': 'Live Bitcoin prices'},
      {'icon': Icons.analytics, 'title': 'Portfolio Analytics', 'subtitle': 'Advanced insights'},
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                feature['icon'] as IconData,
                size: 16,
                color: const Color(0xFFF7931A),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    feature['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundParticles() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(animationValue: _progressAnimation.value),
          );
        },
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF7931A).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const dashWidth = 4.0;
    const dashSpace = 6.0;
    const double startAngle = 0;
    const sweepAngle = 2 * 3.14159;

    double currentAngle = startAngle;
    const double radius = 65;

    while (currentAngle < startAngle + sweepAngle) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: radius),
        currentAngle,
        dashWidth / radius,
        false,
        paint,
      );
      currentAngle += dashWidth / radius + dashSpace / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticlePainter extends CustomPainter {
  final double animationValue;

  _ParticlePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final particleCount = 30;
    final radius = 1.5;

    for (int i = 0; i < particleCount; i++) {
      final progress = (animationValue + i / particleCount) % 1.0;
      final x = size.width * progress;
      final y = size.height * (0.3 + 0.4 * (i % 2));

      final paint = Paint()
        ..color = const Color(0xFFF7931A).withOpacity(0.1 * (1 - progress))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

// FIXED: AutoLockWrapper - ONLY locks when app goes to background for 2+ minutes
// This solves the double authentication issue
class AutoLockWrapper extends StatefulWidget {
  final bool isDarkMode;
  final Widget child;

  const AutoLockWrapper({
    Key? key,
    required this.isDarkMode,
    required this.child,
  }) : super(key: key);

  @override
  _AutoLockWrapperState createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends State<AutoLockWrapper> with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  String _securityType = SecurityService.noSecurity;
  bool _isLocked = false;
  bool _appInBackground = false;
  bool _showRecovery = false;
  bool _obscurePin = true;
  final TextEditingController _recoveryAnswerController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  Timer? _lockTimer;
  DateTime? _backgroundStartTime;

  // NEW: Track if user has already authenticated in this session
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _recoveryAnswerController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadSecuritySettings() async {
    final type = await _securityService.getSecurityType();
    setState(() {
      _securityType = type;
      // IMPORTANT: Only lock if app is coming from background AND user hasn't already authenticated
      // This prevents locking immediately when app starts
      _isLocked = false; // Start unlocked
      _obscurePin = true;
    });
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    // Start a timer for 2 minutes of inactivity in foreground
    _lockTimer = Timer(const Duration(minutes: 2), () {
      if (_securityType != SecurityService.noSecurity && !_isLocked) {
        setState(() {
          _isLocked = true;
          _obscurePin = true;
        });
        print('Auto-lock activated after 2 minutes of inactivity');
      }
    });
  }

  void _stopLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  void _handleUserInteraction() {
    if (_lockTimer != null) {
      _startLockTimer(); // Reset the timer
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _stopLockTimer(); // Stop foreground timer
        _backgroundStartTime = DateTime.now();
        if (_securityType != SecurityService.noSecurity && !_appInBackground) {
          setState(() {
            _appInBackground = true;
          });
          // Start background countdown - lock after 2 minutes in background
          Timer(const Duration(minutes: 2), () {
            if (_appInBackground && _securityType != SecurityService.noSecurity && !_isLocked) {
              setState(() {
                _isLocked = true;
                _obscurePin = true;
              });
              print('Auto-lock activated after 2 minutes in background');
            }
          });
        }
        break;

      case AppLifecycleState.resumed:
        if (_appInBackground) {
          setState(() {
            _appInBackground = false;
          });

          // Check if app was in background for more than 2 minutes
          if (_backgroundStartTime != null) {
            final backgroundDuration = DateTime.now().difference(_backgroundStartTime!);
            if (backgroundDuration.inMinutes >= 2 && _securityType != SecurityService.noSecurity && !_isLocked) {
              setState(() {
                _isLocked = true;
                _obscurePin = true;
              });
              print('Auto-lock activated after returning from background (${backgroundDuration.inMinutes}m)');
            } else if (!_isLocked) {
              // If not locked, start the foreground timer
              _startLockTimer();
            }
          } else if (!_isLocked) {
            // If no background time recorded, start foreground timer
            _startLockTimer();
          }
        }
        break;

      case AppLifecycleState.detached:
        _stopLockTimer();
        break;
    }
  }

  void _unlockApp() {
    setState(() {
      _isLocked = false;
      _obscurePin = true;
      _pinController.clear();
      _hasAuthenticated = true; // Mark as authenticated
    });
    // Start the lock timer after unlocking
    if (_securityType != SecurityService.noSecurity) {
      _startLockTimer();
    }
  }

  Future<void> _resetSecurity() async {
    final question = await _securityService.getBackupQuestion();
    if (question == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No recovery question set'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_recoveryAnswerController.text.toLowerCase() == question['answer']) {
      await _securityService.clearSecurityData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Security reset successfully'),
        backgroundColor: Colors.green,
      ));
      setState(() {
        _showRecovery = false;
        _securityType = SecurityService.noSecurity;
        _isLocked = false;
        _obscurePin = true;
        _pinController.clear();
        _recoveryAnswerController.clear();
      });
      _stopLockTimer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Incorrect answer'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user has already authenticated via LoginScreen, just pass through
    // This prevents double authentication
    if (_securityType == SecurityService.noSecurity) {
      return widget.child;
    }

    // Show recovery screen if needed
    if (_showRecovery) {
      return _buildRecoveryScreen();
    }

    // Show lock screen only if locked
    if (_isLocked) {
      return _buildLockScreen();
    }

    // If not locked, show the main app with interaction tracking
    return GestureDetector(
      onTap: _handleUserInteraction,
      onPanDown: (_) => _handleUserInteraction(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }

  Widget _buildLockScreen() {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7931A).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF7931A),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 60,
                    color: const Color(0xFFF7931A),
                  ),
                ),

                const SizedBox(height: 30),

                // App title
                Text(
                  'SatStack',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Auto-Locked',
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 30),

                // Security type specific content
                if (_securityType == SecurityService.pinSecurity)
                  _buildPinUnlock(textColor, cardColor)
                else
                  _buildGenericUnlock(textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinUnlock(Color textColor, Color cardColor) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Enter PIN to Unlock',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),

          const SizedBox(height: 20),

          // PIN input field
          Container(
            width: 200,
            height: 60,
            child: TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              enableInteractiveSelection: true,
              enableSuggestions: false,
              autocorrect: false,
              style: TextStyle(
                fontSize: 24,
                color: textColor,
                height: 1.0,
              ),
              decoration: InputDecoration(
                hintText: 'Enter PIN',
                hintStyle: TextStyle(
                  color: textColor.withOpacity(0.5),
                  fontSize: 18,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: textColor.withOpacity(0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePin = !_obscurePin;
                    });
                  },
                ),
              ),
              cursorColor: const Color(0xFFF7931A),
              cursorWidth: 2.0,
              cursorHeight: 24.0,
              cursorRadius: const Radius.circular(1),
              onSubmitted: (value) => _checkPin(_pinController.text),
            ),
          ),

          const SizedBox(height: 20),

          // Unlock button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _checkPin(_pinController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Unlock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Forgot PIN button
          TextButton(
            onPressed: () {
              setState(() {
                _showRecovery = true;
                _obscurePin = true;
              });
            },
            child: Text(
              'Forgot your PIN?',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericUnlock(Color textColor) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            size: 40,
            color: const Color(0xFFF7931A),
          ),

          const SizedBox(height: 16),

          Text(
            'App Secured',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Your StackTrack app is locked for security',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _unlockApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryScreen() {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Recovery icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7931A).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF7931A),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.security,
                    size: 60,
                    color: const Color(0xFFF7931A),
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  'Reset Security',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 20),

                FutureBuilder<Map<String, String>?>(
                  future: _securityService.getBackupQuestion(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator(color: const Color(0xFFF7931A));
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return Container(
                        width: 280,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Recovery Option',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No security question has been set up. You cannot reset your PIN.',
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => setState(() {
                                  _showRecovery = false;
                                  _obscurePin = true;
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF7931A),
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Back to Login'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final question = snapshot.data!;
                    return Container(
                      width: 280,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Security Question',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            question['question']!,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: _recoveryAnswerController,
                            decoration: InputDecoration(
                              labelText: 'Your answer',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                            ),
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _resetSecurity,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF7931A),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              ),
                              child: const Text('Reset Security'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showRecovery = false;
                                _obscurePin = true;
                                _recoveryAnswerController.clear();
                              });
                            },
                            child: Text(
                              'Back to Login',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkPin(String enteredPin) async {
    final storedPin = await _securityService.getPinCode();
    if (enteredPin == storedPin) {
      _unlockApp();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid PIN'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// Fallback app in case of initialization errors
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 20),
                Text(
                  'App Initialization Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'There was a problem starting the app. This might be due to data corruption or storage issues.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    runApp(const MyApp());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Try Again'),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await _clearAppDataAndRestart();
                  },
                  child: Text(
                    'Reset App Data',
                    style: TextStyle(
                      color: Colors.red[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAppDataAndRestart() async {
    try {
      await Hive.close();
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
      runApp(const MyApp());
    } catch (e) {
      print('Error clearing app data: $e');
    }
  }
}