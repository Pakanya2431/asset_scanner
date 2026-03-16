import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../models/app_state.dart';
import '../models/asset.dart';
import '../theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _loading = false;
  String? _error;
  List<ImportedItem>? _preview;
  String? _fileName;

  // Expected column headers (case-insensitive)
  static const _colItemCode   = ['item code', 'itemcode', 'code', 'asset code', 'assetcode'];
  static const _colItemName   = ['item name', 'itemname', 'name', 'description', 'asset name'];
  static const _colBuilding   = ['building', 'building name', 'bldg'];
  static const _colRoom       = ['room', 'room name', 'location', 'room no'];

  Future<void> _pickFile() async {
    setState(() { _loading = true; _error = null; _preview = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final bytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.sheets.values.first;
      final rows = sheet.rows;
      if (rows.isEmpty) throw Exception('Sheet is empty');

      // ── Find header row ────────────────────────────────────────────────
      final headerRow = rows.first;
      final headers = headerRow
          .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
          .toList();

      int _findCol(List<String> options) {
        for (final opt in options) {
          final idx = headers.indexOf(opt);
          if (idx >= 0) return idx;
        }
        return -1;
      }

      final codeIdx     = _findCol(_colItemCode);
      final nameIdx     = _findCol(_colItemName);
      final buildingIdx = _findCol(_colBuilding);
      final roomIdx     = _findCol(_colRoom);

      if (codeIdx < 0 || nameIdx < 0) {
        throw Exception(
          'Could not find required columns.\n'
          'Expected: Item Code, Item Name, Building, Room\n'
          'Found: ${headers.join(", ")}',
        );
      }

      // ── Parse data rows ────────────────────────────────────────────────
      final items = <ImportedItem>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        String cell(int idx) =>
            idx >= 0 && idx < row.length
                ? (row[idx]?.value?.toString().trim() ?? '')
                : '';

        final code     = cell(codeIdx);
        final name     = cell(nameIdx);
        final building = buildingIdx >= 0 ? cell(buildingIdx) : 'Default Building';
        final room     = roomIdx >= 0 ? cell(roomIdx) : 'Default Room';

        if (code.isEmpty) continue; // skip blank rows
        items.add(ImportedItem(
          itemCode: code,
          itemName: name.isNotEmpty ? name : code,
          building: building.isNotEmpty ? building : 'Default Building',
          room: room.isNotEmpty ? room : 'Default Room',
        ));
      }

      if (items.isEmpty) throw Exception('No valid data rows found');

      setState(() {
        _preview = items;
        _fileName = fileName;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _import() {
    if (_preview == null) return;
    context.read<AppState>().importItems(_preview!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✓ ${_preview!.length} items imported successfully'),
      backgroundColor: kGreen,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Info card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.info_outline_rounded, color: kPrimary, size: 18),
                  SizedBox(width: 8),
                  Text('Excel Format Required',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kPrimary)),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'Your Excel file must have these column headers:',
                  style: TextStyle(fontSize: 13, color: kTextSecondary),
                ),
                const SizedBox(height: 8),
                _colRow('Item Code', 'Required — unique asset identifier'),
                _colRow('Item Name', 'Required — asset description'),
                _colRow('Building',  'Optional — building name'),
                _colRow('Room',      'Optional — room number'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Current db status ──────────────────────────────────────────
          if (state.hasDatabaseLoaded)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(
                  borderColor: kGreen.withOpacity(0.4)),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: kGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Database loaded',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: kGreen)),
                      Text(
                          '${state.allItems.length} items · ${state.buildings.length} buildings',
                          style: const TextStyle(
                              fontSize: 12, color: kTextSecondary)),
                    ],
                  ),
                ),
              ]),
            ),

          // ── Pick file button ───────────────────────────────────────────
          ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.folder_open_rounded),
            label: Text(_loading ? 'Reading file…' : 'Select Excel File'),
            onPressed: _loading ? null : _pickFile,
          ),

          const SizedBox(height: 16),

          // ── Error ──────────────────────────────────────────────────────
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFCA5A5), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: kRed, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: kRed)),
                  ),
                ],
              ),
            ),

          // ── Preview ────────────────────────────────────────────────────
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Preview — $_fileName',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${_preview!.length} items',
                            style: const TextStyle(
                                fontSize: 12,
                                color: kPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Table header
                  _tableRow(
                      'Code', 'Name', 'Building', 'Room',
                      isHeader: true),
                  const Divider(height: 8),
                  ..._preview!.take(10).map((item) => _tableRow(
                      item.itemCode,
                      item.itemName,
                      item.building.split(' - ').first,
                      item.room)),
                  if (_preview!.length > 10) ...[
                    const SizedBox(height: 6),
                    Text(
                        '… and ${_preview!.length - 10} more items',
                        style: const TextStyle(
                            fontSize: 12, color: kTextHint)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_rounded),
              label: Text('Import ${_preview!.length} Items'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen),
              onPressed: _import,
            ),
          ],

          const SizedBox(height: 32),

          // ── Template hint ──────────────────────────────────────────────
          const Text('Example Excel structure:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Column(children: [
              _tableRow('Item Code', 'Item Name', 'Building', 'Room',
                  isHeader: true),
              const Divider(height: 1),
              _tableRow('AST-001', 'Dell Laptop', 'Building A', 'Room 101'),
              _tableRow('AST-002', 'Office Chair', 'Building A', 'Room 101'),
              _tableRow('AST-003', 'Printer', 'Building B', 'Room 201'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _colRow(String col, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(
            width: 90,
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FE),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(col,
                style: const TextStyle(
                    fontSize: 11,
                    color: kPrimary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(desc,
              style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        ]),
      );

  Widget _tableRow(String c1, String c2, String c3, String c4,
      {bool isHeader = false}) {
    final style = TextStyle(
        fontSize: 11,
        fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
        color: isHeader ? kTextPrimary : kTextSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: [
        SizedBox(width: 70, child: Text(c1, style: style, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 90, child: Text(c2, style: style, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 72, child: Text(c3, style: style, overflow: TextOverflow.ellipsis)),
        Expanded(child: Text(c4, style: style, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
