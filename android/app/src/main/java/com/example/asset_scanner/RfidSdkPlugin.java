package com.example.asset_scanner;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * RfidBroadcastPlugin
 *
 * Listens for iData T2 UHF RFID broadcast intents and forwards each
 * scanned EPC tag to Flutter via an EventChannel stream.
 *
 * iData T2 broadcast action : "com.android.server.scannerservice.broadcast"
 * EPC extra key             : "scannerdata"   (raw EPC string)
 *
 * If your T2 firmware uses different values, update the two constants below.
 */
public class RfidBroadcastPlugin implements FlutterPlugin, EventChannel.StreamHandler {

    // ── iData T2 broadcast constants ─────────────────────────────────────────
    // Check your device settings under: Settings → Scanner Settings → Output Mode
    // and set Output Mode = "Broadcast" with these action/key values.
    private static final String RFID_ACTION = "com.android.server.scannerservice.broadcast";
    private static final String RFID_DATA_KEY = "scannerdata";

    // ── Channel names (must match lib/services/rfid_broadcast_service.dart) ──
    private static final String EVENT_CHANNEL = "com.asset_scanner/rfid_events";
    private static final String METHOD_CHANNEL = "com.asset_scanner/rfid_control";

    private EventChannel.EventSink _eventSink;
    private Context _context;
    private BroadcastReceiver _receiver;
    private boolean _isRegistered = false;

    // ── FlutterPlugin ─────────────────────────────────────────────────────────
    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        _context = binding.getApplicationContext();

        // Event channel — streams EPC tags to Flutter
        new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL)
                .setStreamHandler(this);

        // Method channel — Flutter can call startScan / stopScan
        new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL)
                .setMethodCallHandler(this::onMethodCall);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        _unregisterReceiver();
        _eventSink = null;
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────────
    private void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "startScan":
                _registerReceiver();
                result.success(true);
                break;
            case "stopScan":
                _unregisterReceiver();
                result.success(true);
                break;
            case "isSupported":
                // Returns true — broadcast mode is always available on iData T2
                result.success(true);
                break;
            default:
                result.notImplemented();
        }
    }

    // ── EventChannel.StreamHandler ────────────────────────────────────────────
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        _eventSink = events;
        _registerReceiver();
    }

    @Override
    public void onCancel(Object arguments) {
        _unregisterReceiver();
        _eventSink = null;
    }

    // ── BroadcastReceiver ─────────────────────────────────────────────────────
    private void _registerReceiver() {
        if (_isRegistered || _context == null) return;

        _receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (!RFID_ACTION.equals(intent.getAction())) return;

                String epc = intent.getStringExtra(RFID_DATA_KEY);
                if (epc == null || epc.trim().isEmpty()) return;

                // Forward EPC to Flutter on the main thread
                if (_eventSink != null) {
                    _eventSink.success(epc.trim());
                }
            }
        };

        IntentFilter filter = new IntentFilter(RFID_ACTION);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            _context.registerReceiver(_receiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            _context.registerReceiver(_receiver, filter);
        }
        _isRegistered = true;
    }

    private void _unregisterReceiver() {
        if (!_isRegistered || _context == null || _receiver == null) return;
        try {
            _context.unregisterReceiver(_receiver);
        } catch (IllegalArgumentException ignored) {
            // Already unregistered — safe to ignore
        }
        _isRegistered = false;
        _receiver = null;
    }
}
