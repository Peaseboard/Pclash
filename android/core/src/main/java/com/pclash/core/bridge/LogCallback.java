package com.pclash.core.bridge;

import androidx.annotation.Keep;

import com.pclash.core.event.LogEvent;

@Keep
@SuppressWarnings("unused")
public interface LogCallback {
    void onMessage(LogEvent event);
}
