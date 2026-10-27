package com.netri.exam.netri_exam

import android.content.Context
import android.content.Intent
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
            // 1. Blokir Tangkapan Layar & Jaga Layar Tetap Menyala
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
            )

            // Simpan volume awal sebelum dipaksa ke maksimal
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalMusicVolume < 0) {
                originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            }

            // 2. Kecerahan Layar Maksimal (100% / 1.0f)
            enforceMaxBrightness()

            // 3. Suara / Volume Maksimal (100%)
            enforceMaxVolume()

            // 4. Layar Penuh Immersive Sticky (Sembunyikan Status Bar & Navigasi)
            applyImmersiveMode()

            // 5. Tutup notifikasi jika sedang terbuka
            collapseStatusBar()

            // 6. Jalankan enforcer berkala agar tidak bisa dikecilkan atau dibuka notifikasinya
            mainHandler.removeCallbacks(lockdownEnforcerRunnable)
            mainHandler.post(lockdownEnforcerRunnable)
        }
    }

    private fun disableLockdown() {
        isLockdownActive = false
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()

        runOnUiThread {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
            )

            // Kembalikan kecerahan layar ke pengaturan pengguna
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
            layoutParams.screenBrightness = 1.0f // Kecerahan 100%
            window.attributes = layoutParams
        } catch (e: Exception) {}
    }

    private fun enforceMaxVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Buka mode mute jika ponsel dalam keadaan hening
            if (audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            }

            val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)

            val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
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

    // Menarik kembali aplikasi ke layar paling depan jika ada upaya keluar
    private fun bringAppToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {}
    }

    private fun startAlarmSound(durationMs: Long = 5000L) {
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
                    }
                }

                alarmMediaPlayer?.setVolume(1.0f, 1.0f)
                if (alarmMediaPlayer?.isPlaying == false) {
                    alarmMediaPlayer?.start()
                }

                // Hentikan otomatis tepat setelah durasi tertentu (bawaan: 5 detik)
                alarmTimerRunnable?.let { mainHandler.removeCallbacks(it) }
                alarmTimerRunnable = Runnable {
                    stopAlarmSound()
                }
                mainHandler.postDelayed(alarmTimerRunnable!!, durationMs)

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
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

    // Deteksi jika jendela kehilangan fokus (misal notifikasi ditarik atau split screen)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isLockdownActive) {
            if (!hasFocus) {
                // Notifikasi ditarik atau recent apps dibuka: segera tutup dan bunyikan sirine
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
