package com.netri.exam.netri_exam

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
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
    private var fallbackToneGenerator: ToneGenerator? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var alarmTimerRunnable: Runnable? = null

    // Loop pengawas aktif (setiap 500ms) untuk mengunci kecerahan 100%, volume 100%, dan menutup status bar
    private val lockdownEnforcerRunnable = object : Runnable {
        override fun run() {
            if (isLockdownActive) {
                enforceMaxBrightness()
                enforceMaxVolume()
                collapseStatusBar()
                mainHandler.postDelayed(this, 500)
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
                    val durationMs = (call.argument<Int>("durationMs") ?: 5000).toLong()
                    startAlarmSound(durationMs)
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
            // 1. Blokir tangkapan layar, layar penuh, dan cegah layar mati
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
            )

            // Simpan volume awal sebelum dipaksa ke maksimal
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalMusicVolume < 0) {
                try {
                    originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                } catch (e: Exception) {}
            }

            // 2. Kecerahan layar maksimal (100% / 1.0f)
            enforceMaxBrightness()

            // 3. Suara / volume maksimal (100%)
            enforceMaxVolume()

            // 4. Layar penuh immersive sticky (sembunyikan status bar & navigasi)
            applyImmersiveMode()

            // 5. Tutup notifikasi jika sedang terbuka
            collapseStatusBar()

            // 6. Kunci aplikasi menggunakan Screen Pinning / Lock Task bawaan sistem Android OS
            try {
                startLockTask()
            } catch (e: Exception) {}

            // 7. Jalankan enforcer berkala agar kecerahan dan volume tetap 100%
            mainHandler.removeCallbacks(lockdownEnforcerRunnable)
            mainHandler.post(lockdownEnforcerRunnable)
        }
    }

    private fun disableLockdown() {
        isLockdownActive = false
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()

        runOnUiThread {
            // Hentikan Screen Pinning / Lock Task bawaan Android
            try {
                stopLockTask()
            } catch (e: Exception) {}

            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
            )

            // Kembalikan kecerahan layar ke pengaturan pengguna
            try {
                val layoutParams = window.attributes
                layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = layoutParams
            } catch (e: Exception) {}

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
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
                }
            } catch (e: Exception) {}
        }
    }

    private fun enforceMaxBrightness() {
        runOnUiThread {
            try {
                val layoutParams = window.attributes
                layoutParams.screenBrightness = 1.0f // Kecerahan 100% penuh
                window.attributes = layoutParams
            } catch (e: Exception) {}
        }
    }

    private fun enforceMaxVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            // Coba buka ringer mode normal tanpa membiarkan kegagalan DND membatalkan volume
            try {
                if (audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                }
            } catch (e: Exception) {}

            // Paksa volume musik 100%
            try {
                val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
            } catch (e: Exception) {}

            // Paksa volume alarm 100%
            try {
                val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
            } catch (e: Exception) {}

            // Paksa volume sistem 100%
            try {
                val maxSystem = audioManager.getStreamMaxVolume(AudioManager.STREAM_SYSTEM)
                audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, maxSystem, 0)
            } catch (e: Exception) {}
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

    // Menutup paksa laci notifikasi jika siswa mencoba menariknya dari atas
    private fun collapseStatusBar() {
        try {
            val statusBarService = getSystemService("statusbar")
            val statusBarManager = Class.forName("android.app.StatusBarManager")
            val collapseMethod = statusBarManager.getMethod("collapsePanels")
            collapseMethod.invoke(statusBarService)
        } catch (e: Exception) {
            try {
                @Suppress("DEPRECATION")
                val closeDialog = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                sendBroadcast(closeDialog)
            } catch (e2: Exception) {}
        }
    }

    // Menarik kembali aplikasi ke layar paling depan menggunakan REORDER_TASKS
    private fun bringAppToFront() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
        } catch (e: Exception) {
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
            } catch (e2: Exception) {}
        }
    }

    private fun startAlarmSound(durationMs: Long = 5000L) {
        runOnUiThread {
            try {
                enforceMaxVolume()

                if (alarmMediaPlayer == null) {
                    val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

                    if (alarmUri != null) {
                        try {
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
                            }
                        } catch (e: Exception) {
                            alarmMediaPlayer = null
                        }
                    }
                }

                if (alarmMediaPlayer != null) {
                    alarmMediaPlayer?.setVolume(1.0f, 1.0f)
                    if (alarmMediaPlayer?.isPlaying == false) {
                        alarmMediaPlayer?.start()
                    }
                } else {
                    // Fallback generator nada darurat jika berkas nada dering tidak ditemukan
                    playFallbackTone(durationMs)
                }

                // Hentikan otomatis tepat setelah durasi tertentu (bawaan: 5 detik)
                alarmTimerRunnable?.let { mainHandler.removeCallbacks(it) }
                alarmTimerRunnable = Runnable {
                    stopAlarmSound()
                }
                mainHandler.postDelayed(alarmTimerRunnable!!, durationMs)

            } catch (e: Exception) {
                playFallbackTone(durationMs)
            }
        }
    }

    private fun playFallbackTone(durationMs: Long) {
        try {
            if (fallbackToneGenerator == null) {
                fallbackToneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
            }
            fallbackToneGenerator?.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, durationMs.toInt())
        } catch (e: Exception) {}
    }

    private fun stopAlarmSound() {
        runOnUiThread {
            try {
                alarmTimerRunnable?.let {
                    mainHandler.removeCallbacks(it)
                    alarmTimerRunnable = null
                }
                alarmMediaPlayer?.let {
                    if (it.isPlaying) {
                        it.stop()
                    }
                    it.release()
                }
                alarmMediaPlayer = null

                fallbackToneGenerator?.stopTone()
                fallbackToneGenerator?.release()
                fallbackToneGenerator = null
            } catch (e: Exception) {
                alarmMediaPlayer = null
                fallbackToneGenerator = null
            }
        }
    }

    // Intersepsi seluruh event tombol sebelum masuk ke sub-komponen
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isLockdownActive) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    enforceMaxVolume()
                    return true // Telan seluruh siklus tombol volume agar tidak bisa dikecilkan
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isLockdownActive) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    enforceMaxVolume()
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (isLockdownActive) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    enforceMaxVolume()
                    return true
                }
            }
        }
        return super.onKeyUp(keyCode, event)
    }

    // Deteksi jika jendela kehilangan fokus (misal notifikasi ditarik atau recent apps dibuka)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isLockdownActive) {
            if (!hasFocus) {
                // Notifikasi ditarik atau recent apps dibuka: segera tutup, bunyikan sirine, dan tarik ke depan
                collapseStatusBar()
                startAlarmSound(5000L)
                bringAppToFront()
            } else {
                enforceMaxBrightness()
                enforceMaxVolume()
                applyImmersiveMode()
            }
        }
    }

    // Deteksi saat pengguna mencoba menekan tombol Home atau Recent Apps di Android
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isLockdownActive) {
            startAlarmSound(5000L)
            bringAppToFront()
            methodChannel?.invokeMethod("onUserLeaveHint", null)
        }
    }

    override fun onPause() {
        super.onPause()
        if (isLockdownActive) {
            startAlarmSound(5000L)
            bringAppToFront()
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()
        super.onDestroy()
    }
}
