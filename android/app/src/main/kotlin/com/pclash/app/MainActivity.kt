package com.pclash.app

import android.content.Intent
import android.net.VpnService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * MainActivity - Entry point for Android
 * 
 * Handles platform channel communication for VPN control.
 */
class MainActivity: FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "com.pclash.app/vpn"
        private const val VPN_REQUEST_CODE = 100
    }

    private var pendingResult: Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> handleStartVpn(call, result)
                "stopVpn" -> handleStopVpn(result)
                "checkVpnStatus" -> handleCheckVpnStatus(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleStartVpn(call: MethodCall, result: Result) {
        val mihomoPort = call.argument<Int>("mihomoPort") ?: 7890
        val apiPort = call.argument<Int>("apiPort") ?: 9090
        val secret = call.argument<String>("secret") ?: ""
        val configPath = call.argument<String>("configPath")

        // Request VPN permission
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // Permission already granted, start VPN directly
            startVpnService(mihomoPort, apiPort, secret, configPath)
            result.success(true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                // User granted permission
                val call = pendingResult
                if (call != null) {
                    call.success(true)
                    pendingResult = null
                }
            } else {
                // User denied
                val call = pendingResult
                if (call != null) {
                    call.error("PERMISSION_DENIED", "User denied VPN permission", null)
                    pendingResult = null
                }
            }
        }
    }

    private fun startVpnService(
        mihomoPort: Int,
        apiPort: Int,
        secret: String,
        configPath: String?
    ) {
        val intent = Intent(this, PClashVpnService::class.java).apply {
            action = PClashVpnService.ACTION_START
            putExtra(PClashVpnService.EXTRA_MIHOMO_PORT, mihomoPort)
            putExtra(PClashVpnService.EXTRA_API_PORT, apiPort)
            putExtra(PClashVpnService.EXTRA_SECRET, secret)
            configPath?.let {
                putExtra(PClashVpnService.EXTRA_CONFIG_PATH, it)
            }
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun handleStopVpn(result: Result) {
        val intent = Intent(this, PClashVpnService::class.java).apply {
            action = PClashVpnService.ACTION_STOP
        }
        startService(intent)
        result.success(true)
    }

    private fun handleCheckVpnStatus(result: Result) {
        // Check if VPN service is running
        val isRunning = false // TODO: Implement status check
        result.success(isRunning)
    }
}
