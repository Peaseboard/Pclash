package com.pclash.common

object Permissions {
    val PERMISSION_RECEIVE_BROADCASTS: String
        get() = Global.application.packageName + ".permission.RECEIVE_BROADCASTS"
}