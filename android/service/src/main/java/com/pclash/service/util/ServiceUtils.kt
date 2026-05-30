package com.pclash.service.util

import android.content.Context
import android.content.Intent
import android.net.VpnService
import com.pclash.common.ids.Intents
import com.pclash.common.utils.intent
import com.pclash.common.utils.startForegroundServiceCompat
import com.pclash.service.ClashService
import com.pclash.service.TunService
import com.pclash.service.settings.ServiceSettings

fun Context.startClashService(): Intent? {
    val startTun = ServiceSettings(this).get(ServiceSettings.ENABLE_VPN)

    if (startTun) {
        val vpnRequest = VpnService.prepare(this)
        if (vpnRequest != null)
            return vpnRequest

        startForegroundServiceCompat(TunService::class.intent)
    } else {
        startForegroundServiceCompat(ClashService::class.intent)
    }

    return null
}

fun Context.stopClashService() {
    sendBroadcastSelf(Intent(Intents.INTENT_ACTION_CLASH_REQUEST_STOP))
}