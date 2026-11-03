package com.netri.exam.netri_exam

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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
    private var lockdownStartTime: Long = 0L
    private var lastPinRequestTime: Long = 0L
    private val STARTUP_GRACE_PERIOD_MS = 3000L
    private val PIN_DIALOG_GRACE_MS = 5000L

    // Status sematkan layar (Lock Task) dan mode navigasi
    private var wasPinnedOnce = false
    private var lastReportedPinned: Boolean? = null
    private var lastReportedThreeButton: Boolean? = null

    private var originalBrightness: Float = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
    private var originalMusicVolume: Int = -1
    private var originalAlarmVolume: Int = -1

    // Media player & ToneGenerator untuk memutar alarm suara "Aku Nyontek!"
    private var voiceMediaPlayer: MediaPlayer? = null
    private var fallbackToneGenerator: ToneGenerator? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var alarmTimerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isLockdownActive = false
        lockdownStartTime = 0L
        lastPinRequestTime = 0L
        wasPinnedOnce = false
        stopAlarmSound()
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
                    // Siswa melepas sematan layar di tengah ujian: bunyikan alarm suara terus-menerus
                    startAlarmSound(-1L)
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
                    val durationMs = (call.argument<Int>("durationMs") ?: -1).toLong()
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

    // Memeriksa apakah aplikasi sedang tidak dalam mode split-screen multi window
    private fun isScreenClear(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            !isInMultiWindowMode
        } else {
            true
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

    // Mengirim status pinned dan mode tombol ke Flutter
    private fun notifyFlutterStateIfChanged() {
        val pinned = isInLockTaskMode()
        val threeButton = isThreeButtonNavigation()
        if (pinned != lastReportedPinned || threeButton != lastReportedThreeButton) {
            lastReportedPinned = pinned
            lastReportedThreeButton = threeButton
            runOnUiThread {
                try {
                    methodChannel?.invokeMethod(
                        "onLockStateChanged",
                        mapOf(
                            "isPinned" to pinned,
                            "isObscured" to false,
                            "isThreeButton" to threeButton
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

    // Memutar alarm suara "Aku Nyontek!" selama durasi tertentu (bawaan: 5 detik)
    private fun startAlarmSound(durationMs: Long = 5000L) {
        runOnUiThread {
            try {
                // Jika sedang berputar, biarkan bunyi hingga selesai durasi tanpa di-restart berulang
                if (voiceMediaPlayer?.isPlaying == true) {
                    return@runOnUiThread
                }

                enforceMaxVolume()
                stopAlarmSound()

                var playedVoice = false

                // Cara 1: Putar suara teriakan "Aku Nyontek!" dari res/raw/alarm_nyontek.mp3
                try {
                    val resId = resources.getIdentifier("alarm_nyontek", "raw", packageName)
                    if (resId != 0) {
                        val afd = resources.openRawResourceFd(resId)
                        if (afd != null) {
                            val mp = MediaPlayer().apply {
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_ALARM)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                        .build()
                                )
                                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                isLooping = true
                                setVolume(1.0f, 1.0f)
                                prepare()
                                start()
                            }
                            afd.close()
                            voiceMediaPlayer = mp
                            playedVoice = true
                        }
                    }
                } catch (e: Exception) {
                    playedVoice = false
                }

                // Cara 2: Cadangan Flutter assets
                if (!playedVoice) {
                    try {
                        val afd = assets.openFd("flutter_assets/assets/audio/alarm_nyontek.mp3")
                        val mp = MediaPlayer().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build()
                            )
                            setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                            isLooping = true
                            setVolume(1.0f, 1.0f)
                            prepare()
                            start()
                        }
                        afd.close()
                        voiceMediaPlayer = mp
                        playedVoice = true
                    } catch (e: Exception) {
                        playedVoice = false
                    }
                }

                // Cara 3: Cadangan MediaPlayer.create
                if (!playedVoice) {
                    try {
                        val resId = resources.getIdentifier("alarm_nyontek", "raw", packageName)
                        if (resId != 0) {
                            val mp = MediaPlayer.create(this, resId)
                            if (mp != null) {
                                mp.isLooping = true
                                mp.setVolume(1.0f, 1.0f)
                                mp.start()
                                voiceMediaPlayer = mp
                                playedVoice = true
                            }
                        }
                    } catch (e: Exception) {
                        playedVoice = false
                    }
                }

                // Hentikan otomatis HANYA jika durationMs > 0
                // Jika durationMs <= 0 (misal -1L), alarm berteriak terus-menerus tanpa henti sampai tombol ditekan
                if (durationMs > 0) {
                    alarmTimerRunnable = Runnable {
                        stopAlarmSound()
                    }
                    mainHandler.postDelayed(alarmTimerRunnable!!, durationMs)
                }

            } catch (e: Exception) {
                playFallbackTone(if (durationMs > 0) durationMs else 5000L)
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

                fallbackToneGenerator?.let {
                    try {
                        it.stopTone()
                        it.release()
                    } catch (e: Exception) {}
                }
                fallbackToneGenerator = null
            } catch (e: Exception) {
                voiceMediaPlayer = null
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

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isLockdownActive) {
            if (!hasFocus) {
                if (!isInPinDialogGracePeriod()) {
                    collapseStatusBar()
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
    }

    // Deteksi saat pengguna keluar via tombol Home, Recent Apps, atau usap navigasi gerakan (Gesture)
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(-1L)
                methodChannel?.invokeMethod("onUserLeaveHint", null)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (isLockdownActive) {
            if (!isInPinDialogGracePeriod() && !isInStartupGracePeriod()) {
                startAlarmSound(-1L)
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(lockdownEnforcerRunnable)
        stopAlarmSound()
        super.onDestroy()
    }
}
