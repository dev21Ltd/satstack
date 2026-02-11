// import_export_widget.dart - COMPACT VERSION WITH UPDATED GUIDES
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'services.dart';
import 'dart:io'; // ADD THIS IMPORT
import 'dart:typed_data';
import 'app_state.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(',', '');
    if (int.tryParse(newText) == null) return oldValue;
    newText = NumberFormat().format(int.parse(newText));
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

class ImportExportDialog extends StatefulWidget {
  final bool isDarkMode;
  final Function(BuildContext) onSavePdfReport;
  final Function(BuildContext) onSaveCsvReport;
  final Function(BuildContext) onSaveJsonBackup;
  final Function(BuildContext, String) onShareFile;
  final Function(BuildContext, String) onImportFromFile;
  final Function(BuildContext) onShowJsonImportDialog;
  final Function(String, String) onOperationComplete;

  const ImportExportDialog({Key? key, required this.isDarkMode, required this.onSavePdfReport, required this.onSaveCsvReport, required this.onSaveJsonBackup, required this.onShareFile, required this.onImportFromFile, required this.onShowJsonImportDialog, required this.onOperationComplete}) : super(key: key);

  @override
  _ImportExportDialogState createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<ImportExportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasExported = false;
  String? _lastExportPath;
  List<Map<String, dynamic>> _exportedFiles = [];
  bool _loadingFiles = false;
  bool _isSelecting = false;
  Set<String> _selectedFiles = Set<String>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadExportedFiles();
  }

  Future<void> _loadExportedFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final storageService = StorageService();
      final files = await storageService.getExportedFiles();
      setState(() => _exportedFiles = files);
    } catch (e) { print('Error loading files: $e'); }
    finally { setState(() => _loadingFiles = false); }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleExportComplete(String filePath, String operationType) {
    setState(() { _hasExported = true; _lastExportPath = filePath; });
    if (operationType == 'PDF Export' || operationType == 'CSV Export' || operationType == 'JSON Export') {
      widget.onOperationComplete(operationType, filePath);
    }
    _loadExportedFiles();
  }

  void _toggleSelection() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) _selectedFiles.clear();
    });
  }

  void _selectAll() {
    setState(() { _selectedFiles = Set.from(_exportedFiles.map((file) => file['path'] as String)); });
  }

  void _clearSelection() { setState(() { _selectedFiles.clear(); }); }

  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFiles.contains(filePath)) _selectedFiles.remove(filePath);
      else _selectedFiles.add(filePath);
    });
  }

  bool _isFileSelected(String filePath) { return _selectedFiles.contains(filePath); }

  Future<void> _batchDeleteFiles() async {
    if (_selectedFiles.isEmpty) return;
    bool? confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete Files'), content: Text('Are you sure you want to delete ${_selectedFiles.length} file(s)?'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))],
    ));
    if (confirm == true) {
      try {
        final storageService = StorageService(); int successCount = 0;
        for (String filePath in _selectedFiles) {
          try { await storageService.deleteExportedFile(filePath); successCount++; }
          catch (e) { print('Failed to delete file $filePath: $e'); }
        }
        await _loadExportedFiles(); _clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully deleted $successCount file(s)'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete files: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _batchShareFiles() async {
    if (_selectedFiles.isEmpty) return;
    try {
      final storageService = StorageService(); List<XFile> filesToShare = [];
      for (String filePath in _selectedFiles) filesToShare.add(XFile(filePath));
      await Share.shareXFiles(filesToShare, text: 'SatStack Export - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share files: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _batchSaveFiles() async {
    if (_selectedFiles.isEmpty) return;
    try {
      final storageService = StorageService();
      int successCount = 0;
      for (String filePath in _selectedFiles) {
        try {
          final file = _exportedFiles.firstWhere((f) => f['path'] == filePath);
          final fileName = file['name'] as String;
          final fileBytes = await File(filePath).readAsBytes();
          await storageService.saveFileToLocation(fileBytes, fileName);
          successCount++;
        } catch (e) {
          print('Failed to save file $filePath: $e');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Successfully saved $successCount file(s)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4)
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save files: ${e.toString()}'),
          backgroundColor: Colors.red
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height, screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 350;
    return Dialog(
      backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: screenHeight * 0.8, maxWidth: screenWidth * 0.95),
        child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.import_export, color: const Color(0xFFF7931A), size: isSmallScreen ? 20 : 24),
            const SizedBox(width: 8),
            Text('Import & Export', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 18 : 20)),
          ]),
          const SizedBox(height: 16),
          Container(decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8.0)),
            child: TabBar(controller: _tabController, indicator: BoxDecoration(borderRadius: BorderRadius.circular(8.0), color: const Color(0xFFF7931A)),
              labelColor: Colors.black, unselectedLabelColor: widget.isDarkMode ? Colors.white70 : Colors.black54,
              labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14), indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [Tab(text: 'Export'), Tab(text: 'Import'), Tab(text: 'My Files'), Tab(text: 'Guide')],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: TabBarView(controller: _tabController, children: [
            _buildExportTab(isSmallScreen), _buildImportTab(isSmallScreen), _buildFilesTab(isSmallScreen), _buildGuideTab(isSmallScreen),
          ])),
          if (_hasExported) _buildSuccessMessage(isSmallScreen),
          _buildInfoBox(isSmallScreen),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A), foregroundColor: Colors.black, padding: EdgeInsets.symmetric(horizontal: 24, vertical: isSmallScreen ? 12 : 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Close', style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.bold)),
          )),
        ])),
      ),
    );
  }

  Widget _buildSuccessMessage(bool isSmallScreen) {
    return Column(children: [
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.green.withOpacity(0.3), width: 1)),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: isSmallScreen ? 16 : 18),
          const SizedBox(width: 8),
          Expanded(child: Text('File saved successfully!', style: TextStyle(color: Colors.green[700], fontSize: isSmallScreen ? 12 : 14, fontWeight: FontWeight.w500), maxLines: 2)),
        ]),
      ),
    ]);
  }

  Widget _buildInfoBox(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: const Color(0xFFF7931A), size: isSmallScreen ? 14 : 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Files are automatically saved to app storage and can also be saved to any folder', // UPDATED
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: isSmallScreen ? 12 : 14
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab(bool isSmallScreen) {
    return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Why Export Your Data?', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 12),
      _buildGuideItem('Backup Protection', 'Create regular backups to protect your portfolio data from device loss or app reinstallation.', Icons.backup, isSmallScreen),
      const SizedBox(height: 12),
      _buildGuideItem('Device Migration', 'Easily transfer your data when switching to a new device by importing your backup file.', Icons.phone_iphone, isSmallScreen),
      const SizedBox(height: 12),
      _buildGuideItem('Data Analysis', 'Export to CSV for advanced analysis in spreadsheet applications.', Icons.analytics, isSmallScreen),
      const SizedBox(height: 12),
      _buildGuideItem('Complete Backup', 'Use JSON format for complete app backup including all preferences and settings.', Icons.settings_backup_restore, isSmallScreen),
      const SizedBox(height: 20),
      Text('Recommended Steps:', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStep('1', 'Regular Backups', 'Establish a consistent backup schedule that aligns with your transaction frequency', isSmallScreen),
          const SizedBox(height: 8), _buildStep('2', 'Flexible Storage', 'Save backup files to any folder on your device or external storage for optimal organization', isSmallScreen),
          const SizedBox(height: 8), _buildStep('3', 'Before Importing', 'Always export current data before importing to prevent data loss', isSmallScreen),
          const SizedBox(height: 8), _buildStep('4', 'Verify Files', 'Check that exported files open correctly before deleting old backups', isSmallScreen),
        ]),
      ),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.green.withOpacity(0.3), width: 1)),
        child: Row(children: [
          Icon(Icons.security, color: Colors.green, size: isSmallScreen ? 16 : 18),
          const SizedBox(width: 8),
          Expanded(child: Text('For maximum security, store backups on encrypted external storage devices', style: TextStyle(color: widget.isDarkMode ? Colors.green[100] : Colors.green[800], fontSize: isSmallScreen ? 12 : 14, fontWeight: FontWeight.w500))),
        ]),
      ),
      const SizedBox(height: 16),
      Text('Supported Formats:', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 12),
      _buildFormatItem('PDF Report', 'Professional document with portfolio overview', Icons.picture_as_pdf, Colors.red, isSmallScreen),
      const SizedBox(height: 8), _buildFormatItem('CSV Backup', 'Universal spreadsheet format ideal for data backup and analysis', Icons.table_chart, Colors.green, isSmallScreen),
      const SizedBox(height: 8), _buildFormatItem('JSON Backup', 'Complete app data backup including preferences and settings', Icons.code, Colors.purple, isSmallScreen),
      const SizedBox(height: 16),
      Text('Backup Strategy:', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Frequency:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[800])),
          Text('Maintain regular backup intervals based on your transaction activity and risk tolerance.', style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[800])),
          SizedBox(height: 8), Text('Formats:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[800])),
          Text('Use CSV for universal data compatibility and JSON for comprehensive app state preservation.', style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[800])),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Tips:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.blue[100] : Colors.blue[800])),
            SizedBox(height: 4),
            Text('• All exported files are automatically saved to app storage for backup', style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.blue[100] : Colors.blue[800])), // UPDATED
            Text('• JSON preserves all your app settings and preferences', style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.blue[100] : Colors.blue[800])),
            Text('• You can save additional copies to any folder location on your device', style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.blue[100] : Colors.blue[800])), // UPDATED
          ],
        ),
      ),
    ]));
  }

  Widget _buildGuideItem(String title, String description, IconData icon, bool isSmallScreen) {
    return Container(decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8.0)), padding: const EdgeInsets.all(12.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: isSmallScreen ? 32 : 36, height: isSmallScreen ? 32 : 36, decoration: BoxDecoration(color: const Color(0xFFF7931A).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFF7931A), size: isSmallScreen ? 16 : 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 4), Text(description, style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
        ])),
      ]),
    );
  }

  Widget _buildFormatItem(String title, String description, IconData icon, Color color, bool isSmallScreen) {
    return Container(decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8.0)), padding: const EdgeInsets.all(12.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: isSmallScreen ? 32 : 36, height: isSmallScreen ? 32 : 36, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: isSmallScreen ? 16 : 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 4), Text(description, style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
        ])),
      ]),
    );
  }

  Widget _buildStep(String number, String title, String description, bool isSmallScreen) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: isSmallScreen ? 20 : 24, height: isSmallScreen ? 20 : 24, decoration: BoxDecoration(color: const Color(0xFFF7931A), shape: BoxShape.circle),
          child: Center(child: Text(number, style: TextStyle(color: Colors.black, fontSize: isSmallScreen ? 10 : 12, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
        Text(description, style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: widget.isDarkMode ? Colors.white70 : Colors.black54)),
      ])),
    ]);
  }

  Widget _buildExportTab(bool isSmallScreen) {
    return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Export Your Data', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 8),
      Text(
        'Save your portfolio data to any folder - a copy is automatically saved in app storage', // UPDATED
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: widget.isDarkMode ? Colors.white70 : Colors.black54),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Column(children: [
        _buildOption(icon: Icons.picture_as_pdf, title: 'Save PDF Report', color: Colors.red, onTap: () {
          Navigator.of(context).pop(); widget.onSavePdfReport(context); _handleExportComplete('portfolio_report.pdf', 'PDF Export');
        }, isSmallScreen: isSmallScreen),
        const SizedBox(height: 12), _buildOption(icon: Icons.save, title: 'Save CSV Backup', color: Colors.green, onTap: () {
          Navigator.of(context).pop(); widget.onSaveCsvReport(context); _handleExportComplete('portfolio_data.csv', 'CSV Export');
        }, isSmallScreen: isSmallScreen),
        const SizedBox(height: 12), _buildOption(icon: Icons.backup, title: 'Save JSON Backup', color: Colors.purple, onTap: () {
          Navigator.of(context).pop(); widget.onSaveJsonBackup(context); _handleExportComplete('satstack_backup.json', 'JSON Export');
        }, isSmallScreen: isSmallScreen),
      ]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1)),
        child: Row(children: [
          Icon(Icons.folder_open, color: Colors.blue, size: isSmallScreen ? 16 : 18),
          const SizedBox(width: 8),
          Expanded(child: Text('You can save backup files to any folder on your device for better organization', style: TextStyle(color: widget.isDarkMode ? Colors.blue[100] : Colors.blue[800], fontSize: isSmallScreen ? 12 : 14, fontWeight: FontWeight.w500))),
        ]),
      ),
    ]));
  }

  Widget _buildImportTab(bool isSmallScreen) {
    return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Import Data', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
      const SizedBox(height: 8),
      Text('Restore your portfolio from backup', style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: widget.isDarkMode ? Colors.white70 : Colors.black54), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Column(children: [
        _buildOption(icon: Icons.file_upload, title: 'CSV File', color: Colors.orange, onTap: () {
          Navigator.of(context).pop(); widget.onImportFromFile(context, 'csv');
        }, isSmallScreen: isSmallScreen),
        const SizedBox(height: 12), _buildOption(icon: Icons.text_fields, title: 'JSON Text', color: Colors.teal, onTap: () {
          Navigator.of(context).pop(); widget.onShowJsonImportDialog(context);
        }, isSmallScreen: isSmallScreen),
      ]),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1)),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: isSmallScreen ? 14 : 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Importing will replace your current data. Make sure to export first!', style: TextStyle(color: widget.isDarkMode ? Colors.orange[100] : Colors.orange[800], fontSize: isSmallScreen ? 12 : 14, fontWeight: FontWeight.w500))),
        ]),
      ),
    ]));
  }

  Widget _buildFilesTab(bool isSmallScreen) {
    return Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Exported Files', style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black)),
        if (_isSelecting) Row(children: [
          IconButton(icon: Icon(Icons.select_all, color: const Color(0xFFF7931A)), onPressed: _selectAll, tooltip: 'Select All'),
          IconButton(icon: Icon(Icons.clear_all, color: const Color(0xFFF7931A)), onPressed: _clearSelection, tooltip: 'Clear Selection'),
        ]),
        IconButton(icon: Icon(_isSelecting ? Icons.done : Icons.checklist, color: const Color(0xFFF7931A)), onPressed: _toggleSelection, tooltip: _isSelecting ? 'Done Selecting' : 'Select Files'),
      ])),
      if (_isSelecting && _selectedFiles.isNotEmpty) Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Text('${_selectedFiles.length} selected', style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black)),
          IconButton(icon: Icon(Icons.save_alt, color: Colors.blue), onPressed: _batchSaveFiles, tooltip: 'Save Selected'),
          IconButton(icon: Icon(Icons.share, color: Colors.green), onPressed: _batchShareFiles, tooltip: 'Share Selected'),
          IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: _batchDeleteFiles, tooltip: 'Delete Selected'),
        ]),
      ),
      SizedBox(height: _isSelecting && _selectedFiles.isNotEmpty ? 8 : 0),
      Expanded(child: _loadingFiles ? Center(child: CircularProgressIndicator(color: const Color(0xFFF7931A)))
          : _exportedFiles.isEmpty ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open, size: 48, color: widget.isDarkMode ? Colors.white38 : Colors.black38),
        const SizedBox(height: 16), Text('No exported files', style: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 16)),
        const SizedBox(height: 8), Text('Export files will appear here', style: TextStyle(color: widget.isDarkMode ? Colors.white38 : Colors.black38, fontSize: 14), textAlign: TextAlign.center),
      ])
          : ListView.builder(itemCount: _exportedFiles.length, itemBuilder: (context, index) => _buildFileItem(_exportedFiles[index], isSmallScreen))
      ),
    ]);
  }

  Widget _buildFileItem(Map<String, dynamic> file, bool isSmallScreen) {
    final fileName = file['name'] as String, fileType = file['type'] as String, fileSize = file['size'] as int, modified = file['modified'] as DateTime, filePath = file['path'] as String;
    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    String formatDate(DateTime date) { return DateFormat('MMM dd, yyyy - HH:mm').format(date); }
    IconData getFileIcon(String type) {
      switch (type) { case 'CSV': return Icons.table_chart; case 'PDF': return Icons.picture_as_pdf; case 'JSON': return Icons.code; default: return Icons.insert_drive_file; }
    }
    Color getFileColor(String type) {
      switch (type) { case 'CSV': return Colors.green; case 'PDF': return Colors.red; case 'JSON': return Colors.purple; default: return Colors.blue; }
    }
    String getFileDescription(String type) {
      switch (type) { case 'CSV': return 'Spreadsheet data'; case 'PDF': return 'Document report'; case 'JSON': return 'Backup data'; default: return 'Unknown file'; }
    }
    return Container(margin: const EdgeInsets.only(bottom: 8.0), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8.0), border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, width: 1)),
      child: ListTile(leading: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_isSelecting) Checkbox(value: _isFileSelected(filePath), onChanged: (value) => _toggleFileSelection(filePath), activeColor: const Color(0xFFF7931A)),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: getFileColor(fileType).withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: getFileColor(fileType).withOpacity(0.3), width: 2)),
            child: Icon(getFileIcon(fileType), color: getFileColor(fileType), size: 20)),
      ]), title: Text(fileName, style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$fileType • ${formatFileSize(fileSize)} • ${getFileDescription(fileType)}', style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
          Text(formatDate(modified), style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: widget.isDarkMode ? Colors.white54 : Colors.black45)),
        ]), trailing: _isSelecting ? null : PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: widget.isDarkMode ? Colors.white54 : Colors.black54),
          onSelected: (value) async {
            if (value == 'open') await _openFile(filePath, fileName);
            else if (value == 'share') await _shareFile(filePath, fileName);
            else if (value == 'save') await _saveFileToLocation(filePath, fileName);
            else if (value == 'delete') await _deleteFile(filePath, fileName);
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(value: 'open', child: Row(children: [Icon(Icons.open_in_new, color: widget.isDarkMode ? Colors.white : Colors.black), const SizedBox(width: 8), const Text('Open')])),
            PopupMenuItem<String>(value: 'share', child: Row(children: [Icon(Icons.share, color: widget.isDarkMode ? Colors.white : Colors.black), const SizedBox(width: 8), const Text('Share')])),
            PopupMenuItem<String>(value: 'save', child: Row(children: [Icon(Icons.save, color: widget.isDarkMode ? Colors.white : Colors.black), const SizedBox(width: 8), const Text('Save As...')])),
            PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), const Text('Delete', style: TextStyle(color: Colors.red))])),
          ],
        ), onTap: () async { if (_isSelecting) _toggleFileSelection(filePath); else await _openFile(filePath, fileName); },
        onLongPress: () { if (!_isSelecting) { _toggleSelection(); _toggleFileSelection(filePath); } },
      ),
    );
  }

  Future<void> _saveFileToLocation(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final storageService = StorageService();
      final result = await storageService.saveFileToLocation(bytes, fileName);

      if (result.contains('saved to:')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('File saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4)
        ));
      } else if (result.contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Save operation canceled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2)
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save file: ${e.toString()}'),
          backgroundColor: Colors.red
      ));
    }
  }

  Future<void> _openFile(String filePath, String fileName) async {
    try {
      final storageService = StorageService();
      await storageService.openFileWithPicker(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open file: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _shareFile(String filePath, String fileName) async {
    try {
      final storageService = StorageService();
      await storageService.shareFile(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share file: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteFile(String filePath, String fileName) async {
    bool? confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete File'), content: Text('Are you sure you want to delete "$fileName"?'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))],
    ));
    if (confirm == true) {
      try {
        final storageService = StorageService();
        await storageService.deleteExportedFile(filePath);
        await _loadExportedFiles();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File deleted successfully'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete file: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildOption({required IconData icon, required String title, required Color color, required VoidCallback onTap, required bool isSmallScreen}) {
    return Container(decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12.0), border: Border.all(color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, width: 1)),
      child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(12.0), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [
          Container(width: isSmallScreen ? 40 : 48, height: isSmallScreen ? 40 : 48, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3), width: 2)),
              child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white : Colors.black))])),
          Icon(Icons.arrow_forward_ios, color: widget.isDarkMode ? Colors.white54 : Colors.black54, size: isSmallScreen ? 16 : 18),
        ])),
      )),
    );
  }
}

class SuccessAnimationOverlay extends StatelessWidget {
  final String message;
  final AnimationController animationController;
  final bool isDarkMode;

  const SuccessAnimationOverlay({Key? key, required this.message, required this.animationController, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildAnimationOverlay(icon: Icons.check, iconColor: Colors.green, message: message, animationController: animationController, isDarkMode: isDarkMode,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.currency_bitcoin, color: const Color(0xFFF7931A), size: 16).animate(controller: animationController, autoPlay: false).scale(delay: 400.ms, duration: 300.ms).fadeOut(delay: 700.ms),
        const SizedBox(width: 8), Icon(Icons.currency_bitcoin, color: const Color(0xFFF7931A), size: 20).animate(controller: animationController, autoPlay: false).scale(delay: 500.ms, duration: 300.ms).fadeOut(delay: 800.ms),
        const SizedBox(width: 8), Icon(Icons.currency_bitcoin, color: const Color(0xFFF7931A), size: 16).animate(controller: animationController, autoPlay: false).scale(delay: 600.ms, duration: 300.ms).fadeOut(delay: 900.ms),
      ]),
    );
  }
}

class SaveAnimationOverlay extends StatelessWidget {
  final String message;
  final AnimationController animationController;
  final bool isDarkMode;

  const SaveAnimationOverlay({Key? key, required this.message, required this.animationController, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildAnimationOverlay(icon: Icons.download_done, iconColor: Colors.blue, message: message, animationController: animationController, isDarkMode: isDarkMode,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder, color: const Color(0xFFF7931A), size: 24).animate(controller: animationController, autoPlay: false).scale(delay: 400.ms, duration: 300.ms).then().slideY(begin: -10, end: 0, duration: 400.ms),
      ]),
    );
  }
}

class ImportAnimationOverlay extends StatelessWidget {
  final String message;
  final AnimationController animationController;
  final bool isDarkMode;

  const ImportAnimationOverlay({Key? key, required this.message, required this.animationController, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildAnimationOverlay(icon: Icons.file_upload, iconColor: const Color(0xFFF7931A), message: message, animationController: animationController, isDarkMode: isDarkMode,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.arrow_upward, color: const Color(0xFFF7931A), size: 16).animate(controller: animationController, autoPlay: false).slideY(begin: 10, end: -10, duration: 600.ms).fadeOut(delay: 400.ms),
        const SizedBox(width: 8), Icon(Icons.arrow_upward, color: const Color(0xFFF7931A), size: 20).animate(controller: animationController, autoPlay: false).slideY(begin: 10, end: -10, duration: 600.ms, delay: 200.ms).fadeOut(delay: 600.ms),
        const SizedBox(width: 8), Icon(Icons.arrow_upward, color: const Color(0xFFF7931A), size: 16).animate(controller: animationController, autoPlay: false).slideY(begin: 10, end: -10, duration: 600.ms, delay: 400.ms).fadeOut(delay: 800.ms),
      ]),
    );
  }
}

Widget _buildAnimationOverlay({required IconData icon, required Color iconColor, required String message, required AnimationController animationController, required bool isDarkMode, required Widget child}) {
  return Dialog(backgroundColor: Colors.transparent, elevation: 0,
    child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: iconColor, width: 3)),
          child: Icon(icon, color: iconColor, size: 40),
        ).animate(controller: animationController).scale(duration: 600.ms, curve: Curves.elasticOut).then(delay: 300.ms).shake(hz: 4, curve: Curves.easeInOut),
        const SizedBox(height: 20),
        Text(message, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black), textAlign: TextAlign.center)
            .animate(controller: animationController).fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.3, end: 0, duration: 500.ms),
        const SizedBox(height: 16), child,
      ]),
    ),
  );
}