import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../widgets/scanner_widget.dart';
import '../theme.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final locationItems = state.itemsForCurrentLocation;
    final missingCount = locationItems
        .where((i) => state.displayStatusFor(i) == ItemDisplayStatus.missing)
        .length;
    final foundCount = locationItems
        .where((i) => state.displayStatusFor(i) == ItemDisplayStatus.found)
        .length;
    final wrongCount = locationItems
        .where(
            (i) => state.displayStatusFor(i) == ItemDisplayStatus.wrongLocation)
        .length;
    final timeFmt = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan Mode'),
            if (state.selectedBuilding.isNotEmpty)
              Text(
                '${state.selectedBuilding.split(" - ").first} · ${state.selectedRoom}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Shared scanner widget (always-on, no toggle button) ──────
          ScannerWidget(
            onScanResult: (code, result) =>
                _handleScanResult(context, state, code, result),
          ),

          // ── Summary chips ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              _SummaryChip(
                  label: 'Missing',
                  count: missingCount,
                  color: kRed,
                  bg: const Color(0xFFFEF2F2)),
              const SizedBox(width: 8),
              _SummaryChip(
                  label: 'Found',
                  count: foundCount,
                  color: kGreen,
                  bg: const Color(0xFFF0FDF4)),
              const SizedBox(width: 8),
              _SummaryChip(
                  label: 'Wrong Loc.',
                  count: wrongCount,
                  color: const Color(0xFFEA580C),
                  bg: const Color(0xFFFFF7ED)),
            ]),
          ),

          // ── Item list ────────────────────────────────────────────────
          Expanded(
            child: !state.hasDatabaseLoaded
                ? _emptyState(
                    Icons.upload_file_rounded,
                    'No database loaded',
                    'Import an Excel file first',
                  )
                : locationItems.isEmpty
                    ? _emptyState(
                        Icons.location_off_rounded,
                        'No items for this location',
                        'Set a location first',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: locationItems.length,
                        itemBuilder: (_, i) {
                          final s = locationItems[i];
                          final ds = state.displayStatusFor(s);
                          return _ItemRow(
                              item: s, displayStatus: ds, timeFmt: timeFmt);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _handleScanResult(
      BuildContext context, AppState state, String code, ItemScanStatus? result) {
    if (result == null) {
      _snack(context, '⚠ Unknown code: $code', kAmber);
      return;
    }
    final ds = state.displayStatusFor(result);
    if (ds == ItemDisplayStatus.wrongLocation) {
      _snack(
        context,
        '⚠ ${result.item.itemName} — belongs to '
        '${result.item.building.split(" - ").first} / ${result.item.room}',
        const Color(0xFFEA580C),
        duration: const Duration(seconds: 4),
      );
    } else {
      _snack(context, '✓ ${result.item.itemName} — Found', kGreen);
    }
  }

  void _snack(BuildContext context, String msg, Color color,
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

  Widget _emptyState(IconData icon, String title, String sub) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: kTextHint),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: kTextSecondary)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: kTextHint)),
        ]),
      );
}

// ── Summary chip ─────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;

  const _SummaryChip(
      {required this.label,
      required this.count,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      );
}

// ── Item row ──────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final ItemScanStatus item;
  final ItemDisplayStatus displayStatus;
  final DateFormat timeFmt;

  const _ItemRow(
      {required this.item,
      required this.displayStatus,
      required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    late Color borderColor;
    late Color bgColor;
    late Color iconColor;
    late IconData iconData;
    late Widget badge;

    switch (displayStatus) {
      case ItemDisplayStatus.found:
        borderColor = const Color(0xFF86EFAC);
        bgColor = const Color(0xFFF0FDF4);
        iconColor = kGreen;
        iconData = Icons.check_circle_rounded;
        badge = _badge('Found', kGreen, const Color(0xFFDCFCE7));
        break;
      case ItemDisplayStatus.missing:
        borderColor = const Color(0xFFFCA5A5);
        bgColor = const Color(0xFFFEF2F2);
        iconColor = kRed;
        iconData = Icons.cancel_rounded;
        badge = _badge('Missing', kRed, const Color(0xFFFFE4E4));
        break;
      case ItemDisplayStatus.wrongLocation:
        borderColor = const Color(0xFFFDBA74);
        bgColor = const Color(0xFFFFF7ED);
        iconColor = const Color(0xFFEA580C);
        iconData = Icons.swap_horiz_rounded;
        badge =
            _badge('Wrong Loc.', const Color(0xFFEA580C), const Color(0xFFFFEDD5));
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(iconData, color: iconColor, size: 20),
            const SizedBox(width: 10),
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
            badge,
          ]),
          if (displayStatus == ItemDisplayStatus.wrongLocation) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Registered: ${item.item.building.split(" - ").first} / ${item.item.room}'
                    '  →  Scanned: ${item.scannedBuilding?.split(" - ").first ?? ""} / ${item.scannedRoom ?? ""}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFEA580C)),
                  ),
                ),
              ]),
            ),
          ],
          if (item.isScanned && item.scannedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time_rounded,
                    size: 11, color: iconColor.withOpacity(0.7)),
                const SizedBox(width: 3),
                Text(timeFmt.format(item.scannedAt!),
                    style: TextStyle(
                        fontSize: 11, color: iconColor.withOpacity(0.7))),
                if (item.scanMode != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.scanMode!,
                        style: TextStyle(
                            fontSize: 10,
                            color: iconColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: fg.withOpacity(0.3), width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      );
}
