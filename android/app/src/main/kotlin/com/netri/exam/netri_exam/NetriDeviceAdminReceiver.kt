package com.netri.exam.netri_exam

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

// Komponen penerima kebijakan Device Owner untuk mengaktifkan Lock Task Mode tanpa dialog pada perangkat sekolah
class NetriDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }
}
