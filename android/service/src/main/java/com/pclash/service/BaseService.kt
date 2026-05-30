package com.pclash.service

import android.app.Service
import android.content.Context
import com.pclash.common.utils.createLanguageConfigurationContext
import com.pclash.service.settings.ServiceSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel

abstract class BaseService : Service(), CoroutineScope by CoroutineScope(Dispatchers.Default) {
    lateinit var settings: ServiceSettings

    override fun attachBaseContext(base: Context?) {
        settings = ServiceSettings(base ?: return super.attachBaseContext(base))

        val language = settings.get(ServiceSettings.LANGUAGE)

        super.attachBaseContext(base.createLanguageConfigurationContext(language))
    }

    override fun onDestroy() {
        super.onDestroy()

        cancel()
    }
}