package com.example.asset_scanner

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.uhf.base.UHFManager
import com.uhf.base.UHFModuleType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class RfidSdkPlugin : FlutterPlugin, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scanning = false
    private var mgr: Any? = null
    private val executor = Executors.newSingleThreadExecutor()

    companion object {
        private const val TAG = "RfidSdkPlugin"
        private const val EVENT_CHANNEL = "com.asset_scanner/rfid_events"
        private const val METHOD_CHANNEL = "com.asset_scanner/rfid_control"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        EventChannel(binding.binaryMessenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopScanning()
        eventSink = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> { startScanning(); result.success(true) }
            "stopScan" -> { stopScanning(); result.success(true) }
            "isSupported" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        stopScanning()
        eventSink = null
    }

    private fun startScanning() {
        if (scanning) return
        scanning = true
        Log.d(TAG, "RFID scanning started")
        try {
            UHFManager.con = context
            val m = UHFManager.getUHFImplSigleInstance(UHFModuleType.UM_MODULE)
            mgr = m
            val cls = m.javaClass

            // Power on
            try { cls.getMethod("powerOn").invoke(m); Log.d(TAG, "powerOn OK") }
            catch (e: Exception) { Log.e(TAG, "powerOn failed: ${e.message}") }

            // Start inventory
            try { cls.getMethod("startInventoryTag").invoke(m); Log.d(TAG, "startInventoryTag OK") }
            catch (e: Exception) { Log.e(TAG, "startInventoryTag failed: ${e.message}") }

            // Poll for tags in background thread
            val seenTags = mutableSetOf<String>()
            executor.execute {
                while (scanning) {
                    try {
                        val result = cls.getMethod("readTagFromBuffer").invoke(m)
                        if (result != null) {
                            // result could be a TAGINFO or String
                            val epc = extractEpc(result)
                            if (epc != null && epc.isNotEmpty() && !seenTags.contains(epc)) {
                                seenTags.add(epc)
                                Log.d(TAG, "Tag read: $epc")
                                mainHandler.post { eventSink?.success(epc) }
                            }
                        }
                    } catch (e: Exception) {
                        // ignore polling errors
                    }
                    Thread.sleep(100)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "RFID start error: ${e.message}")
            scanning = false
        }
    }

    private fun extractEpc(obj: Any): String? {
        return try {
            // Try EpcId field (byte array)
            val field = obj.javaClass.getField("EpcId")
            val epcId = field.get(obj)
            when (epcId) {
                is ByteArray -> epcId.joinToString("") { "%02X".format(it) }
                is String -> epcId
                else -> obj.toString()
            }
        } catch (e: Exception) {
            try {
                // Try toString
                val str = obj.toString()
                if (str.length >= 4) str else null
            } catch (e2: Exception) { null }
        }
    }

    private fun stopScanning() {
        if (!scanning) return
        scanning = false
        Log.d(TAG, "RFID scanning stopped")
        try {
            val m = mgr
            if (m != null) {
                val cls = m.javaClass
                try { cls.getMethod("stopInventory").invoke(m); Log.d(TAG, "stopInventory OK") }
                catch (e: Exception) { Log.e(TAG, "stopInventory failed: ${e.message}") }
                try { cls.getMethod("powerOff").invoke(m); Log.d(TAG, "powerOff OK") }
                catch (e: Exception) { Log.e(TAG, "powerOff failed: ${e.message}") }
            }
        } catch (e: Exception) {
            Log.e(TAG, "RFID stop error: ${e.message}")
        }
        mgr = null
    }
}
