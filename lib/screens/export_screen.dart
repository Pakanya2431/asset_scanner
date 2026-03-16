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
  String _filter = 'All Data';
  bool _includeWrongLocation = true;
  bool _exporting = false;

  final _formats = [
    ('Excel (.xlsx)', Icons.table_chart_rounded),
    ('CSV (.csv)', Icons.description_rounded),
    ('Google Sheets', Icons.share_rounded),
  ];

  final _filters = [
    ('Today', 'Export today\'s scans', Icons.calendar_today_rounded),
    ('Current Location', 'Export current building/room', Icons.location_on_rounded),
    ('All Data', 'Export all scanned assets', Icons.storage_rounded),
  ];

  List<ItemScanStatus> _getItems(AppState state) {
    switch (_filter) {
      case 'Today': return state.todayScanned;
      case 'Current Location': return state.currentLocationScanned;
      default: return state.allScanned;
    }
  }

  Future<void> _doExport(AppState state) async {
    final items = _getItems(state);
    if (items.isEmpty && !(_includeWrongLocation && state.wrongLocationItems.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No items to export for this filter'),
          backgroundColor: kAmber));
      return;
    }
    setState(() => _exporting = true);
    try {
      if (_format == 'CSV (.csv)') {
        await _exportCsv(items, state);
      } else {
        await _exportExcel(items, state);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel(List<ItemScanStatus> items, AppState state) async {
    final excel = Excel.createExcel();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    // ── Sheet 1: Scanned assets ──────────────────────────────────────────
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

    // ── Sheet 2: Missing items ─────────────────────────────────────────
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
          TextCellValue(s.item.itemCode),
          TextCellValue(s.item.itemName),
          TextCellValue(s.item.building),
          TextCellValue(s.item.room),
          TextCellValue('Missing — Not Scanned'),
        ]);
      }
    }

    // ── Sheet 3: Wrong location items ──────────────────────────────────
    if (_includeWrongLocation) {
      final wrong = state.wrongLocationItems;
      if (wrong.isNotEmpty) {
        final sheet3 = excel['Wrong Location (SAP Update)'];
        sheet3.appendRow([
          TextCellValue('Item Code'), TextCellValue('Item Name'),
          TextCellValue('SAP Building'), TextCellValue('SAP Room'),
          TextCellValue('Actual Building'), TextCellValue('Actual Room'),
          TextCellValue('Scanned At'), TextCellValue('Scan Mode'),
          TextCellValue('Action Required'),
        ]);
        for (final s in wrong) {
          sheet3.appendRow([
            TextCellValue(s.item.itemCode),
            TextCellValue(s.item.itemName),
            TextCellValue(s.item.building),
            TextCellValue(s.item.room),
            TextCellValue(s.scannedBuilding ?? ''),
            TextCellValue(s.scannedRoom ?? ''),
            TextCellValue(s.scannedAt != null ? fmt.format(s.scannedAt!) : ''),
            TextCellValue(s.scanMode ?? ''),
            TextCellValue('Update location in SAP to: ${s.scannedBuilding} / ${s.scannedRoom}'),
          ]);
        }
      }
    }

    // Remove default sheet
    excel.delete('Sheet1');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/asset_report.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], subject: 'Asset Scanner Report');
  }

  Future<void> _exportCsv(List<ItemScanStatus> items, AppState state) async {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    // Main CSV
    final lines = [
      'Item Code,Item Name,Registered Building,Registered Room,Status,Scan Mode,Scanned At,Scanned Building,Scanned Room,Location Remark',
      ...items.map((s) {
        final remark = s.isWrongLocation ? 'Wrong Location - Update SAP' : '';
        return '"${s.item.itemCode}","${s.item.itemName}","${s.item.building}","${s.item.room}",'
            '"Scanned","${s.scanMode ?? ""}","${s.scannedAt != null ? fmt.format(s.scannedAt!) : ""}",'
            '"${s.scannedBuilding ?? ""}","${s.scannedRoom ?? ""}","$remark"';
      }),
    ];

    // Append wrong-location section
    if (_includeWrongLocation && state.wrongLocationItems.isNotEmpty) {
      lines.add('');
      lines.add('--- WRONG LOCATION ITEMS (SAP Update Required) ---');
      lines.add('Item Code,Item Name,SAP Building,SAP Room,Actual Building,Actual Room,Action');
      for (final s in state.wrongLocationItems) {
        lines.add('"${s.item.itemCode}","${s.item.itemName}",'
            '"${s.item.building}","${s.item.room}",'
            '"${s.scannedBuilding ?? ""}","${s.scannedRoom ?? ""}",'
            '"Update SAP location"');
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/asset_report.csv');
    await file.writeAsString(lines.join('\n'));
    await Share.shareXFiles([XFile(file.path)], subject: 'Asset Report CSV');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = _getItems(state).length;
    final wrongCount = state.wrongLocationItems.length;
    final fmtShort = _format == 'Excel (.xlsx)'
        ? 'EXCEL' : _format == 'CSV (.csv)' ? 'CSV' : 'SHEETS';

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _label('Export Format'),
                const SizedBox(height: 8),
                ..._formats.map((f) => _SelectCard(
                      label: f.$1, icon: f.$2,
                      selected: _format == f.$1,
                      onTap: () => setState(() => _format = f.$1),
                    )),
                const SizedBox(height: 16),
                _label('Filter Options'),
                const SizedBox(height: 8),
                ..._filters.map((f) => _SelectCard(
                      label: f.$1, sub: f.$2, icon: f.$3,
                      selected: _filter == f.$1,
                      onTap: () => setState(() => _filter = f.$1),
                    )),

                // Wrong location toggle
                const SizedBox(height: 16),
                _label('Additional Sheets / Sections'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: cardDecoration(
                      selected: _includeWrongLocation,
                      borderColor: _includeWrongLocation
                          ? const Color(0xFFEA580C)
                          : null),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            wrongCount > 0
                                ? '$wrongCount item(s) found at wrong location — export to update SAP'
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
                      onChanged: (v) => setState(() => _includeWrongLocation = v),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),
                // Summary note
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
                        'Ready to export $count scanned assets as $fmtShort',
                        style: const TextStyle(
                            fontSize: 13,
                            color: kPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      if (_format != 'CSV (.csv)') ...[
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
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton.icon(
              icon: _exporting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.share_rounded),
              label: Text(_exporting ? 'Exporting…' : 'Export Data'),
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

class _SelectCard extends StatelessWidget {
  final String label;
  final String? sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectCard({
    required this.label, required this.icon,
    required this.selected, required this.onTap, this.sub,
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
            Icon(icon,
                size: 20,
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
