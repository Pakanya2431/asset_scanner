package com.example.asset_scanner

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.uhf.api.cls.Reader
import com.uhf.base.UHFManager
import com.uhf.base.UHFModuleType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RfidSdkPlugin : FlutterPlugin, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scanning = false
    private var reader: Reader? = null

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
            val mgr = UHFManager.getUHFImplSigleInstance(UHFModuleType.UM_MODULE)
            val r = mgr as Reader
            reader = r
            r.powerOn()
            val listener = object : com.uhf.api.cls.ReadListener {
                override fun tagRead(rd: Reader, tags: Array<Reader.TAGINFO>?) {
                    tags?.forEach { tag ->
                        val bytes = tag.EpcId ?: return@forEach
                        val epc = bytes.joinToString("") { "%02X".format(it) }
                        mainHandler.post { eventSink?.success(epc) }
                    }
                }
            }
            r.addReadListener(listener)
            val option = Reader.BackReadOption()
            option.ReadDuration = 0
            r.StartReading(intArrayOf(1), 1, option)
        } catch (e: Exception) {
            Log.e(TAG, "RFID start error: ${e.message}")
            scanning = false
        }
    }

    private fun stopScanning() {
        if (!scanning) return
        scanning = false
        Log.d(TAG, "RFID scanning stopped")
        try {
            reader?.StopReading()
        } catch (e: Exception) {
            Log.e(TAG, "RFID stop error: ${e.message}")
        }
        reader = null
    }
}
