package com.netri.exam.netri_exam

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo

// Layanan pemeriksa daftar jendela sistem untuk mendeteksi aplikasi mengambang (Floating Apps / Freeform / PiP)
class NetriWindowGuardService : AccessibilityService() {

    companion object {
        @Volatile
        private var instance: NetriWindowGuardService? = null

        @Volatile
        var onWindowHierarchyChanged: (() -> Unit)? = null

        // Daftar paket sistem yang diizinkan (bukan aplikasi mengambang kecurangan)
        private val WHITELISTED_PACKAGES = setOf(
            "com.android.systemui",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller",
            "com.miui.securitycenter",
            "com.lbe.security.miui",
            "com.coloros.safecenter",
            "com.oplus.safecenter",
            "com.samsung.android.MtpApplication",
            "android"
        )

        fun isServiceActive(): Boolean = instance != null

        // Memeriksa apakah ada jendela aplikasi lain (Floating Window / Pop-up View / Split-Screen / PiP) yang tampil di layar
        fun hasVisibleFloatingWindow(context: Context): Boolean {
            val service = instance ?: return false
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false

            return try {
                val windowList = service.windows ?: return false
                if (windowList.isEmpty()) return false

                val metrics = context.resources.displayMetrics
                val screenWidth = metrics.widthPixels.coerceAtLeast(1)
                val screenHeight = metrics.heightPixels.coerceAtLeast(1)
                val screenArea = screenWidth.toLong() * screenHeight.toLong()
                val minSignificantArea = (screenArea * 2L) / 100L // Abaikan elemen sistem kecil < 2% luas layar

                val ownPackage = context.packageName
                val currentImePackage = getCurrentImePackage(context)

                var visibleAppWindowCount = 0
                val bounds = Rect()

                for (window in windowList) {
                    // Deteksi langsung jendela Picture-in-Picture atau pembagi Split-Screen
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && window.isInPictureInPictureMode) {
                        return true
                    }
                    if (window.type == AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER) {
                        return true
                    }

                    // Abaikan keyboard (IME) dan overlay aksesibilitas
                    if (window.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD ||
                        window.type == AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY
                    ) {
                        continue
                    }

                    window.getBoundsInScreen(bounds)
                    val width = bounds.width().coerceAtLeast(0)
                    val height = bounds.height().coerceAtLeast(0)
                    val area = width.toLong() * height.toLong()
                    if (area < minSignificantArea) {
                        continue
                    }

                    if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                        val pkg = try {
                            window.root?.packageName?.toString()
                        } catch (e: Exception) {
                            null
                        }

                        if (pkg != null) {
                            if (pkg == ownPackage ||
                                WHITELISTED_PACKAGES.contains(pkg) ||
                                (currentImePackage != null && pkg == currentImePackage)
                            ) {
                                if (pkg == ownPackage) {
                                    visibleAppWindowCount++
                                }
                                continue
                            }
                            // Jendela aplikasi pihak ketiga (misal Chrome, WhatsApp, Kalkulator, Browser) terlihat di layar
                            return true
                        } else {
                            // Jika root package tidak terbaca, periksa apakah ukuran jendela mengambang (tidak layar penuh)
                            val isFloatingSize = width < (screenWidth * 92 / 100) && height < (screenHeight * 88 / 100)
                            if (isFloatingSize) {
                                return true
                            }
                            visibleAppWindowCount++
                        }
                    }
                }

                // Jika terdapat lebih dari 1 jendela aplikasi aktif secara bersamaan di layar
                visibleAppWindowCount > 1
            } catch (e: Exception) {
                false
            }
        }

        private fun getCurrentImePackage(context: Context): String? {
            return try {
                val defaultIme = Settings.Secure.getString(
                    context.contentResolver,
                    Settings.Secure.DEFAULT_INPUT_METHOD
                )
                defaultIme?.substringBefore('/')
            } catch (e: Exception) {
                null
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        onWindowHierarchyChanged?.invoke()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event != null &&
            (event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED ||
                event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
        ) {
            onWindowHierarchyChanged?.invoke()
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }
}
