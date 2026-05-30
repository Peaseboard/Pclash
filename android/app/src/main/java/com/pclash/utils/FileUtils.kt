package com.pclash.utils

import android.content.Context
import com.pclash.Constants
import java.io.File

val Context.logsDir: File
    get() = (externalCacheDir ?: cacheDir).resolve(Constants.LOG_DIR_NAME)