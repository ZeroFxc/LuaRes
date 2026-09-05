package com.luajava;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaException extends Exception {
    public LuaException(Exception exc) {
        super(exc.getCause() != null ? exc.getCause() : exc);
    }

    public LuaException(String str) {
        super(str);
    }
}