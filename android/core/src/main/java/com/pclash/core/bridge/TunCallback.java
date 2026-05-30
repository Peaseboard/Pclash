package com.pclash.core.bridge;

import androidx.annotation.Keep;

@Keep
@SuppressWarnings("unused")
public interface TunCallback {
    void onNewSocket(int socket);
    void onStop();
}
