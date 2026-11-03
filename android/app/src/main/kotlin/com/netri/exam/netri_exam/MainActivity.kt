package com.netri.exam.netri_exam

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.ActionMode
import android.view.KeyEvent
import android.view.MotionEvent
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
    private var lockdownStartTime: Long = 0L
    private var lastPinRequestTime: Long = 0L
    private val STARTUP_GRACE_PERIOD_MS = 5000L
    private val PIN_DIALOG_GRACE_MS = 6000L

    // Status deteksi floating window / overlay dan status sematkan layar (Lock Task)
    private var isWindowObscured = false
    private var isTopResumed = true
    private var wasPinnedOnce = false
    private var lastReportedPinned: Boolean? = null
    private var lastReportedObscured: Boolean? = null

    private var originalBrightness: Float = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
    private var originalMusicVolume: Int = -1
    private var originalAlarmVolume: Int = -1

    // Media player & AudioTrack untuk memutar alarm suara "Aku Nyontek!" dan sirine darurat
    private var voiceMediaPlayer: MediaPlayer? = null
    private var sirenAudioTrack: AudioTrack? = null
    private var fallbackToneGenerator: ToneGenerator? = null
    private var sirenPcmBuffer: ShortArray? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var alarmTimerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Reset kondisi awal saat aplikasi baru dipasang/dibuka agar tidak ada sirine aktif
        isLockdownActive = false
        lockdownStartTime = 0L
        lastPinRequestTime = 0L
        isWindowObscured = false
        wasPinnedOnce = false
        stopAlarmSound()
    }

    // Loop pengawas aktif (setiap 500ms) untuk mengunci kecerahan 100%, volume 100%, dan memantau Lock Task
    private val lockdownEnforcerRunnable = object : Runnable {
        override fun run() {
            if (isLockdownActive) {
                enforceMaxBrightness()
                enforceMaxVolume()
                applyImmersiveMode()

                val pinnedNow = isInLockTaskMode()
                if (pinnedNow) {
                    wasPinnedOnce = true
                } else if (wasPinnedOnce && !isInPinDialogGracePeriod()) {
                    // Siswa melepas sematan layar di tengah ujian: bunyikan sirine 5 detik
                    startAlarmSound(5000L)
                }

                // Jangan panggil collapseStatusBar saat dialog sistem Sematkan Layar sedang menunggu konfirmasi siswa
                if (pinnedNow || !isInPinDialogGracePeriod()) {
                    collapseStatusBar()
                }

                notifyFlutterStateIfChanged()
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
                "checkScreenClear" -> {
                    result.success(isScreenClear())
                }
                "isLockTaskActive" -> {
                    result.success(isInLockTaskMode())
                }
                "requestLockTask" -> {
                    requestScreenPinning()
                    result.success(isInLockTaskMode())
                }
                "openSecuritySettings" -> {
                    openSecuritySettingsForPinning()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Memeriksa apakah tidak ada floating app / overlay yang sedang menutupi atau mencuri fokus layar
    private fun isScreenClear(): Boolean {
        val multiWindow = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) isInMultiWindowMode else false
        return !isWindowObscured && isTopResumed && hasWindowFocus() && !multiWindow
    }

    // Memeriksa apakah aplikasi sudah berada dalam Lock Task Mode (Pinned atau Device Owner Locked)
    private fun isInLockTaskMode(): Boolean {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
            } else {
                @Suppress("DEPRECATION")
                am.isInLockTaskMode
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isInStartupGracePeriod(): Boolean {
        return (System.currentTimeMillis() - lockdownStartTime) < STARTUP_GRACE_PERIOD_MS
    }

    private fun isInPinDialogGracePeriod(): Boolean {
        return (System.currentTimeMillis() - lastPinRequestTime) < PIN_DIALOG_GRACE_MS
    }

    // Mengaktifkan paket Lock Task otomatis jika perangkat dikonfigurasi sebagai Device Owner sekolah
    private fun configureDeviceOwnerIfAvailable() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, NetriDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
            }
        } catch (e: Exception) {}
    }

    // Meminta sistem Android menyematkan layar (dan otomatis menutup semua floating window freeform saat aktif)
    private fun requestScreenPinning() {
        lastPinRequestTime = System.currentTimeMillis()
        runOnUiThread {
            configureDeviceOwnerIfAvailable()
            try {
                if (!isInLockTaskMode()) {
                    startLockTask()
                }
            } catch (e: Exception) {}
            // Periksa ulang status setelah dialog ditampilkan / disetujui
            mainHandler.postDelayed({ notifyFlutterStateIfChanged() }, 600)
            mainHandler.postDelayed({ notifyFlutterStateIfChanged() }, 1800)
        }
    }

    // Membuka pengaturan keamanan Android jika fitur Sematkan Layar di HP siswa masih nonaktif
    private fun openSecuritySettingsForPinning() {
        lastPinRequestTime = System.currentTimeMillis()
        try {
            val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            } catch (e2: Exception) {}
        }
    }

    // Mengirim pembaruan status Lock Task & Obscured ke Flutter bila terjadi perubahan
    private fun notifyFlutterStateIfChanged() {
        val pinned = isInLockTaskMode()
        val obscured = !isScreenClear() && !isInPinDialogGracePeriod()
        if (pinned != lastReportedPinned || obscured != lastReportedObscured) {
            lastReportedPinned = pinned
            lastReportedObscured = obscured
            runOnUiThread {
                try {
                    methodChannel?.invokeMethod(
                        "onLockStateChanged",
                        mapOf(
                            "isPinned" to pinned,
                            "isObscured" to obscured
                        )
                    )
                } catch (e: Exception) {}
            }
        }
    }

    private fun enableLockdown() {
        isLockdownActive = true
        isWindowObscured = false
        wasPinnedOnce = false
        lastReportedPinned = null
        lastReportedObscured = null
        lockdownStartTime = System.currentTimeMillis()
        lastPinRequestTime = System.currentTimeMillis()

        runOnUiThread {
            // 1. Blokir tangkapan layar, layar penuh, dan cegah layar mati
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
            )

            // Hentikan suara apapun yang sebelumnya sempat aktif
            stopAlarmSound()

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

            // 5. Sembunyikan semua overlay jenis SYSTEM_ALERT_WINDOW dari aplikasi lain (Android 12+ / API 31+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    window.setHideOverlayWindows(true)
                } catch (e: Exception) {}
            }

            // 6. Blokir interaksi sentuhan jika ada aplikasi mengambang yang menutupi layar
            window.decorView.filterTouchesWhenObscured = true

            // 7. Aktifkan Screen Pinning / Lock Task Mode (tanpa memanggil ACTION_CLOSE_SYSTEM_DIALOGS agar dialog sistem tidak tertutup)
            requestScreenPinning()

            // 8. Jalankan enforcer berkala
            mainHandler.removeCallbacks(lockdownEnforcerRunnable)
            mainHandler.postDelayed(lockdownEnforcerRunnable, 500)
        }
    }

    private fun disableLockdown() {
        isLockdownActive = false
        lockdownStartTime = 0L
        lastPinRequestTime = 0L
        isWindowObscured = false
        wasPinnedOnce = false
        lastReportedPinned = null
        lastReportedObscured = null
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()

        runOnUiThread {
            // Hentikan Screen Pinning / Lock Task bawaan Android
            try {
                if (isInLockTaskMode()) {
                    stopLockTask()
                }
            } catch (e: Exception) {}

            // Kembalikan visibilitas overlay jika sebelumnya disembunyikan
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    window.setHideOverlayWindows(false)
                } catch (e: Exception) {}
            }

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
        } catch (e: Exception) {}
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
            val phase = 2.0 * Math.PI * (carrierFreq * t - (freqDeviation / (2.0 * Math.PI * modFreq)) * Math.sin(2.0 * Math.PI * modFreq * t))
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

                // 1. Prioritas Utama: Putar rekaman suara berteriak "Aku Nyontek! Aku Nyontek! Aku Nyontek!" dari res/raw
                var playedVoice = false
                try {
                    val resId = resources.getIdentifier("alarm_nyontek", "raw", packageName)
                    if (resId != 0) {
                        val mp = MediaPlayer.create(this, resId)
                        if (mp != null) {
                            val audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                            mp.setAudioAttributes(audioAttributes)
                            mp.setVolume(1.0f, 1.0f)
                            mp.isLooping = true
                            mp.start()
                            voiceMediaPlayer = mp
                            playedVoice = true
                        }
                    }
                } catch (e: Exception) {
                    playedVoice = false
                }

                // 2. Cadangan: Jika MediaPlayer gagal, jalankan sintesis PCM sirine darurat wailing
                if (!playedVoice) {
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
                }

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

                voiceMediaPlayer?.let {
                    try {
                        if (it.isPlaying) {
                            it.stop()
                        }
                        it.release()
                    } catch (e: Exception) {}
                }
                voiceMediaPlayer = null

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
                voiceMediaPlayer = null
                sirenAudioTrack = null
                fallbackToneGenerator = null
            }
        }
    }

    // Deteksi flag sentuhan yang tertutup oleh floating window / overlay aplikasi lain
    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev != null) {
            val flags = ev.flags
            val obscured = (flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED) != 0 ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    (flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0)
            if (obscured != isWindowObscured) {
                isWindowObscured = obscured
                notifyFlutterStateIfChanged()
            }
            if (obscured && isLockdownActive) {
                startAlarmSound(5000L)
                methodChannel?.invokeMethod("onObscuredDetected", null)
                return true
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    // Deteksi perubahan status Top Resumed pada Android 10+ (Multi-Resume untuk Freeform Floating Window)
    override fun onTopResumedActivityChanged(isTopResumedActivity: Boolean) {
        super.onTopResumedActivityChanged(isTopResumedActivity)
        isTopResumed = isTopResumedActivity
        if (isLockdownActive && !isTopResumedActivity) {
            if (!isInStartupGracePeriod() && !isInPinDialogGracePeriod()) {
                startAlarmSound(5000L)
                bringAppToFront()
                methodChannel?.invokeMethod("onObscuredDetected", null)
            }
        }
        notifyFlutterStateIfChanged()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isLockdownActive && isInMultiWindowMode) {
            startAlarmSound(5000L)
            methodChannel?.invokeMethod("onObscuredDetected", null)
        }
        notifyFlutterStateIfChanged()
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

    // Deteksi jika jendela kehilangan fokus (misal notifikasi ditarik, floating app disentuh, atau recent apps dibuka)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            isWindowObscured = false
        }
        if (isLockdownActive) {
            if (!hasFocus) {
                // Jangan ganggu dialog sistem Sematkan Layar saat sedang meminta izin sematkan
                if (!isInPinDialogGracePeriod()) {
                    collapseStatusBar()
                    bringAppToFront()
                    if (!isInStartupGracePeriod()) {
                        startAlarmSound(5000L)
                    }
                }
            } else {
                enforceMaxBrightness()
                enforceMaxVolume()
                applyImmersiveMode()
            }
        }
        notifyFlutterStateIfChanged()
    }

    // Deteksi saat pengguna mencoba menekan tombol Home atau Recent Apps di Android
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(5000L)
                bringAppToFront()
                methodChannel?.invokeMethod("onUserLeaveHint", null)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(5000L)
                bringAppToFront()
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()
        super.onDestroy()
    }
}
