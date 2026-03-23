import 'package:flutter/services.dart';

/// Communicates with the native [RfidBroadcastPlugin] on Android.
///
/// Usage:
///   final service = RfidBroadcastService();
///   service.tagStream.listen((epc) => print('Tag: $epc'));
///   await service.startScan();
///   // ... later ...
///   await service.stopScan();
///   service.dispose();
class RfidBroadcastService {
  static const _eventChannel =
      EventChannel('com.asset_scanner/rfid_events');
  static const _methodChannel =
      MethodChannel('com.asset_scanner/rfid_control');

  Stream<String>? _tagStream;

  /// Stream of EPC strings — emits every time the iData T2 reads a tag.
  Stream<String> get tagStream {
    _tagStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
    return _tagStream!;
  }

  /// Tell the native layer to register the broadcast receiver.
  Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod('startScan');
    } on PlatformException catch (e) {
      // Ignore on non-iData devices (e.g. development emulator)
      debugPrint('[RfidBroadcastService] startScan error: ${e.message}');
    }
  }

  /// Tell the native layer to unregister the broadcast receiver.
  Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      debugPrint('[RfidBroadcastService] stopScan error: ${e.message}');
    }
  }

  /// Check if the RFID broadcast service is supported on this device.
  Future<bool> isSupported() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  void dispose() {
    stopScan();
  }
}

// ignore: avoid_print
void debugPrint(String message) => print(message);