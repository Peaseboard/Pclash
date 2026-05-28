package com.peaseboard.pclash

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * PClash VPN Service - Android TUN mode
 * 
 * Creates a TUN device and routes all traffic through it.
 * The Mihomo core handles the actual proxying.
 */
class PClashVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.peaseboard.pclash.START"
        const val ACTION_STOP = "com.peaseboard.pclash.STOP"
        const val EXTRA_MIHOMO_PORT = "mihomo_port"
        const val EXTRA_API_PORT = "api_port"
        const val EXTRA_SECRET = "secret"
        const val EXTRA_CONFIG_PATH = "config_path"
        const val NOTIFICATION_CHANNEL_ID = "pclash_vpn"
        const val NOTIFICATION_ID = 1
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var mihomoProcess: Process? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startVpn(intent)
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    private fun startVpn(intent: Intent) {
        val mihomoPort = intent.getIntExtra(EXTRA_MIHOMO_PORT, 7890)
        val apiPort = intent.getIntExtra(EXTRA_API_PORT, 9090)
        val secret = intent.getStringExtra(EXTRA_SECRET) ?: ""
        val configPath = intent.getStringExtra(EXTRA_CONFIG_PATH)

        try {
            // 1. Build TUN device
            val builder = Builder()
                .addAddress("198.18.0.1", 30)
                .addDnsServer("8.8.8.8")
                .addDnsServer("1.1.1.1")
                .addRoute("0.0.0.0", 0)
                .setSession("PClash")
                .setMtu(9000)
                .setBlocking(false)

            // Bypass local network to avoid routing loops
            builder.addRoute("127.0.0.0", 8)

            vpnInterface = builder.establish()
                ?: throw IllegalStateException("Failed to establish VPN interface")

            // 2. Protect mihomo's own sockets from going through VPN
            // This prevents recursive routing

            // 3. Start notification
            startForeground(NOTIFICATION_ID, createNotification())

            // 4. Start mihomo process if config is provided
            if (configPath != null && File(configPath).exists()) {
                startMihomoProcess(configPath, mihomoPort, apiPort, secret)
            }

        } catch (e: Exception) {
            stopVpn()
            throw e
        }
    }

    private fun startMihomoProcess(
        configPath: String,
        mixedPort: Int,
        apiPort: Int,
        secret: String
    ) {
        try {
            // Get the application's native library directory
            val appInfo = applicationInfo
            val nativeLibDir = appInfo.nativeLibraryDir
            
            // Look for mihomo binary
            val mihomoBinary = File(nativeLibDir, "libmihomo.so")
            
            if (!mihomoBinary.exists()) {
                // Fallback: try to find in assets
                throw IllegalStateException("Mihomo binary not found at $nativeLibDir")
            }

            // Make executable
            mihomoBinary.setExecutable(true)

            // Build working directory
            val workDir = File(applicationContext.filesDir, "mihomo")
            workDir.mkdirs()

            // Start mihomo with TUN fd
            val processBuilder = ProcessBuilder(
                mihomoBinary.absolutePath,
                "-d", workDir.absolutePath,
                "-f", configPath,
                "--tun-fd", vpnInterface?.fd?.toString() ?: ""
            )
            
            processBuilder.directory(workDir)
            processBuilder.environment()["MIHOMO_MIXED_PORT"] = mixedPort.toString()
            processBuilder.environment()["MIHOMO_API_PORT"] = apiPort.toString()
            processBuilder.environment()["MIHOMO_SECRET"] = secret

            mihomoProcess = processBuilder.start()

        } catch (e: Exception) {
            throw RuntimeException("Failed to start mihomo: ${e.message}", e)
        }
    }

    private fun stopVpn() {
        // Stop mihomo process
        mihomoProcess?.destroy()
        mihomoProcess = null

        // Close TUN interface
        vpnInterface?.close()
        vpnInterface = null

        // Stop foreground service
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "PClash VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "PClash proxy service status"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("PClash")
            .setContentText("代理已连接")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onRevoke() {
        // Called when VPN is revoked by system
        stopVpn()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
