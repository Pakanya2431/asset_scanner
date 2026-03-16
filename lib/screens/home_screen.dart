import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme.dart';
import 'scan_screen.dart';
import 'location_screen.dart';
import 'report_screen.dart';
import 'export_screen.dart';
import 'import_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: kPrimary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20, right: 20, bottom: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Asset Scanner',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Fixed Asset Verification System',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
                if (state.hasDatabaseLoaded) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${state.allItems.length} items loaded'
                          '${state.selectedBuilding.isNotEmpty ? "  ·  ${state.selectedBuilding.split(" - ").first} · ${state.selectedRoom}" : ""}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Grid ────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Row 1
                  Row(children: [
                    _Tile(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan Mode',
                      badge: state.hasDatabaseLoaded
                          ? '${state.allItems.where((i) => i.isScanned).length}/${state.allItems.length}'
                          : null,
                      onTap: () => _go(context, const ScanScreen()),
                    ),
                    const SizedBox(width: 14),
                    _Tile(
                      icon: Icons.location_on_rounded,
                      label: 'Location Mode',
                      onTap: () => _go(context, const LocationScreen()),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // Row 2
                  Row(children: [
                    _Tile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Report',
                      onTap: () => _go(context, const ReportScreen()),
                    ),
                    const SizedBox(width: 14),
                    _Tile(
                      icon: Icons.download_rounded,
                      label: 'Export Data',
                      onTap: () => _go(context, const ExportScreen()),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // Row 3 — Import (full width)
                  SizedBox(
                    width: double.infinity,
                    child: _Tile(
                      icon: Icons.upload_file_rounded,
                      label: 'Import Data',
                      subtitle: 'Load asset database from Excel',
                      wide: true,
                      onTap: () => _go(context, const ImportScreen()),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12),
            child: const Text('v1.0.0  |  Last sync: Today',
                style: TextStyle(fontSize: 12, color: kTextHint)),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext ctx, Widget screen) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? badge;
  final bool wide;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: wide
          ? const EdgeInsets.symmetric(vertical: 20, horizontal: 24)
          : const EdgeInsets.all(20),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(children: [
                  Icon(icon, color: Colors.white, size: 34),
                  if (badge != null)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                fontSize: 9,
                                color: kPrimary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
    );

    return wide
        ? GestureDetector(onTap: onTap, child: content)
        : Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: GestureDetector(onTap: onTap, child: content),
            ),
          );
  }
}
