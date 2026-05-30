package com.pclash.pipeline

import com.pclash.common.settings.BaseSettings

data class Pipeline<T>(val input: T, val settings: BaseSettings)