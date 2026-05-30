package com.pclash.service.clash.module

import android.content.Context
import android.content.Intent
import com.pclash.common.ids.Intents
import com.pclash.core.Clash
import com.pclash.service.ServiceStatusProvider
import com.pclash.service.data.ProfileDao
import com.pclash.service.data.SelectedProxyDao
import com.pclash.service.util.resolveBaseDir
import com.pclash.service.util.resolveProfileFile
import kotlinx.coroutines.future.await
import kotlinx.coroutines.sync.Mutex

class ReloadModule(private val context: Context) : Module() {
    override val receiveBroadcasts: Set<String>
        get() = setOf(Intents.INTENT_ACTION_NETWORK_CHANGED, Intents.INTENT_ACTION_PROFILE_CHANGED)
    private val reloadMutex = Mutex()
    private var loadedCallback: (Exception?) -> Unit = {}

    override suspend fun onStart() {
        reload()
    }

    override suspend fun onBroadcastReceived(intent: Intent) {
        if (!reloadMutex.tryLock())
            return

        when (intent.action) {
            Intents.INTENT_ACTION_NETWORK_CHANGED, Intents.INTENT_ACTION_PROFILE_CHANGED -> {
                reload()
            }
        }

        reloadMutex.unlock()
    }


    fun onLoaded(callback: (Exception?) -> Unit) {
        loadedCallback = callback
    }

    private suspend fun reload() {
        try {
            val active = ProfileDao.queryActive()
                ?: throw NullPointerException("No profile selected")

            Clash.loadProfile(
                context.resolveProfileFile(active.id),
                context.resolveBaseDir(active.id).apply { mkdirs() }
            ).await()

            val remove = SelectedProxyDao.querySelectedForProfile(active.id)
                .filterNot { Clash.setSelector(it.proxy, it.selected) }
                .map { it.selected }

            SelectedProxyDao.removeSelectedForProfile(active.id, remove)

            ServiceStatusProvider.currentProfile = active.name

            loadedCallback(null)
        } catch (e: Exception) {
            loadedCallback(e)
        }
    }
}