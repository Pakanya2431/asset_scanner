import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Progress'),
            Tab(text: 'Wrong Location'),
          ],
        ),
      ),
      body: !state.hasDatabaseLoaded
          ? _empty()
          : TabBarView(
              controller: _tabs,
              children: [
                _ProgressTab(state: state),
                _WrongLocationTab(state: state),
              ],
            ),
    );
  }

  Widget _empty() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: kTextHint),
            SizedBox(height: 12),
            Text('No data yet',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: kTextSecondary)),
            SizedBox(height: 4),
            Text('Import an Excel database first',
                style: TextStyle(fontSize: 12, color: kTextHint)),
          ],
        ),
      );
}

// ── Tab 1: Progress ───────────────────────────────────────────────────────────
class _ProgressTab extends StatelessWidget {
  final AppState state;
  const _ProgressTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.roomProgress;
    final completed = progress.where((r) => r.status == 'Completed').length;
    final inProgress = progress.where((r) => r.status == 'In Progress').length;
    final notStarted = progress.where((r) => r.status == 'Not Started').length;
    final overall = state.overallProgress;
    final totalItems = state.allItems.length;
    final scannedItems = state.allItems.where((i) => i.isScanned).length;
    final wrongCount = state.wrongLocationItems.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Overall Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${(overall * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: overall,
                minHeight: 10,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text('$scannedItems of $totalItems assets verified',
                style:
                    const TextStyle(fontSize: 12, color: kTextSecondary)),
            if (wrongCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFFFDBA74), width: 0.5),
                ),
                child: Row(children: [
                  const Icon(Icons.swap_horiz_rounded,
                      size: 14, color: Color(0xFFEA580C)),
                  const SizedBox(width: 6),
                  Text('$wrongCount item(s) found at wrong location',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEA580C),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),

        // Stats row
        Row(children: [
          _StatCard(value: '$completed', label: 'Completed', color: kGreen),
          const SizedBox(width: 8),
          _StatCard(value: '$inProgress', label: 'In Progress', color: kAmber),
          const SizedBox(width: 8),
          _StatCard(
              value: '$notStarted', label: 'Not Started', color: kGrayText),
        ]),
        const SizedBox(height: 16),

        const Text('Room Breakdown',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 10),
        ...progress.map((r) => _RoomCard(room: r)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: cardDecoration(),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: kTextHint)),
          ]),
        ),
      );
}

class _RoomCard extends StatelessWidget {
  final RoomProgress room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    final Color badgeBg;
    final Color badgeFg;
    final IconData statusIcon;

    switch (room.status) {
      case 'Completed':
        barColor = kGreen;
        badgeBg = const Color(0xFFDCFCE7);
        badgeFg = const Color(0xFF166534);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'In Progress':
        barColor = kAmber;
        badgeBg = const Color(0xFFFEF3C7);
        badgeFg = const Color(0xFF92400E);
        statusIcon = Icons.access_time_rounded;
        break;
      default:
        barColor = const Color(0xFF9CA3AF);
        badgeBg = const Color(0xFFF3F4F6);
        badgeFg = kGrayText;
        statusIcon = Icons.cancel_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(statusIcon, color: barColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.building.split(' - ').first,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(room.room,
                    style: const TextStyle(
                        fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: badgeBg, borderRadius: BorderRadius.circular(99)),
            child: Text(room.status,
                style: TextStyle(
                    fontSize: 11,
                    color: badgeFg,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: room.percent,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (room.wrongLocation > 0)
              Row(children: [
                const Icon(Icons.swap_horiz_rounded,
                    size: 13, color: Color(0xFFEA580C)),
                const SizedBox(width: 3),
                Text('${room.wrongLocation} wrong location',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFEA580C))),
              ])
            else
              const SizedBox(),
            Text('${room.scanned}/${room.total}',
                style: const TextStyle(fontSize: 12, color: kTextHint)),
          ],
        ),
      ]),
    );
  }
}

// ── Tab 2: Wrong Location ─────────────────────────────────────────────────────
class _WrongLocationTab extends StatelessWidget {
  final AppState state;
  const _WrongLocationTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = state.wrongLocationItems;

    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: kGreen),
            SizedBox(height: 12),
            Text('No location discrepancies',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: kTextSecondary)),
            SizedBox(height: 4),
            Text('All scanned items are at their registered locations',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kTextHint)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: const Color(0xFFFDBA74), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFEA580C), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${items.length} item(s) were scanned at a different location '
                  'than their SAP-registered location. Export this list to update SAP.',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFEA580C)),
                ),
              ),
            ],
          ),
        ),

        ...items.map((s) => _WrongLocationCard(item: s)),
      ],
    );
  }
}

class _WrongLocationCard extends StatelessWidget {
  final ItemScanStatus item;
  const _WrongLocationCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFDBA74), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.swap_horiz_rounded,
                  color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.item.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(item.item.itemCode,
                        style: const TextStyle(
                            fontSize: 12, color: kTextSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(99)),
                child: const Text('Adjust SAP',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFFDBA74)),
            const SizedBox(height: 10),
            _locationRow(
              icon: Icons.storage_rounded,
              label: 'SAP (Registered)',
              location:
                  '${item.item.building}  /  ${item.item.room}',
              color: kGrayText,
            ),
            const SizedBox(height: 6),
            _locationRow(
              icon: Icons.location_on_rounded,
              label: 'Actual (Scanned)',
              location:
                  '${item.scannedBuilding ?? "—"}  /  ${item.scannedRoom ?? "—"}',
              color: const Color(0xFFEA580C),
              bold: true,
            ),
            if (item.scannedAt != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time_rounded,
                    size: 12, color: kTextHint),
                const SizedBox(width: 4),
                Text(
                  'Scanned ${_fmt(item.scannedAt!)}  ·  ${item.scanMode ?? ""}',
                  style: const TextStyle(fontSize: 11, color: kTextHint),
                ),
              ]),
            ],
          ],
        ),
      );

  Widget _locationRow({
    required IconData icon,
    required String label,
    required String location,
    required Color color,
    bool bold = false,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary)),
          ),
          Expanded(
            child: Text(location,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      );

  String _fmt(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
