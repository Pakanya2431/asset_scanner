import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/asset.dart';
import '../theme.dart';

/// A self-contained scanner widget (Barcode/RFID toggle + continuous camera)
/// that can be embedded in any screen. Calls [onScanResult] after each scan.
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
  late MobileScannerController _ctrl;
  bool _torchOn = false;
  String? _lastCode;
  final _rfidController = TextEditingController();
  final _rfidFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _rfidController.dispose();
    _rfidFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final appState = context.read<AppState>();
      if (appState.activeScanMode == 'Barcode') _ctrl.start();
    } else if (state == AppLifecycleState.paused) {
      _ctrl.stop();
    }
  }

  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastCode) return;
    _lastCode = code;
    _processCode(code);
    // Debounce: same code can't re-trigger for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _lastCode = null;
    });
  }

  void _processCode(String code) {
    final state = context.read<AppState>();
    final result = state.registerScan(code);
    widget.onScanResult?.call(code, result);
  }

  void _submitRfid() {
    final code = _rfidController.text.trim();
    if (code.isEmpty) return;
    _processCode(code);
    _rfidController.clear();
    _rfidFocus.requestFocus();
  }

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
                Future.delayed(const Duration(milliseconds: 200),
                    () => _rfidFocus.requestFocus());
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
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? kPrimary : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ]),
        ),

        // ── Camera / RFID area ─────────────────────────────────────────
        if (isBarcode)
          SizedBox(
            height: viewportH,
            width: double.infinity,
            child: Stack(
              children: [
                // Always-on camera — no button needed
                MobileScanner(controller: _ctrl, onDetect: _onDetect),
                // Scan overlay
                Center(child: _ScanOverlay(compact: widget.compact)),
                // "Continuous scan" label
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
                          width: 6, height: 6,
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
              ],
            ),
          )
        else
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing RFID icon
                    _PulsingIcon(),
                    const SizedBox(width: 10),
                    const Text('RFID reader active',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rfidController,
                  focusNode: _rfidFocus,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'RFID code — auto-fill or type & submit',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Color(0xFF3B82F6)),
                      onPressed: _submitRfid,
                    ),
                  ),
                  onSubmitted: (_) => _submitRfid(),
                ),
              ],
            ),
          ),
      ],
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
        builder: (_, __) => Icon(Icons.wifi_rounded,
            color: Color.fromRGBO(59, 130, 246, _anim.value), size: 28),
      );
}

// ── Scan overlay (animated corner frame + scan line) ─────────────────────────
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
          CustomPaint(
              size: Size(w, h), painter: _CornerPainter()),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Positioned(
              left: 10,
              right: 10,
              top: 10 + _anim.value * (h - 20),
              child: Container(
                  height: 2,
                  color: const Color(0xFF3B82F6).withOpacity(0.8)),
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
          ..moveTo(0, len)..lineTo(0, r)
          ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
          ..lineTo(len, 0),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len, 0)..lineTo(size.width - r, 0)
          ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
          ..lineTo(size.width, len),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - len)..lineTo(0, size.height - r)
          ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
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
