package com.netri.exam.netri_exam

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.netri.exam/lockdown"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureWindow" -> {
                    enableLockdown()
                    result.success(true)
                }
                "disableSecureWindow" -> {
                    disableLockdown()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableLockdown() {
        runOnUiThread {
            // 1. Blokir Tangkapan Layar & Rekam Layar (FLAG_SECURE)
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

            // 2. Layar Penuh Immersive Sticky (Sembunyikan Status Bar & Navigasi Bar)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let { controller ->
                    controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                    controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                )
            }
        }
    }

    private fun disableLockdown() {
        runOnUiThread {
            // Hapus proteksi saat ujian selesai, kembalikan ke antarmuka normal tanpa mengunci perangkat OS
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Terdeteksi ketika siswa menekan tombol Home atau Recent Apps di Android
        methodChannel?.invokeMethod("onUserLeaveHint", null)
    }
}
