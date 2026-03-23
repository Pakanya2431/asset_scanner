package com.example.asset_scanner

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RfidSdkPlugin : FlutterPlugin, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scanning = false

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
        Log.d(TAG, "RFID scanning started (SDK placeholder)")
        // TODO: Initialize iData UHF SDK here when available
        // UHFManager.con = context
        // uhfManager = UHFManager.getUHFImplSigleInstance(UHFModuleType.UM_MODULE)
        // uhfManager.powerOn()
        // uhfManager.addReadListener { _, tags ->
        //     tags?.forEach { tag ->
        //         val epc = tag.EpcId?.joinToString("") { "%02X".format(it) } ?: return@forEach
        //         mainHandler.post { eventSink?.success(epc) }
        //     }
        // }
        // uhfManager.StartReading(intArrayOf(1), 1, Reader.BackReadOption())
    }

    private fun stopScanning() {
        if (!scanning) return
        scanning = false
        Log.d(TAG, "RFID scanning stopped")
        // TODO: uhfManager?.StopReading()
    }
}
