import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../services/rfid_broadcast_service.dart';
import '../theme.dart';

/// A self-contained scanner widget (Barcode/RFID toggle + continuous camera)
/// that can be embedded in any screen. Calls [onScanResult] after each scan.
///
/// RFID mode uses Android Broadcast Intents (iData T2 UHF):
///  - Tap "Start Scanning" → device reads all tags in range automatically
///  - Each EPC is received via broadcast and processed in real time
///  - Tap "Stop" to end the session
class ScannerWidget extends StatefulWidget {
  /// Called when a code is processed. [result] is null if code not in DB.
  final void Function(String code, ItemScanStatus? result)? onScanResult;

  /// If true, camera viewport is compact (for embedding inside a larger screen)
  final bool compact;

  const ScannerWidget({
    super.key,
    this.onScanResult,
    this.compact = false,
  });

  @override
  State<ScannerWidget> createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget>
    with WidgetsBindingObserver {
  // ── Barcode ────────────────────────────────────────────────────────────────
  late MobileScannerController _ctrl;
  bool _torchOn = false;
  String? _lastBarcodeCode;

  // ── RFID Broadcast ─────────────────────────────────────────────────────────
  final _rfidService = RfidBroadcastService();
  StreamSubscription<String>? _rfidSub;
  bool _rfidScanning = false;

  /// EPCs seen in this RFID session — used for dedup and live count
  final Set<String> _sessionEpcs = {};

  // ── Fallback keyboard-wedge (for non-broadcast devices) ───────────────────
  final _rfidController = TextEditingController();
  final _rfidFocus = FocusNode();
  bool _broadcastSupported = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      autoStart: true,
    );
    _checkBroadcastSupport();
  }

  Future<void> _checkBroadcastSupport() async {
    final supported = await _rfidService.isSupported();
    if (mounted) setState(() => _broadcastSupported = supported);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _stopRfid();
    _rfidService.dispose();
    _rfidController.dispose();
    _rfidFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ctrl.stop();
      _stopRfid();
    } else if (state == AppLifecycleState.resumed) {
      final appState = context.read<AppState>();
      if (appState.activeScanMode == 'Barcode') _ctrl.start();
    }
  }

  // ── Barcode detection ─────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastBarcodeCode) return;
    _lastBarcodeCode = code;
    _processCode(code);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _lastBarcodeCode = null;
    });
  }

  // ── RFID broadcast ────────────────────────────────────────────────────────
  void _startRfid() {
    if (_rfidScanning) return;
    setState(() {
      _rfidScanning = true;
      _sessionEpcs.clear();
    });
    _rfidService.startScan();
    _rfidSub = _rfidService.tagStream.listen(_onRfidTag);
  }

  void _stopRfid() {
    if (!_rfidScanning) return;
    _rfidSub?.cancel();
    _rfidSub = null;
    _rfidService.stopScan();
    if (mounted) setState(() => _rfidScanning = false);
  }

  void _onRfidTag(String epc) {
    // Deduplicate within session
    if (_sessionEpcs.contains(epc)) return;
    _sessionEpcs.add(epc);
    if (mounted) setState(() {}); // update live counter
    _processCode(epc);
  }

  // ── Keyboard-wedge fallback (non-broadcast devices) ───────────────────────
  void _onRfidChanged(String value) {
    if (value.contains('\n')) {
      final code = value.replaceAll('\n', '').trim();
      if (code.isNotEmpty) _submitRfidManual(code);
    }
  }

  void _submitRfidManual([String? override]) {
    final code = (override ?? _rfidController.text).trim();
    if (code.isEmpty) return;
    _rfidController.clear();
    _rfidFocus.requestFocus();
    if (_sessionEpcs.contains(code)) return;
    _sessionEpcs.add(code);
    if (mounted) setState(() {});
    _processCode(code);
  }

  // ── Shared processing ─────────────────────────────────────────────────────
  void _processCode(String code) {
    final state = context.read<AppState>();
    final result = state.registerScan(code);
    widget.onScanResult?.call(code, result);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isBarcode = state.activeScanMode == 'Barcode';
    final viewportH = widget.compact ? 160.0 : 210.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mode toggle bar ────────────────────────────────────────────
        Container(
          color: kPrimary,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            _ModeBtn(
              label: 'Barcode / QR',
              icon: Icons.qr_code_scanner_rounded,
              active: isBarcode,
              onTap: () {
                _stopRfid();
                state.setScanMode('Barcode');
                _ctrl.start();
              },
            ),
            const SizedBox(width: 10),
            _ModeBtn(
              label: 'RFID',
              icon: Icons.wifi_rounded,
              active: !isBarcode,
              onTap: () {
                state.setScanMode('RFID');
                _ctrl.stop();
              },
            ),
            if (isBarcode) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  _ctrl.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _torchOn ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: _torchOn ? kPrimary : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ]),
        ),

        // ── Camera (Barcode mode) ──────────────────────────────────────
        if (isBarcode)
          SizedBox(
            height: viewportH,
            width: double.infinity,
            child: Stack(children: [
              MobileScanner(controller: _ctrl, onDetect: _onDetect),
              Center(child: _ScanOverlay(compact: widget.compact)),
              Positioned(
                bottom: 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('Continuous scan',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ]),
          )

        // ── RFID bulk scan panel ───────────────────────────────────────
        else
          _broadcastSupported
              ? _BroadcastPanel(
                  scanning: _rfidScanning,
                  tagCount: _sessionEpcs.length,
                  onStart: _startRfid,
                  onStop: _stopRfid,
                )
              : _KeyboardWedgePanel(
                  controller: _rfidController,
                  focusNode: _rfidFocus,
                  sessionCount: _sessionEpcs.length,
                  onChanged: _onRfidChanged,
                  onSubmit: () => _submitRfidManual(),
                ),
      ],
    );
  }
}

// ── Broadcast RFID panel ──────────────────────────────────────────────────────
class _BroadcastPanel extends StatelessWidget {
  final bool scanning;
  final int tagCount;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _BroadcastPanel({
    required this.scanning,
    required this.tagCount,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _PulsingIcon(active: scanning),
                const SizedBox(width: 10),
                Text(
                  scanning ? 'Scanning for tags…' : 'RFID ready',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ]),
              if (tagCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color:
                            const Color(0xFF3B82F6).withOpacity(0.5)),
                  ),
                  child: Text(
                    '$tagCount tag${tagCount == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Start / Stop button
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: scanning
                  ? _ActionBtn(
                      key: const ValueKey('stop'),
                      label: 'Stop Scanning',
                      icon: Icons.stop_circle_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: onStop,
                    )
                  : _ActionBtn(
                      key: const ValueKey('start'),
                      label: 'Start Scanning',
                      icon: Icons.play_circle_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: onStart,
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Hint
          Row(children: const [
            Icon(Icons.info_outline_rounded,
                color: Colors.white24, size: 12),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Point the T2 at your assets and tap Start — '
                'all UHF tags in range are read automatically.',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Start / Stop action button ────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ── Keyboard-wedge fallback panel ─────────────────────────────────────────────
class _KeyboardWedgePanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int sessionCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const _KeyboardWedgePanel({
    required this.controller,
    required this.focusNode,
    required this.sessionCount,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _PulsingIcon(active: true),
                const SizedBox(width: 10),
                const Text('RFID reader active',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              if (sessionCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: const Color(0xFF3B82F6)
                            .withOpacity(0.5)),
                  ),
                  child: Text(
                    '$sessionCount tag${sessionCount == 1 ? '' : 's'} scanned',
                    style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Waiting for RFID tag…',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: const Color(0xFF3B82F6).withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color:
                        const Color(0xFF3B82F6).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF3B82F6), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Color(0xFF3B82F6)),
                onPressed: onSubmit,
              ),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ],
      ),
    );
  }
}

// ── Mode button ───────────────────────────────────────────────────────────────
class _ModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? kPrimary : Colors.white70),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? kPrimary : Colors.white70)),
              ],
            ),
          ),
        ),
      );
}

// ── Pulsing RFID icon ─────────────────────────────────────────────────────────
class _PulsingIcon extends StatefulWidget {
  final bool active;
  const _PulsingIcon({this.active = true});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ac);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Icon(
          Icons.wifi_rounded,
          color: widget.active
              ? Color.fromRGBO(59, 130, 246, _anim.value)
              : Colors.white24,
          size: 28,
        ),
      );
}

// ── Scan overlay ──────────────────────────────────────────────────────────────
class _ScanOverlay extends StatefulWidget {
  final bool compact;
  const _ScanOverlay({this.compact = false});

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ac);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.compact ? 130.0 : 160.0;
    final h = widget.compact ? 90.0 : 120.0;
    return Center(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(children: [
          CustomPaint(size: Size(w, h), painter: _CornerPainter()),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Positioned(
              left: 10,
              right: 10,
              top: 10 + _anim.value * (h - 20),
              child: Container(
                  height: 2,
                  color:
                      const Color(0xFF3B82F6).withOpacity(0.8)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const len = 22.0;
    const r = 4.0;
    canvas.drawPath(
        Path()
          ..moveTo(0, len)
          ..lineTo(0, r)
          ..arcToPoint(const Offset(r, 0),
              radius: const Radius.circular(r))
          ..lineTo(len, 0),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len, 0)
          ..lineTo(size.width - r, 0)
          ..arcToPoint(Offset(size.width, r),
              radius: const Radius.circular(r))
          ..lineTo(size.width, len),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - len)
          ..lineTo(0, size.height - r)
          ..arcToPoint(Offset(r, size.height),
              radius: const Radius.circular(r))
          ..lineTo(len, size.height),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len, size.height)
          ..lineTo(size.width - r, size.height)
          ..arcToPoint(Offset(size.width, size.height - r),
              radius: const Radius.circular(r))
          ..lineTo(size.width, size.height - len),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}