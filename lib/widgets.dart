import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'pin_crypto.dart';
import 'security_service.dart';

class TimeRangeSelector extends StatelessWidget {
  final TimeRange selectedTimeRange;
  final Function(TimeRange) onTimeRangeChanged;
  final bool isDarkMode;
  final bool isRefreshing;

  const TimeRangeSelector({
    Key? key,
    required this.selectedTimeRange,
    required this.onTimeRangeChanged,
    required this.isDarkMode,
    required this.isRefreshing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TimeRange.values.map((range) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildTimeRangeButton(range),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeRangeButton(TimeRange range) {
    bool isSel = selectedTimeRange == range;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSel ? bitcoinOrange : isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: isRefreshing ? null : () => onTimeRangeChanged(range),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          timeRangeToString(range),
          style: TextStyle(color: isSel ? Colors.black : isDarkMode ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

class SecuritySettingsDialog extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onSecurityChanged;

  const SecuritySettingsDialog({Key? key, required this.isDarkMode, this.onSecurityChanged}) : super(key: key);

  @override
  _SecuritySettingsDialogState createState() => _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends State<SecuritySettingsDialog> {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _jsonBackupPasswordController = TextEditingController();
  final TextEditingController _jsonBackupConfirmController = TextEditingController();
  String _selectedSecurityType = SecurityService.noSecurity;
  bool _isSettingUp = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _obscureJsonBackup = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final type = await _securityService.getSecurityType();
    if (!mounted) return;
    setState(() {
      _selectedSecurityType = type;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _jsonBackupPasswordController.dispose();
    _jsonBackupConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade50;
    final borderColor = widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.security, color: const Color(0xFFF7931A), size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text('Security Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 16),
            _buildSectionLabel('App PIN', textColor),
            _buildSecurityTypeDropdown(textColor, cardColor, borderColor),
            if (_selectedSecurityType == SecurityService.pinSecurity && _isSettingUp)
              _buildPinSetup(textColor, cardColor),
            if (_selectedSecurityType != SecurityService.noSecurity && _isSettingUp)
              _buildBackupQuestion(textColor, cardColor),
            _buildSectionLabel('JSON password', textColor),
            _buildJsonBackupPassword(textColor, cardColor),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: textColor.withOpacity(0.7))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _saveSecuritySettings,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A), foregroundColor: Colors.black),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildSecurityTypeDropdown(Color textColor, Color cardColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: _selectedSecurityType,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: textColor, size: 24),
            items: [
              DropdownMenuItem(value: SecurityService.noSecurity, child: Text('No Security', style: TextStyle(color: textColor))),
              DropdownMenuItem(value: SecurityService.pinSecurity, child: Text('PIN Code', style: TextStyle(color: textColor))),
            ],
            onChanged: (String? newValue) => setState(() {
              _selectedSecurityType = newValue!;
              _isSettingUp = newValue != SecurityService.noSecurity;
              _obscurePin = true;
              _obscureConfirmPin = true;
            }),
            dropdownColor: widget.isDarkMode ? const Color(0xFF3D3D3D) : Colors.white,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPinSetup(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        TextField(
          controller: _pinController,
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          maxLength: pinMaxLength,
          enableInteractiveSelection: false,
          enableSuggestions: false,
          autocorrect: false,
          contextMenuBuilder: (context, state) => const SizedBox.shrink(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(pinMaxLength),
          ],
          decoration: InputDecoration(
            labelText: 'Enter 4-6 digit PIN',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cardColor,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePin ? Icons.visibility_off : Icons.visibility,
                color: textColor.withOpacity(0.6),
              ),
              onPressed: () {
                setState(() {
                  _obscurePin = !_obscurePin;
                });
              },
            ),
          ),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPinController,
          obscureText: _obscureConfirmPin,
          keyboardType: TextInputType.number,
          maxLength: pinMaxLength,
          enableInteractiveSelection: false,
          enableSuggestions: false,
          autocorrect: false,
          contextMenuBuilder: (context, state) => const SizedBox.shrink(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(pinMaxLength),
          ],
          decoration: InputDecoration(
            labelText: 'Confirm PIN',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cardColor,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                color: textColor.withOpacity(0.6),
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPin = !_obscureConfirmPin;
                });
              },
            ),
          ),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBackupQuestion(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PIN recovery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _questionController,
          decoration: InputDecoration(labelText: 'Security question', border: const OutlineInputBorder(), filled: true, fillColor: cardColor),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _answerController,
          obscureText: true,
          enableInteractiveSelection: false,
          enableSuggestions: false,
          autocorrect: false,
          contextMenuBuilder: (context, state) => const SizedBox.shrink(),
          decoration: InputDecoration(labelText: 'Answer', border: const OutlineInputBorder(), filled: true, fillColor: cardColor),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildJsonBackupPassword(Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encrypts JSON backups. Not the app PIN. After a reinstall, type this same password here, then import the file.',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _jsonBackupPasswordController,
          obscureText: _obscureJsonBackup,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(
            labelText: 'JSON password (min $backupMinPasswordLength characters)',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cardColor,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureJsonBackup ? Icons.visibility_off : Icons.visibility,
                color: textColor.withOpacity(0.6),
              ),
              onPressed: () => setState(() => _obscureJsonBackup = !_obscureJsonBackup),
            ),
          ),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _jsonBackupConfirmController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(
            labelText: 'Confirm JSON backup password',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cardColor,
          ),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _saveSecuritySettings() async {
    if (_saving) return;
    if (_selectedSecurityType == SecurityService.pinSecurity && _isSettingUp) {
      if (!PinCrypto.isValidPin(_pinController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PIN must be $pinMinLength–$pinMaxLength digits')),
        );
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match')));
        return;
      }
      if (_questionController.text.trim().isEmpty || _answerController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A recovery question and answer are required')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await Future.wait([
          _securityService.setPinCode(_pinController.text),
          _securityService.setBackupQuestion(
            _questionController.text,
            _answerController.text,
          ),
        ]);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', ''))),
        );
        return;
      }
    }

    if (!_saving) setState(() => _saving = true);

    await _securityService.setSecurityType(_selectedSecurityType);

    final jsonPassword = _jsonBackupPasswordController.text;
    if (jsonPassword.isNotEmpty) {
      if (jsonPassword != _jsonBackupConfirmController.text) {
        if (mounted) setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON backup passwords do not match')),
        );
        return;
      }
      try {
        await _securityService.setJsonBackupPassword(jsonPassword);
      } catch (e) {
        if (mounted) setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', ''))),
        );
        return;
      }
    }

    final jsonChanged = jsonPassword.isNotEmpty;
    final String securityStatus;
    if (jsonChanged && !_isSettingUp) {
      securityStatus = 'JSON password saved';
    } else if (_selectedSecurityType == SecurityService.noSecurity) {
      securityStatus = jsonChanged ? 'App unlocked. JSON password saved' : 'App is now unlocked';
    } else if (jsonChanged) {
      securityStatus = 'PIN and JSON password saved';
    } else {
      securityStatus = 'App is now secured with PIN';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(securityStatus)));

    widget.onSecurityChanged?.call();
    Navigator.of(context).pop();
  }
}

class LoginScreen extends StatefulWidget {
  final bool isDarkMode;
  final Widget child;
  final VoidCallback? onSecurityReset;
  final Future<void> Function()? onUnlocked;
  final Future<void> Function()? onWipeStorage;

  const LoginScreen({
    Key? key,
    required this.isDarkMode,
    required this.child,
    this.onSecurityReset,
    this.onUnlocked,
    this.onWipeStorage,
  }) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SecurityService _securityService = SecurityService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _recoveryAnswerController = TextEditingController();
  String _securityType = SecurityService.noSecurity;
  bool _showRecovery = false, _isUnlocked = false;
  bool _obscurePin = true;
  bool _lockedOut = false;
  bool _securityLoaded = false;
  bool _storageFailed = false;
  bool _unlocking = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final type = await _securityService.getSecurityType();
      if (!mounted) return;
      setState(() {
        _securityType = type;
        _isUnlocked = type == SecurityService.noSecurity;
        _securityLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _storageFailed = true);
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_unlocking || _lockedOut) return;
    setState(() {
      _unlocking = true;
      _authError = null;
    });
    final result = await _securityService.verifyPin(_pinController.text);
    if (result.success) {
      try {
        if (widget.onUnlocked != null) {
          await widget.onUnlocked!();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _unlocking = false;
          _authError = 'Could not open encrypted storage';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isUnlocked = true;
        _authError = null;
        _lockedOut = false;
        _unlocking = false;
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => widget.child));
    } else {
      if (!mounted) return;
      setState(() {
        _unlocking = false;
        _lockedOut = result.lockedOut;
        _authError = result.message;
      });
      _pinController.clear();
    }
  }

  Future<void> _resetSecurity() async {
    if (!await _securityService.hasBackupQuestion()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recovery question set')));
      return;
    }

    final result = await _securityService.verifyBackupAnswer(_recoveryAnswerController.text);
    if (result.success) {
      try {
        if (widget.onUnlocked != null) await widget.onUnlocked!();
      } catch (_) {}
      await _securityService.clearSecurityData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security reset successfully')));
      widget.onSecurityReset?.call();
      setState(() {
        _showRecovery = false;
        _securityType = SecurityService.noSecurity;
        _isUnlocked = true;
        _authError = null;
        _lockedOut = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSecuritySettings());
    } else {
      setState(() {
        _lockedOut = result.lockedOut;
        _authError = result.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => SecuritySettingsDialog(isDarkMode: widget.isDarkMode, onSecurityChanged: _loadSecuritySettings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;

    if (_storageFailed) {
      return SecureStorageErrorScreen(
        onRetry: () {
          setState(() => _storageFailed = false);
          _loadSecuritySettings();
        },
        onWipe: () async {
          if (widget.onWipeStorage != null) await widget.onWipeStorage!();
        },
      );
    }

    if (!_securityLoaded) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF7931A)),
        ),
      );
    }

    if (_securityType == SecurityService.noSecurity) return widget.child;

    if (_showRecovery) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Reset Security', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 20),
                  FutureBuilder<String?>(
                    future: _securityService.getBackupQuestionText(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return Text('No recovery question set', style: TextStyle(fontSize: 16, color: textColor), textAlign: TextAlign.center);
                      }
                      return Column(
                        children: [
                          Text(snapshot.data!, style: TextStyle(fontSize: 18, color: textColor), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _recoveryAnswerController,
                              obscureText: true,
                              enableInteractiveSelection: false,
                              enableSuggestions: false,
                              autocorrect: false,
                              contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                              decoration: InputDecoration(
                                hintText: 'Your answer',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: cardColor,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              ),
                              style: TextStyle(color: textColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _resetSecurity,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A), foregroundColor: Colors.black),
                    child: const Text('Reset Security'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showRecovery = false),
                    child: Text('Back to login', style: TextStyle(color: textColor)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 80, color: _isUnlocked ? Colors.green : const Color(0xFFF7931A)),
                const SizedBox(height: 20),
                Text(_isUnlocked ? 'App Unlocked' : 'Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 10),
                Text(
                    _unlocking
                        ? 'Unlocking…'
                        : (_isUnlocked ? 'Your app is now unlocked' : 'Please authenticate to continue'),
                    style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7))),
                const SizedBox(height: 30),
                if (_securityType == SecurityService.pinSecurity && !_isUnlocked) ..._buildPinInput(textColor, cardColor),
                if (_isUnlocked) ..._buildUnlockedUI(textColor),
                if (!_isUnlocked) _buildForgotPinButton(textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPinInput(Color textColor, Color cardColor) {
    return [
      Container(
        width: 200,
        height: 60,
        child: TextField(
          controller: _pinController,
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          maxLength: pinMaxLength,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          enableInteractiveSelection: false,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !_lockedOut && !_unlocking,
          contextMenuBuilder: (context, state) => const SizedBox.shrink(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(pinMaxLength),
          ],
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
            fillColor: cardColor,
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
          onSubmitted: (value) => _authenticateWithPin(),
        ),
      ),
      if (_authError != null) ...[
        const SizedBox(height: 12),
        Text(
          _authError!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: (_lockedOut || _unlocking) ? null : _authenticateWithPin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF7931A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: _unlocking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Text('Unlock'),
      ),
    ];
  }

  List<Widget> _buildUnlockedUI(Color textColor) {
    return [
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _showSecuritySettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF7931A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text('Security Settings'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => widget.child)),
        child: Text('Continue to App', style: TextStyle(color: textColor.withOpacity(0.7))),
      ),
    ];
  }

  Widget _buildForgotPinButton(Color textColor) {
    return TextButton(
      onPressed: () => setState(() => _showRecovery = true),
      child: Text('Forgot your PIN?', style: TextStyle(color: textColor.withOpacity(0.7))),
    );
  }
}

class CompactCurrencyDisplay extends StatelessWidget {
  final Currency favoriteCurrency;
  final Currency secondaryCurrency;
  final Currency selectedCurrency;
  final Map<Currency, double> prices;
  final Function(Currency) onCurrencyChanged;
  final Function() onSettingsPressed;
  final bool isRefreshing;
  final bool isDarkMode;

  const CompactCurrencyDisplay({
    Key? key,
    required this.favoriteCurrency,
    required this.secondaryCurrency,
    required this.selectedCurrency,
    required this.prices,
    required this.onCurrencyChanged,
    required this.onSettingsPressed,
    required this.isRefreshing,
    required this.isDarkMode,
  }) : super(key: key);

  String _getSymbol(Currency currency) {
    switch (currency) {
      case Currency.USD: return '\$';
      case Currency.GBP: return '£';
      case Currency.EUR: return '€';
      case Currency.CAD: return 'C\$';
      case Currency.AUD: return 'A\$';
      case Currency.JPY: return '¥';
      case Currency.CNY: return '¥';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildCurrencyButton(favoriteCurrency)),
        const SizedBox(width: 8),
        Expanded(child: _buildCurrencyButton(secondaryCurrency)),
        IconButton(
          icon: const Icon(Icons.more_horiz, size: 28),
          onPressed: onSettingsPressed,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ],
    );
  }

  Widget _buildCurrencyButton(Currency currency) {
    final price = prices[currency] ?? 0.0;
    final symbol = _getSymbol(currency);
    final isSelected = currency == selectedCurrency;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
      ]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? bitcoinOrange : isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isSelected ? Colors.black : (isDarkMode ? Colors.white : Colors.black),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: isRefreshing ? null : () => onCurrencyChanged(currency),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(width: 6),
              Text(currencyToString(currency),
                  style: TextStyle(fontSize: 16, color: isSelected ? Colors.black : isDarkMode ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 6),
              Text(price == 0 ? '-' : price.toStringAsFixed(0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class CurrencySettingsDialog extends StatefulWidget {
  final Currency favoriteCurrency;
  final Currency secondaryCurrency;
  final Denomination denomination;
  final Function(Currency, Currency, Denomination) onSave;
  final bool isDarkMode;

  const CurrencySettingsDialog({
    Key? key,
    required this.favoriteCurrency,
    required this.secondaryCurrency,
    required this.denomination,
    required this.onSave,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _CurrencySettingsDialogState createState() => _CurrencySettingsDialogState();
}

class _CurrencySettingsDialogState extends State<CurrencySettingsDialog> {
  late Currency _tempFavorite, _tempSecondary;
  late Denomination _tempDenomination;

  @override
  void initState() {
    super.initState();
    _tempFavorite = widget.favoriteCurrency;
    _tempSecondary = widget.secondaryCurrency;
    _tempDenomination = widget.denomination;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade50;
    final borderColor = widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.currency_exchange, color: const Color(0xFFF7931A), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Currency Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 20),
          _buildDropdown('Favorite Currency', _tempFavorite, textColor, cardColor, borderColor, (newValue) {
            setState(() {
              _tempFavorite = newValue!;
              if (_tempSecondary == _tempFavorite) {
                _tempSecondary = Currency.values.firstWhere((c) => c != _tempFavorite, orElse: () => Currency.USD);
              }
            });
          }),
          const SizedBox(height: 16),
          _buildDropdown('Secondary Currency', _tempSecondary, textColor, cardColor, borderColor, (newValue) {
            setState(() => _tempSecondary = newValue!);
          }, filter: _tempFavorite),
          const SizedBox(height: 16),
          _buildDenominationSelector(textColor),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: textColor.withOpacity(0.7))),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.onSave(_tempFavorite, _tempSecondary, _tempDenomination);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A), foregroundColor: Colors.black),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, Currency value, Color textColor, Color cardColor, Color borderColor,
      ValueChanged<Currency?> onChanged, {Currency? filter}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<Currency>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: textColor, size: 24),
            items: Currency.values.where((currency) => currency != filter).map((Currency currency) {
              return DropdownMenuItem<Currency>(
                value: currency,
                child: Text(currencyToString(currency), style: TextStyle(fontSize: 14, color: textColor)),
              );
            }).toList(),
            onChanged: onChanged,
            dropdownColor: widget.isDarkMode ? const Color(0xFF3D3D3D) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDenominationSelector(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display Units', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('BTC'),
                selected: _tempDenomination == Denomination.BTC,
                onSelected: (selected) => setState(() => _tempDenomination = Denomination.BTC),
                selectedColor: const Color(0xFFF7931A),
                labelStyle: TextStyle(color: _tempDenomination == Denomination.BTC ? Colors.black : textColor),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Sats'),
                selected: _tempDenomination == Denomination.SATS,
                onSelected: (selected) => setState(() => _tempDenomination = Denomination.SATS),
                selectedColor: const Color(0xFFF7931A),
                labelStyle: TextStyle(color: _tempDenomination == Denomination.SATS ? Colors.black : textColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SecureStorageErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onWipe;

  const SecureStorageErrorScreen({
    super.key,
    required this.onRetry,
    required this.onWipe,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, color: Color(0xFFF7931A), size: 56),
            const SizedBox(height: 20),
            const Text(
              'Secure storage is unreadable',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'The device keystore could not be opened. Retry, or wipe local SatStack data and start over. Wiping cannot be undone.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931A),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onWipe,
              child: const Text('Wipe local data', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}