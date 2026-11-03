package com.netri.exam.netri_exam

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

// Service Pengawal Latar Belakang (Exam NETRI Watchdog)
// Menjaga sesi ujian tetap hidup dan menarik paksa kembali MainActivity ke layar depan
// apabila siswa berhasil keluar sementara menggunakan sapuan navigasi gerakan (Gesture)
class ExamGuardService : Service() {

    companion object {
        private const val CHANNEL_ID = "netri_exam_guard_channel"
        private const val NOTIFICATION_ID = 9901

        @Volatile
        var isGuardActive: Boolean = false

        @Volatile
        var isActivityInForeground: Boolean = true

        @Volatile
        var isInGracePeriod: Boolean = false

        @Volatile
        var currentTaskId: Int = -1

        // Memulai service pengawal ujian
        fun startGuard(context: Context, taskId: Int) {
            currentTaskId = taskId
            isGuardActive = true
            try {
                val intent = Intent(context, ExamGuardService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {}
        }

        // Menghentikan service pengawal saat ujian selesai
        fun stopGuard(context: Context) {
            isGuardActive = false
            try {
                val intent = Intent(context, ExamGuardService::class.java)
                context.stopService(intent)
            } catch (e: Exception) {}
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    // Loop pengawas latar belakang setiap 200ms untuk mengembalikan layar ujian jika siswa swipe keluar
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (!isGuardActive) {
                stopSelf()
                return
            }

            if (!isActivityInForeground && !isInGracePeriod) {
                relaunchExamActivity()
            }

            handler.postDelayed(this, 200)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundSafely()
        handler.removeCallbacks(watchdogRunnable)
        handler.postDelayed(watchdogRunnable, 200)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundSafely()
        handler.removeCallbacks(watchdogRunnable)
        handler.postDelayed(watchdogRunnable, 200)
        return START_STICKY
    }

    // Membangun notifikasi persisten pengawal ujian dan menjalankan startForeground sesuai versi Android
    private fun startForegroundSafely() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Pengawal Sesi Ujian NETRI Exam",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Menjaga layar ujian tetap terkunci dan mencegah keluar aplikasi"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(channel)
            }

            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val notification = builder
                .setContentTitle("Ujian NETRI Exam Sedang Berlangsung")
                .setContentText("Mode terkunci aktif — Dilarang keluar dari lembar ujian")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {}
    }

    // Menarik paksa kembali MainActivity ke permukaan layar depan
    private fun relaunchExamActivity() {
        try {
            if (currentTaskId != -1) {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.moveTaskToFront(currentTaskId, ActivityManager.MOVE_TASK_NO_USER_ACTION)
            }
        } catch (e: Exception) {}

        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("FORCE_RELAUNCH_ALARM", true)
            }
            startActivity(intent)
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        handler.removeCallbacks(watchdogRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
