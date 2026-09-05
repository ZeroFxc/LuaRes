package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\andlua.dex */
public class LuaException extends Exception {
    public LuaException(Exception exc) {
        super(exc.getCause() != null ? exc.getCause() : exc);
    }

    public LuaException(String str) {
        super(str);
    }
}