package com.pclash.settings

import com.pclash.R
import com.pclash.preference.UiSettings
import com.pclash.service.settings.ServiceSettings

class InterfaceFragment : BaseSettingFragment() {
    companion object {
        private const val KEY_DARK_MODE = "dark_mode"
        private const val KEY_LANGUAGE = "language"
    }

    override fun onCreateDataStore(): SettingsDataStore {
        return SettingsDataStore().apply {
            on(KEY_DARK_MODE, UiSettings.DARK_MODE.asSource(ui))
            on(KEY_LANGUAGE, UiSettings.LANGUAGE.asSource(ui))

            onApply {
                service.commit {
                    put(ServiceSettings.LANGUAGE, ui.get(UiSettings.LANGUAGE))
                }

                requireActivity().recreate()
            }
        }
    }

    override val xmlResourceId: Int
        get() = R.xml.settings_interface
}