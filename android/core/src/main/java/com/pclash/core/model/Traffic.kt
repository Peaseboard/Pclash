package com.pclash.core.model

import androidx.annotation.Keep

data class Traffic @Keep constructor(val upload: Long, val download: Long)