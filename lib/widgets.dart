// widgets.dart
import 'package:flutter/material.dart';
import 'constants.dart';
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: TimeRange.values.map((range) => _buildTimeRangeButton(range)).toList(),
    );
  }

  Widget _buildTimeRangeButton(TimeRange range) {
    bool isSel = selectedTimeRange == range;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSel ? bitcoinOrange : isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: isRefreshing ? null : () => onTimeRangeChanged(range),
      child: Text(
        timeRangeToString(range),
        style: TextStyle(color: isSel ? Colors.black : isDarkMode ? Colors.white : Colors.black),
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
  String _selectedSecurityType = SecurityService.noSecurity;
  bool _isSettingUp = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final type = await _securityService.getSecurityType();
    setState(() => _selectedSecurityType = type);
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
              Text('Security Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            ]),
            const SizedBox(height: 20),
            _buildSecurityTypeDropdown(textColor, cardColor, borderColor),
            if (_selectedSecurityType == SecurityService.pinSecurity && _isSettingUp)
              _buildPinSetup(textColor, cardColor),
            if (_selectedSecurityType != SecurityService.noSecurity && _isSettingUp)
              _buildBackupQuestion(textColor, cardColor),
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
                  onPressed: _saveSecuritySettings,
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

  Widget _buildSecurityTypeDropdown(Color textColor, Color cardColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
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
        Text('Set PIN Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _pinController,
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          enableInteractiveSelection: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Enter 4-digit PIN',
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
          maxLength: 4,
          enableInteractiveSelection: true,
          enableSuggestions: false,
          autocorrect: false,
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
        Text('Security Question (For recovery)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _questionController,
          decoration: InputDecoration(labelText: 'Security question', border: const OutlineInputBorder(), filled: true, fillColor: cardColor),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(labelText: 'Answer', border: const OutlineInputBorder(), filled: true, fillColor: cardColor),
          style: TextStyle(color: textColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _saveSecuritySettings() async {
    if (_selectedSecurityType == SecurityService.pinSecurity && _isSettingUp) {
      if (_pinController.text.length != 4) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match')));
        return;
      }
      await _securityService.setPinCode(_pinController.text);
    }

    if (_selectedSecurityType != SecurityService.noSecurity && _questionController.text.isNotEmpty && _answerController.text.isNotEmpty) {
      await _securityService.setBackupQuestion(_questionController.text, _answerController.text);
    }

    await _securityService.setSecurityType(_selectedSecurityType);

    final securityStatus = _selectedSecurityType == SecurityService.noSecurity ? 'App is now unlocked' : 'App is now secured with PIN';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(securityStatus)));

    widget.onSecurityChanged?.call();
    Navigator.of(context).pop();
  }
}

class LoginScreen extends StatefulWidget {
  final bool isDarkMode;
  final Widget child;
  final VoidCallback? onSecurityReset;

  const LoginScreen({Key? key, required this.isDarkMode, required this.child, this.onSecurityReset}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final type = await _securityService.getSecurityType();
    setState(() {
      _securityType = type;
      _isUnlocked = type == SecurityService.noSecurity;
    });
  }

  Future<void> _authenticateWithPin() async {
    final storedPin = await _securityService.getPinCode();
    if (_pinController.text == storedPin) {
      setState(() => _isUnlocked = true);
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => widget.child));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN')));
    }
  }

  Future<void> _resetSecurity() async {
    final question = await _securityService.getBackupQuestion();
    if (question == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recovery question set')));
      return;
    }

    if (_recoveryAnswerController.text.toLowerCase() == question['answer']) {
      await _securityService.clearSecurityData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security reset successfully')));
      widget.onSecurityReset?.call();
      setState(() {
        _showRecovery = false;
        _securityType = SecurityService.noSecurity;
        _isUnlocked = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSecuritySettings());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect answer')));
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
                  FutureBuilder<Map<String, String>?>(
                    future: _securityService.getBackupQuestion(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return Column(
                        children: [
                          Text(snapshot.data!['question']!, style: TextStyle(fontSize: 18, color: textColor), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _recoveryAnswerController,
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
                Text(_isUnlocked ? 'Your app is now unlocked' : 'Please authenticate to continue',
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
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _authenticateWithPin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF7931A),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text('Unlock'),
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCurrencyButton(favoriteCurrency),
        _buildCurrencyButton(secondaryCurrency),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: isRefreshing ? null : () => onCurrencyChanged(currency),
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.currency_exchange, color: const Color(0xFFF7931A), size: 24),
            const SizedBox(width: 12),
            Text('Currency Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
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