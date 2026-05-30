package com.pclash.common.ids

object PendingIds {
    const val CLASH_VPN = 1

    fun generateProfileResultId(profileId: Long): Int {
        return NotificationIds.generateProfileResultId(profileId)
    }
}