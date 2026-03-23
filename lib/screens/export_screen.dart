import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../theme.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _format = 'Excel (.xlsx)';
  bool _includeWrongLocation = true;
  bool _exporting = false;
  // 'downloads' = save to phone Downloads folder (USB accessible)
  // 'share'     = Android share sheet (email, Drive, etc.)
  String _exportMethod = 'downloads';

  final _formats = [
    ('Excel (.xlsx)', Icons.table_chart_rounded),
    ('CSV (.csv)',    Icons.description_rounded),
  ];


  List<ItemScanStatus> _getItems(AppState state) => state.allScanned;

  /// Returns the Downloads folder path on Android
  Future<String> _getDownloadsPath() async {
    // Android public Downloads directory
    const downloadsPath = '/storage/emulated/0/Download';
    final dir = Directory(downloadsPath);
    if (await dir.exists()) return downloadsPath;
    // Fallback to app external storage
    final ext = await getExternalStorageDirectory();
    return ext?.path ?? (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> _doExport(AppState state) async {
    final items = _getItems(state);
    if (items.isEmpty &&
        !(_includeWrongLocation && state.wrongLocationItems.isNotEmpty)) {
      _snack('No scanned items to export', kAmber);
      return;
    }
    setState(() => _exporting = true);
    try {
      final String savedPath;
      if (_format == 'CSV (.csv)') {
        savedPath = await _buildCsv(items, state);
      } else {
        savedPath = await _buildExcel(items, state);
      }

      if (_exportMethod == 'share') {
        await Share.shareXFiles([XFile(savedPath)],
            subject: 'Asset Scanner Report');
      } else {
        // Save to Downloads — show success dialog with path
        if (mounted) _showSavedDialog(savedPath);
      }
    } catch (e) {
      _snack('Export failed: $e', kRed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Shows a dialog telling the user where the file was saved
  void _showSavedDialog(String filePath) {
    final fileName = filePath.split('/').last;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: kGreen, size: 24),
          SizedBox(width: 10),
          Text('File Saved!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your file has been saved to:',
                style: TextStyle(fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁 Phone → Internal Storage → Download',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kGreen)),
                  const SizedBox(height: 4),
                  Text(fileName,
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To transfer via USB:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimary)),
                  SizedBox(height: 4),
                  Text('1. Connect phone to PC via USB\n'
                      '2. Select "File Transfer" on phone\n'
                      '3. Open File Explorer on PC\n'
                      '4. Go to Phone → Download folder\n'
                      '5. Copy the file to your PC',
                      style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Also offer share after saving
              Share.shareXFiles([XFile(filePath)],
                  subject: 'Asset Scanner Report');
            },
            child: const Text('Also Share'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String> _buildExcel(List<ItemScanStatus> items, AppState state) async {
    final excel = Excel.createExcel();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    // Sheet 1: Scanned assets
    final sheet1 = excel['Scanned Assets'];
    sheet1.appendRow([
      TextCellValue('Item Code'), TextCellValue('Item Name'),
      TextCellValue('Registered Building'), TextCellValue('Registered Room'),
      TextCellValue('Status'), TextCellValue('Scan Mode'),
      TextCellValue('Scanned At'), TextCellValue('Scanned At Building'),
      TextCellValue('Scanned At Room'), TextCellValue('Location Remark'),
    ]);
    for (final s in items) {
      final remark = s.isWrongLocation ? 'Wrong Location — Update SAP' : '';
      sheet1.appendRow([
        TextCellValue(s.item.itemCode),
        TextCellValue(s.item.itemName),
        TextCellValue(s.item.building),
        TextCellValue(s.item.room),
        TextCellValue('Scanned'),
        TextCellValue(s.scanMode ?? ''),
        TextCellValue(s.scannedAt != null ? fmt.format(s.scannedAt!) : ''),
        TextCellValue(s.scannedBuilding ?? ''),
        TextCellValue(s.scannedRoom ?? ''),
        TextCellValue(remark),
      ]);
    }

    // Sheet 2: Missing items
    final notScanned = state.allItems.where((s) => !s.isScanned).toList();
    if (notScanned.isNotEmpty) {
      final sheet2 = excel['Missing Items'];
      sheet2.appendRow([
        TextCellValue('Item Code'), TextCellValue('Item Name'),
        TextCellValue('Building'), TextCellValue('Room'),
        TextCellValue('Status'),
      ]);
      for (final s in notScanned) {
        sheet2.appendRow([
          TextCellValue(s.item.itemCode), TextCellValue(s.item.itemName),
          TextCellValue(s.item.building), TextCellValue(s.item.room),
          TextCellValue('Missing — Not Scanned'),
        ]);
      }
    }

    // Sheet 3: Wrong location
    if (_includeWrongLocation && state.wrongLocationItems.isNotEmpty) {
      final sheet3 = excel['Wrong Location (SAP Update)'];
      sheet3.appendRow([
        TextCellValue('Item Code'), TextCellValue('Item Name'),
        TextCellValue('SAP Building'), TextCellValue('SAP Room'),
        TextCellValue('Actual Building'), TextCellValue('Actual Room'),
        TextCellValue('Scanned At'), TextCellValue('Scan Mode'),
        TextCellValue('Action Required'),
      ]);
      for (final s in state.wrongLocationItems) {
        sheet3.appendRow([
          TextCellValue(s.item.itemCode), TextCellValue(s.item.itemName),
          TextCellValue(s.item.building), TextCellValue(s.item.room),
          TextCellValue(s.scannedBuilding ?? ''),
          TextCellValue(s.scannedRoom ?? ''),
          TextCellValue(s.scannedAt != null ? fmt.format(s.scannedAt!) : ''),
          TextCellValue(s.scanMode ?? ''),
          TextCellValue(
              'Update location in SAP to: ${s.scannedBuilding} / ${s.scannedRoom}'),
        ]);
      }
    }

    excel.delete('Sheet1');

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'asset_report_$timestamp.xlsx';
    final dirPath = _exportMethod == 'downloads'
        ? await _getDownloadsPath()
        : (await getTemporaryDirectory()).path;
    final file = File('$dirPath/$fileName');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  Future<String> _buildCsv(List<ItemScanStatus> items, AppState state) async {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final lines = [
      'Item Code,Item Name,Registered Building,Registered Room,Status,Scan Mode,Scanned At,Scanned Building,Scanned Room,Location Remark',
      ...items.map((s) {
        final remark = s.isWrongLocation ? 'Wrong Location - Update SAP' : '';
        return '"${s.item.itemCode}","${s.item.itemName}","${s.item.building}","${s.item.room}",'
            '"Scanned","${s.scanMode ?? ""}","${s.scannedAt != null ? fmt.format(s.scannedAt!) : ""}",'
            '"${s.scannedBuilding ?? ""}","${s.scannedRoom ?? ""}","$remark"';
      }),
    ];
    if (_includeWrongLocation && state.wrongLocationItems.isNotEmpty) {
      lines.addAll([
        '',
        '--- WRONG LOCATION ITEMS (SAP Update Required) ---',
        'Item Code,Item Name,SAP Building,SAP Room,Actual Building,Actual Room,Action',
        ...state.wrongLocationItems.map((s) =>
            '"${s.item.itemCode}","${s.item.itemName}",'
            '"${s.item.building}","${s.item.room}",'
            '"${s.scannedBuilding ?? ""}","${s.scannedRoom ?? ""}",'
            '"Update SAP location"'),
      ]);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'asset_report_$timestamp.csv';
    final dirPath = _exportMethod == 'downloads'
        ? await _getDownloadsPath()
        : (await getTemporaryDirectory()).path;
    final file = File('$dirPath/$fileName');
    await file.writeAsString(lines.join('\n'));
    return file.path;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = _getItems(state).length;
    final wrongCount = state.wrongLocationItems.length;
    final fmtShort = _format == 'Excel (.xlsx)' ? 'EXCEL' : 'CSV';

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Export method ────────────────────────────────────────
                _label('Export Method'),
                const SizedBox(height: 8),
                Row(children: [
                  _MethodCard(
                    icon: Icons.usb_rounded,
                    title: 'Save to Downloads',
                    subtitle: 'Access via USB cable',
                    selected: _exportMethod == 'downloads',
                    onTap: () => setState(() => _exportMethod = 'downloads'),
                  ),
                  const SizedBox(width: 10),
                  _MethodCard(
                    icon: Icons.share_rounded,
                    title: 'Share',
                    subtitle: 'Email, Drive, etc.',
                    selected: _exportMethod == 'share',
                    onTap: () => setState(() => _exportMethod = 'share'),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Format ───────────────────────────────────────────────
                _label('File Format'),
                const SizedBox(height: 8),
                ..._formats.map((f) => _SelectCard(
                      label: f.$1, icon: f.$2,
                      selected: _format == f.$1,
                      onTap: () => setState(() => _format = f.$1),
                    )),


                const SizedBox(height: 16),

                // ── Wrong location toggle ────────────────────────────────
                _label('Additional Sheets'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: cardDecoration(selected: _includeWrongLocation),
                  child: Row(children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 20, color: Color(0xFFEA580C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Include Wrong Location Report',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            wrongCount > 0
                                ? '$wrongCount item(s) found at wrong location'
                                : 'No wrong-location items currently',
                            style: const TextStyle(
                                fontSize: 12, color: kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _includeWrongLocation,
                      activeColor: const Color(0xFFEA580C),
                      onChanged: (v) =>
                          setState(() => _includeWrongLocation = v),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Summary ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: kPrimary.withOpacity(0.2), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to export $count scanned assets as $fmtShort'
                        ' → ${_exportMethod == "downloads" ? "Downloads folder" : "Share sheet"}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: kPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      if (_format == 'Excel (.xlsx)') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sheets: Scanned Assets'
                          '${state.allItems.where((i) => !i.isScanned).isNotEmpty ? "  +  Missing Items" : ""}'
                          '${_includeWrongLocation && wrongCount > 0 ? "  +  Wrong Location" : ""}',
                          style: const TextStyle(
                              fontSize: 12, color: kTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Export button ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton.icon(
              icon: _exporting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_exportMethod == 'downloads'
                      ? Icons.save_alt_rounded
                      : Icons.share_rounded),
              label: Text(_exporting
                  ? 'Exporting…'
                  : _exportMethod == 'downloads'
                      ? 'Save to Downloads'
                      : 'Export & Share'),
              onPressed: _exporting ? null : () => _doExport(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary));
}

// ── Method card (Downloads vs Share) ─────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(selected: selected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 24,
                    color: selected ? kPrimary : kTextSecondary),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? kPrimary : kTextPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
        ),
      );
}

// ── Select card ───────────────────────────────────────────────────────────────
class _SelectCard extends StatelessWidget {
  final String label;
  final String? sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

 const _SelectCard({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: sub != null ? 12 : 14),
          decoration: cardDecoration(selected: selected),
          child: Row(children: [
            Icon(icon, size: 20,
                color: selected ? kPrimary : kTextSecondary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: selected ? kPrimary : kTextPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400)),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ]),
        ),
      );
}
