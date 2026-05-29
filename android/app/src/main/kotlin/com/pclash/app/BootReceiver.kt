package com.pclash.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Boot receiver - Auto-start PClash on device boot
 */
class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Check if auto-start is enabled in preferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val autoStart = prefs.getBoolean("flutter.auto_start", false)
                
                if (autoStart) {
                    // Start VPN service
                    val vpnIntent = Intent(context, PClashVpnService::class.java).apply {
                        action = PClashVpnService.ACTION_START
                        // TODO: Load saved config from preferences
                    }
                    
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            context.startForegroundService(vpnIntent)
                        } else {
                            context.startService(vpnIntent)
                        }
                    } catch (e: Exception) {
                        // Ignore - service might not be ready
                    }
                }
            }
        }
    }
}
