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
    private val STARTUP_GRACE_PERIOD_MS = 3000L
    private val PIN_DIALOG_GRACE_MS = 5000L

    // Status sematkan layar (Lock Task), status fokus, deteksi floating apps, dan mode navigasi
    private var wasPinnedOnce = false
    private var isActivityResumed = false
    private var isTopResumed = true
    private var isWindowObscured = false
    private var lastReportedPinned: Boolean? = null
    private var lastReportedThreeButton: Boolean? = null
    private var lastReportedScreenClear: Boolean? = null

    private var originalBrightness: Float = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
    private var originalMusicVolume: Int = -1
    private var originalAlarmVolume: Int = -1

    // AudioTrack & ToneGenerator untuk mensintesis sirine darurat yang tajam dan keras
    private var sirenAudioTrack: AudioTrack? = null
    private var fallbackToneGenerator: ToneGenerator? = null
    private var sirenPcmBuffer: ShortArray? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var alarmTimerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isLockdownActive = false
        isActivityResumed = true
        isTopResumed = true
        isWindowObscured = false
        lockdownStartTime = 0L
        lastPinRequestTime = 0L
        wasPinnedOnce = false
        stopAlarmSound()

        // Pantau perubahan daftar jendela dari layanan aksesibilitas bila aktif
        NetriWindowGuardService.onWindowHierarchyChanged = {
            notifyFlutterStateIfChanged()
        }
    }

    // Loop pengawas berkala (setiap 1000ms) untuk mengunci kecerahan 100%, volume 100%, dan memantau status Lock Task
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
                    // Siswa melepas sematan layar di tengah ujian: bunyikan sirine peringatan selama 15 detik
                    startAlarmSound(15000L)
                }

                // Jangan tutup panel status bar saat dialog Sematkan Layar sistem sedang menunggu konfirmasi siswa
                if (pinnedNow || !isInPinDialogGracePeriod()) {
                    collapseStatusBar()
                }

                notifyFlutterStateIfChanged()
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
                    val durationMs = (call.argument<Int>("durationMs") ?: 15000).toLong()
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
                "unpinScreen" -> {
                    try {
                        if (isInLockTaskMode()) {
                            stopLockTask()
                        }
                    } catch (e: Exception) {}
                    result.success(true)
                }
                "openSecuritySettings" -> {
                    openSecuritySettingsForPinning()
                    result.success(true)
                }
                "isThreeButtonNavigation" -> {
                    result.success(isThreeButtonNavigation())
                }
                "openNavigationSettings" -> {
                    openSecuritySettingsForPinning()
                    result.success(true)
                }
                "hasOverlayPermission" -> {
                    result.success(true)
                }
                "requestOverlayPermission" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Memeriksa apakah layar bersih dari floating apps, freeform window, PiP, split-screen, dan kehilangan fokus
    private fun isScreenClear(): Boolean {
        val multiWindow = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) isInMultiWindowMode else false
        val pipMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) isInPictureInPictureMode else false
        val windowGuardFloating = NetriWindowGuardService.hasVisibleFloatingWindow(this)
        val freeformShrunk = isActivityWidthShrunk()

        if (isWindowObscured || multiWindow || pipMode || windowGuardFloating || freeformShrunk) {
            return false
        }

        // Abaikan kehilangan fokus sesaat hanya ketika dialog sistem Sematkan Layar sedang muncul
        if (isInPinDialogGracePeriod()) {
            return true
        }

        return hasWindowFocus() && isTopResumed
    }

    // Mendeteksi jika jendela aplikasi kita sendiri diperkecil menjadi mode mengambang (freeform)
    private fun isActivityWidthShrunk(): Boolean {
        return try {
            val decor = window?.decorView ?: return false
            val w = decor.width
            if (w <= 0) return false
            val screenW = resources.displayMetrics.widthPixels
            if (screenW <= 0) return false
            w < (screenW * 88 / 100)
        } catch (e: Exception) {
            false
        }
    }

    // Memeriksa apakah aplikasi berada dalam Lock Task Mode (Pinned)
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

    private fun configureDeviceOwnerIfAvailable() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, NetriDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(packageName)) {
                dpm.setLockTaskPackages(adminComponent, arrayOf(packageName))
            }
        } catch (e: Exception) {}
    }

    // Meminta sematkan layar
    private fun requestScreenPinning() {
        lastPinRequestTime = System.currentTimeMillis()
        runOnUiThread {
            configureDeviceOwnerIfAvailable()
            try {
                if (!isInLockTaskMode()) {
                    startLockTask()
                }
            } catch (e: Exception) {}
            mainHandler.postDelayed({ notifyFlutterStateIfChanged() }, 1000)
        }
    }

    // Membuka pengaturan keamanan Android untuk fitur sematkan layar
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

    // Mendeteksi apakah HP menggunakan Navigasi Mode Tombol (3-Button) atau Mode Gestur (Gesture)
    private fun isThreeButtonNavigation(): Boolean {
        try {
            // Android standar (API 29+): 0 = 3-button, 1 = 2-button, 2 = gesture
            val navMode = Settings.Secure.getInt(contentResolver, "navigation_mode", -1)
            if (navMode == 2) return false

            // Xiaomi MIUI / HyperOS (force_fsg_nav_bar == 1 berarti mode gestur)
            val miui = Settings.Global.getInt(contentResolver, "force_fsg_nav_bar", 0)
            if (miui == 1) return false

            // Vivo FuntouchOS (navigation_gesture_on != 0 berarti mode gestur)
            val vivo = Settings.Secure.getInt(contentResolver, "navigation_gesture_on", 0)
            if (vivo != 0) return false

            // Huawei EMUI (navigationbar_is_min == 1 berarti mode gestur)
            val huawei = Settings.Global.getInt(contentResolver, "navigationbar_is_min", 0)
            if (huawei == 1) return false

            // Oppo / Realme ColorOS (hide_navigationbar_enable == 2 atau 3 berarti mode gestur)
            val oppo = Settings.Secure.getInt(contentResolver, "hide_navigationbar_enable", 0)
            if (oppo == 2 || oppo == 3) return false

            // Fallback resource sistem Android
            val resId = resources.getIdentifier("config_navBarInteractionMode", "integer", "android")
            if (resId > 0 && resources.getInteger(resId) == 2) return false
        } catch (e: Exception) {}
        return true
    }

    // Mengirim status pinned, kebersihan layar pra-ujian, dan mode tombol ke Flutter
    private fun notifyFlutterStateIfChanged() {
        val pinned = isInLockTaskMode()
        val threeButton = isThreeButtonNavigation()
        val screenClear = isScreenClear()
        if (pinned != lastReportedPinned ||
            threeButton != lastReportedThreeButton ||
            screenClear != lastReportedScreenClear
        ) {
            lastReportedPinned = pinned
            lastReportedThreeButton = threeButton
            lastReportedScreenClear = screenClear
            runOnUiThread {
                try {
                    methodChannel?.invokeMethod(
                        "onLockStateChanged",
                        mapOf(
                            "isPinned" to pinned,
                            "isObscured" to false,
                            "isThreeButton" to threeButton,
                            "isScreenClear" to screenClear
                        )
                    )
                } catch (e: Exception) {}
            }
        }
    }

    private fun enableLockdown() {
        isLockdownActive = true
        wasPinnedOnce = false
        lastReportedPinned = null
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

            stopAlarmSound()

            // Simpan volume awal sebelum dipaksa ke maksimal
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalMusicVolume < 0) {
                try {
                    originalMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                } catch (e: Exception) {}
            }

            // 2. Kecerahan layar 100%
            enforceMaxBrightness()

            // 3. Suara / volume 100%
            enforceMaxVolume()

            // 4. Layar penuh immersive sticky
            applyImmersiveMode()

            // 5. Sembunyikan overlay pada Android 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    window.setHideOverlayWindows(true)
                } catch (e: Exception) {}
            }

            // 6. Coba aktifkan Lock Task (Sematkan Layar) jika didukung HP
            requestScreenPinning()

            // 7. Loop enforcer berkala
            mainHandler.removeCallbacks(lockdownEnforcerRunnable)
            mainHandler.postDelayed(lockdownEnforcerRunnable, 1000)
        }
    }

    private fun disableLockdown() {
        isLockdownActive = false
        lockdownStartTime = 0L
        lastPinRequestTime = 0L
        wasPinnedOnce = false
        lastReportedPinned = null
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()

        runOnUiThread {
            try {
                if (isInLockTaskMode()) {
                    stopLockTask()
                }
            } catch (e: Exception) {}

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

            // Kembalikan kecerahan
            try {
                val layoutParams = window.attributes
                layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = layoutParams
            } catch (e: Exception) {}

            // Kembalikan volume
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
                layoutParams.screenBrightness = 1.0f
                window.attributes = layoutParams
            } catch (e: Exception) {}
        }
    }

    private fun enforceMaxVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            try {
                if (audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                }
            } catch (e: Exception) {}

            try {
                val maxMusic = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
            } catch (e: Exception) {}

            try {
                val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
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

    private fun collapseStatusBar() {
        try {
            val statusBarService = getSystemService("statusbar")
            val statusBarManager = Class.forName("android.app.StatusBarManager")
            val collapseMethod = statusBarManager.getMethod("collapsePanels")
            collapseMethod.invoke(statusBarService)
        } catch (e: Exception) {}
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

    // Memutar sirine darurat tajam selama durasi tertentu (bawaan: 15 detik)
    private fun startAlarmSound(durationMs: Long = 15000L) {
        runOnUiThread {
            try {
                // Jika sedang berputar, biarkan bunyi hingga selesai durasi tanpa di-restart berulang
                if (sirenAudioTrack?.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    return@runOnUiThread
                }

                enforceMaxVolume()
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

                // Hentikan otomatis HANYA jika durationMs > 0
                if (durationMs > 0) {
                    alarmTimerRunnable = Runnable {
                        stopAlarmSound()
                    }
                    mainHandler.postDelayed(alarmTimerRunnable!!, durationMs)
                }

            } catch (e: Exception) {
                playFallbackTone(if (durationMs > 0) durationMs else 15000L)
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

    // Blokir menu Share / Pencarian Web saat siswa memilih teks di soal
    override fun onActionModeStarted(mode: ActionMode?) {
        if (isLockdownActive && mode != null) {
            try {
                val menu = mode.menu
                val idsToRemove = mutableListOf<Int>()
                for (i in 0 until menu.size()) {
                    val item = menu.getItem(i)
                    val title = item.title?.toString()?.lowercase() ?: ""
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

    // Telan tombol volume agar suara tidak bisa dikecilkan
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isLockdownActive) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_MUTE,
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    enforceMaxVolume()
                    return true
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

    // Deteksi sentuhan terhalang jendela mengambang (floating apps / pop-up view / PiP / bubble)
    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev != null) {
            val flags = ev.flags
            val partiallyObscured = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                (flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0
            } else {
                false
            }
            val fullyObscured = (flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED) != 0
            val obscuredNow = fullyObscured || partiallyObscured

            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN,
                MotionEvent.ACTION_POINTER_DOWN -> {
                    // Pada awal sentuhan baru, InputDispatcher Android memverifikasi apakah ada jendela aplikasi lain di atas jendela kita
                    if (obscuredNow != isWindowObscured) {
                        isWindowObscured = obscuredNow
                        notifyFlutterStateIfChanged()
                    } else {
                        isWindowObscured = obscuredNow
                    }
                }
                MotionEvent.ACTION_MOVE,
                MotionEvent.ACTION_UP -> {
                    // Jika di tengah interaksi muncul jendela mengambang, langsung kunci status tertutup
                    if (obscuredNow && !isWindowObscured) {
                        isWindowObscured = true
                        notifyFlutterStateIfChanged()
                    }
                }
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    // Deteksi jika jendela kehilangan fokus (misal floating app menyala atau siswa menyentuh notifikasi)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Jangan mereset isWindowObscured = false saat hasFocus == true agar status floating app tidak hilang saat pindah fokus / tempel teks
        if (isLockdownActive) {
            if (!hasFocus) {
                if (!isInPinDialogGracePeriod()) {
                    collapseStatusBar()
                    if (!isInStartupGracePeriod()) {
                        startAlarmSound(15000L)
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

    // Deteksi perubahan status Top Resumed pada Android 10+ (Multi-Resume saat Floating App Chrome/WA tampil di atas aplikasi)
    override fun onTopResumedActivityChanged(isTopResumedActivity: Boolean) {
        super.onTopResumedActivityChanged(isTopResumedActivity)
        isTopResumed = isTopResumedActivity
        if (!isTopResumedActivity && isActivityResumed && !isInPinDialogGracePeriod()) {
            // Activity kita masih RESUMED tetapi bukan lagi Top Resumed -> ada jendela mengambang (Multi-Resume) aktif di atas layar!
            isWindowObscured = true
        }
        if (isLockdownActive && !isTopResumedActivity) {
            if (!isInStartupGracePeriod() && !isInPinDialogGracePeriod()) {
                startAlarmSound(15000L)
            }
        }
        notifyFlutterStateIfChanged()
    }

    // Deteksi multi-window / split-screen
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isInMultiWindowMode) {
            isWindowObscured = true
        }
        if (isLockdownActive && isInMultiWindowMode) {
            startAlarmSound(15000L)
        }
        notifyFlutterStateIfChanged()
    }

    // Deteksi saat pengguna keluar via tombol Home, Recent Apps, atau usap navigasi gerakan (Gesture)
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(15000L)
                methodChannel?.invokeMethod("onUserLeaveHint", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        notifyFlutterStateIfChanged()
    }

    override fun onPause() {
        super.onPause()
        isActivityResumed = false
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(15000L)
            }
        }
        notifyFlutterStateIfChanged()
    }

    override fun onDestroy() {
        NetriWindowGuardService.onWindowHierarchyChanged = null
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()
        super.onDestroy()
    }
}
