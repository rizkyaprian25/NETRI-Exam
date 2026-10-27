package com.netri.exam.netri_exam

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
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

    private var isLockdownActive = false
    private var originalBrightness: Float = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
    private var originalMusicVolume: Int = -1
    private var originalAlarmVolume: Int = -1

    private var alarmMediaPlayer: MediaPlayer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Enforcer berkala untuk memastikan volume dan kecerahan tidak bisa dikecilkan selama ujian
    private val lockdownEnforcerRunnable = object : Runnable {
        override fun run() {
            if (isLockdownActive) {
                enforceMaxBrightness()
                enforceMaxVolume()
                mainHandler.postDelayed(this, 1000)
            }
        }
    }

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
                "startAlarmSound" -> {
                    startAlarmSound()
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    stopAlarmSound()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableLockdown() {
        isLockdownActive = true
        runOnUiThread {
            // 1. Blokir Tangkapan Layar & Jaga Layar Tetap Hidup
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )

            // 2. Kecerahan Layar Maksimal (100% / 1.0f)
            enforceMaxBrightness()

            // 3. Suara / Volume Maksimal (100%)
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalMusicVolume < 0) {
                originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            }
            enforceMaxVolume()

            // 4. Layar Penuh Immersive Sticky (Sembunyikan Status Bar & Navigasi Bar)
            applyImmersiveMode()

            // 5. Jalankan loop pengawas agar kecerahan & volume tidak bisa dikecilkan
            mainHandler.removeCallbacks(lockdownEnforcerRunnable)
            mainHandler.post(lockdownEnforcerRunnable)
        }
    }

    private fun disableLockdown() {
        isLockdownActive = false
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()

        runOnUiThread {
            // Hapus proteksi window
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )

            // Kembalikan kecerahan layar ke pengaturan bawaan sistem
            val layoutParams = window.attributes
            layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window.attributes = layoutParams

            // Kembalikan volume jika sebelumnya tersimpan
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalMusicVolume >= 0) {
                try {
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalMusicVolume, 0)
                } catch (e: Exception) {}
                originalMusicVolume = -1
            }
            if (originalAlarmVolume >= 0) {
                try {
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
                } catch (e: Exception) {}
                originalAlarmVolume = -1
            }

            // Kembalikan antarmuka normal
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            }
        }
    }

    private fun enforceMaxBrightness() {
        try {
            val layoutParams = window.attributes
            if (layoutParams.screenBrightness != 1.0f) {
                layoutParams.screenBrightness = 1.0f
                window.attributes = layoutParams
            }
        } catch (e: Exception) {}
    }

    private fun enforceMaxVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentMusic = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (currentMusic < maxMusic) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
            }

            val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val currentAlarm = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            if (currentAlarm < maxAlarm) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
            }
        } catch (e: Exception) {}
    }

    private fun applyImmersiveMode() {
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

    private fun startAlarmSound() {
        runOnUiThread {
            try {
                enforceMaxVolume()

                if (alarmMediaPlayer == null) {
                    val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

                    alarmMediaPlayer = MediaPlayer().apply {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        setDataSource(applicationContext, alarmUri)
                        isLooping = true
                        prepare()
                        start()
                    }
                } else if (!alarmMediaPlayer!!.isPlaying) {
                    alarmMediaPlayer!!.start()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun stopAlarmSound() {
        runOnUiThread {
            try {
                alarmMediaPlayer?.let {
                    if (it.isPlaying) {
                        it.stop()
                    }
                    it.release()
                }
                alarmMediaPlayer = null
            } catch (e: Exception) {
                alarmMediaPlayer = null
            }
        }
    }

    // Blokir tombol fisik volume agar suara tidak bisa dikecilkan selama ujian
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isLockdownActive) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    enforceMaxVolume()
                    return true // Telan aksi tombol volume agar volume tidak berkurang
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isLockdownActive && hasFocus) {
            enforceMaxBrightness()
            enforceMaxVolume()
            applyImmersiveMode()
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Terdeteksi ketika siswa menekan tombol Home atau Recent Apps di Android
        methodChannel?.invokeMethod("onUserLeaveHint", null)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()
        super.onDestroy()
    }
}
