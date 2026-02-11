// donation_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:clipboard/clipboard.dart';

class DonationWidget {
  static void showDonationDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => DonationDialog(isDarkMode: isDarkMode),
    );
  }
}

class DonationDialog extends StatefulWidget {
  final bool isDarkMode;

  const DonationDialog({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  _DonationDialogState createState() => _DonationDialogState();
}

class _DonationDialogState extends State<DonationDialog> with SingleTickerProviderStateMixin {
  final String lightningAddress = "dev.21.ltd@walletofsatoshi.com";
  final String onChainAddress = "bc1qk6evnqxp7a49plvu9jjk8k8vnhmuyhus0dqvg0fnvlyyw8lcn2ps3d3z4x";
  final String lnurl = "lnurl1dp68gurn8ghj7ampd3kx2ar0veekzar0wd5xjtnrdakj7tnhv4kxctttdehhwm30d3h82unvwqhkgetk9cerztnvw3jqy0gu4f";

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 350;

    return Dialog(
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
          maxWidth: screenWidth * 0.95,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Support Development',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(height: 16),

              // Tab bar with adjusted styling for small screens
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    color: const Color(0xFFF7931A),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  labelStyle: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Lightning'),
                    Tab(text: 'QR Code'),
                    Tab(text: 'On-Chain'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab content with flexible height
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLightningTab(isSmallScreen),
                    _buildQrTab(isSmallScreen),
                    _buildOnChainTab(isSmallScreen),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLightningTab(bool isSmallScreen) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAddressTile(
            icon: Icons.bolt,
            title: 'Lightning Address',
            address: lightningAddress,
            isSmallScreen: isSmallScreen,
          ),
          const SizedBox(height: 12),
          _buildAddressTile(
            icon: Icons.link,
            title: 'LNURL',
            address: lnurl,
            isTruncated: true,
            isSmallScreen: isSmallScreen,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse('lightning:$lightningAddress'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              child: Text(
                'Open in Wallet',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildThankYouNote(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildQrTab(bool isSmallScreen) {
    final qrSize = isSmallScreen ? 150.0 : 200.0;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrImageView(
            data: lnurl,
            version: QrVersions.auto,
            size: qrSize,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Scan to donate via LNURL',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: isSmallScreen ? 14 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildThankYouNote(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildOnChainTab(bool isSmallScreen) {
    final qrSize = isSmallScreen ? 150.0 : 200.0;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: onChainAddress,
            version: QrVersions.auto,
            size: qrSize,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SelectableText(
              onChainAddress,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: isSmallScreen ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FlutterClipboard.copy(onChainAddress).then((value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Address copied to clipboard'),
                      backgroundColor: const Color(0xFFF7931A),
                    ),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              child: Text(
                'Copy Address',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildThankYouNote(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildAddressTile({
    required IconData icon,
    required String title,
    required String address,
    bool isTruncated = false,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF7931A), size: isSmallScreen ? 20 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTruncated && address.length > 20
                      ? '${address.substring(0, 20)}...'
                      : address,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.content_copy,
              size: isSmallScreen ? 18 : 20,
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              FlutterClipboard.copy(address).then((value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title copied to clipboard'),
                    backgroundColor: const Color(0xFFF7931A),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThankYouNote(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color(0xFFF7931A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Thank you for choosing SatStack to map your journey towards financial sovereignty. '
            'As a solo developer building for the Bitcoin community, '
            'I created this app to empower users to track their stacking progress. '
            'Every Satoshi helps keep this project free, private, and constantly improving. '
            'Thank you for supporting independent Bitcoin development.',
        style: TextStyle(
          color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[900],
          fontSize: isSmallScreen ? 12 : 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}