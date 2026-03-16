import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../widgets/scanner_widget.dart';
import '../theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Tracks codes scanned in this session (this screen opening)
  final List<String> _sessionCodes = [];

  void _handleResult(String code, ItemScanStatus? result) {
    // Add to session list if not already there
    if (!_sessionCodes.contains(code)) {
      setState(() => _sessionCodes.insert(0, code));
    }
    if (result == null) {
      _snack('⚠ Unknown code: $code', kAmber);
    } else {
      _snack('✓ ${result.item.itemName}', kGreen);
    }
  }

  void _snack(String msg, Color color,
      {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timeFmt = DateFormat('hh:mm a');

    // All scanned items sorted by most recent — all of them, no limit
    final allScanned = state.allItems
        .where((i) => i.isScanned && i.scannedAt != null)
        .toList()
      ..sort((a, b) => b.scannedAt!.compareTo(a.scannedAt!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Mode'),
      ),
      body: Column(
        children: [
          // ── Scanner (always-on, no location link) ────────────────────
          ScannerWidget(
            onScanResult: (code, result) => _handleResult(code, result),
          ),

          // ── Header row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scanned Items',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                if (allScanned.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${allScanned.length} scanned',
                      style: const TextStyle(
                          fontSize: 11,
                          color: kGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // ── Scanned items list ───────────────────────────────────────
          Expanded(
            child: allScanned.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            size: 48, color: kTextHint),
                        const SizedBox(height: 10),
                        const Text('No items scanned yet',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kTextSecondary)),
                        const SizedBox(height: 4),
                        const Text(
                            'Point camera at a barcode to start',
                            style: TextStyle(
                                fontSize: 12, color: kTextHint)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: allScanned.length,
                    itemBuilder: (_, i) {
                      final item = allScanned[i];
                      return _ScannedRow(
                          item: item, index: i, timeFmt: timeFmt);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Simple scanned row — green only, no location logic ───────────────────────
class _ScannedRow extends StatelessWidget {
  final ItemScanStatus item;
  final int index;
  final DateFormat timeFmt;

  const _ScannedRow({
    required this.item,
    required this.index,
    required this.timeFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1),
      ),
      child: Row(children: [
        // Index bubble
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: kGreen.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGreen)),
          ),
        ),
        const SizedBox(width: 10),

        // Item info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.item.itemName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(item.item.itemCode,
                  style: const TextStyle(
                      fontSize: 11, color: kTextSecondary)),
            ],
          ),
        ),

        // Time + mode
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: kGreen, size: 18),
            const SizedBox(height: 4),
            Text(
              item.scannedAt != null
                  ? timeFmt.format(item.scannedAt!)
                  : '',
              style: const TextStyle(fontSize: 11, color: kTextHint),
            ),
            if (item.scanMode != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.scanMode!,
                    style: const TextStyle(
                        fontSize: 9,
                        color: kGreen,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ]),
    );
  }
}
