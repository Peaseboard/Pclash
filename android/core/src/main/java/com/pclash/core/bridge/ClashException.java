package com.pclash.core.bridge;

import androidx.annotation.Keep;

public class ClashException extends Exception {
    @Keep
    public ClashException(String msg) {
        super(msg);
    }
}
