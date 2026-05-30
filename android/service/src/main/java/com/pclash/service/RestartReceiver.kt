package com.pclash.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pclash.common.utils.intent
import com.pclash.common.utils.startForegroundServiceCompat
import com.pclash.service.util.startClashService

class RestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null)
            return

        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
            }
            else -> return
        }

        context.startForegroundServiceCompat(ProfileBackgroundService::class.intent)

        if (ServiceStatusProvider.shouldStartClashOnBoot)
            context.startClashService()
    }
}