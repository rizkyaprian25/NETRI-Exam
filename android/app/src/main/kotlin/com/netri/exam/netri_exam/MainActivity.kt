package com.netri.exam.netri_exam

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.ActionMode
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

    // AudioTrack untuk mensintesis suara sirine darurat yang tajam, keras, dan menusuk
    private var sirenAudioTrack: AudioTrack? = null
    private var fallbackToneGenerator: ToneGenerator? = null
    private var sirenPcmBuffer: ShortArray? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var alarmTimerRunnable: Runnable? = null

    // Loop pengawas aktif (setiap 500ms) untuk mengunci kecerahan 100%, volume 100%, dan menutup status bar
    private val lockdownEnforcerRunnable = object : Runnable {
        override fun run() {
            if (isLockdownActive) {
                enforceMaxBrightness()
                enforceMaxVolume()
                collapseStatusBar()
                applyImmersiveMode()
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

            // 8. Blokir interaksi sentuhan jika ada aplikasi mengambang (floating apps / chat bubble) yang menutupi layar
            window.decorView.filterTouchesWhenObscured = true
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

            // Kembalikan filter sentuhan
            try {
                window.decorView.filterTouchesWhenObscured = false
            } catch (e: Exception) {}

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

    // Menghasilkan 1 gelombang periodik penuh (0.4 detik = 2.5 siklus per detik)
    // Suara sirine darurat wailing tajam dengan rentang frekuensi 600 Hz - 1400 Hz dan harmonik ke-3
    private fun getOrCreateSirenBuffer(): ShortArray {
        sirenPcmBuffer?.let { return it }
        val sampleRate = 44100
        val durationSeconds = 0.4 // 400ms per siklus sapuan frekuensi
        val numSamples = (sampleRate * durationSeconds).toInt() // 17640 sampel
        val buffer = ShortArray(numSamples)

        val modFreq = 2.5 // Sapuan frekuensi 2.5 siklus per detik
        val carrierFreq = 1000.0 // Frekuensi tengah 1000 Hz
        val freqDeviation = 400.0 // Deviasi frekuensi (+- 400 Hz -> rentang 600 Hz s/d 1400 Hz)

        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            // Integrasi fase untuk sapuan frekuensi kontinu:
            // f(t) = carrierFreq - freqDeviation * cos(2*pi*modFreq*t)
            // phase(t) = 2*pi * (carrierFreq * t - (freqDeviation / (2*pi*modFreq)) * sin(2*pi*modFreq*t))
            val phase = 2.0 * Math.PI * (carrierFreq * t - (freqDeviation / (2.0 * Math.PI * modFreq)) * Math.sin(2.0 * Math.PI * modFreq * t))

            // Tambahkan harmonik ke-3 (25%) dan sedikit saturasi agar menghasilkan suara sirine darurat yang keras, tajam, dan tidak lembut
            val raw = 0.75 * Math.sin(phase) + 0.25 * Math.sin(3.0 * phase)
            val sample = (raw / 0.85 * 32767.0).toInt().coerceIn(-32768, 32767)
            buffer[i] = sample.toShort()
        }
        sirenPcmBuffer = buffer
        return buffer
    }

    private fun startAlarmSound(durationMs: Long = 5000L) {
        runOnUiThread {
            try {
                enforceMaxVolume()

                // Hentikan pemutaran sebelumnya jika masih aktif
                stopAlarmSound()

                val buffer = getOrCreateSirenBuffer()
                val sampleRate = 44100

                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val audioFormat = AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()

                val track = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    AudioTrack.Builder()
                        .setAudioAttributes(audioAttributes)
                        .setAudioFormat(audioFormat)
                        .setBufferSizeInBytes(buffer.size * 2)
                        .setTransferMode(AudioTrack.MODE_STATIC)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    AudioTrack(
                        audioAttributes,
                        audioFormat,
                        buffer.size * 2,
                        AudioTrack.MODE_STATIC,
                        AudioManager.AUDIO_SESSION_ID_GENERATE
                    )
                }

                track.write(buffer, 0, buffer.size)
                track.setLoopPoints(0, buffer.size, -1) // Loop sirine tak terputus
                track.setVolume(1.0f)
                track.play()

                sirenAudioTrack = track

                // Hentikan otomatis tepat setelah durasi tertentu (bawaan: 5 detik)
                alarmTimerRunnable = Runnable {
                    stopAlarmSound()
                }
                mainHandler.postDelayed(alarmTimerRunnable!!, durationMs)

            } catch (e: Exception) {
                // Cadangan ToneGenerator darurat jika AudioTrack gagal
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

                sirenAudioTrack?.let {
                    try {
                        if (it.playState == AudioTrack.PLAYSTATE_PLAYING) {
                            it.stop()
                        }
                        it.release()
                    } catch (e: Exception) {}
                }
                sirenAudioTrack = null

                fallbackToneGenerator?.let {
                    try {
                        it.stopTone()
                        it.release()
                    } catch (e: Exception) {}
                }
                fallbackToneGenerator = null
            } catch (e: Exception) {
                sirenAudioTrack = null
                fallbackToneGenerator = null
            }
        }
    }

    // Menghilangkan opsi "Web Search" dan "Share" saat siswa memilih teks di WebView/aplikasi
    override fun onActionModeStarted(mode: ActionMode?) {
        if (isLockdownActive && mode != null) {
            try {
                val menu = mode.menu
                val idsToRemove = mutableListOf<Int>()
                for (i in 0 until menu.size()) {
                    val item = menu.getItem(i)
                    val title = item.title?.toString()?.lowercase() ?: ""
                    // Hapus opsi pencarian web atau share aplikasi luar
                    if (title.contains("search") || title.contains("cari") ||
                        title.contains("share") || title.contains("bagikan") ||
                        item.intent != null) {
                        idsToRemove.add(item.itemId)
                    }
                }
                for (id in idsToRemove) {
                    menu.removeItem(id)
                }
            } catch (e: Exception) {}
        }
        super.onActionModeStarted(mode)
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
