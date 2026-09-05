package com.luajava;

import java.util.HashMap;
import java.util.Map;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public final class LuaStateFactory {
    private static final Map<Long, LuaState> a = new HashMap();

    private LuaStateFactory() {
    }

    public static synchronized LuaState getExistingState(long j) {
        LuaState luaState;
        luaState = a.get(Long.valueOf(j));
        if (luaState == null) {
            luaState = new LuaState(j);
            a.put(Long.valueOf(j), luaState);
        }
        return luaState;
    }

    public static synchronized long insertLuaState(LuaState luaState) {
        a.put(Long.valueOf(luaState.getPointer()), luaState);
        return luaState.getPointer();
    }

    public static synchronized LuaState newLuaState() {
        LuaState luaState;
        luaState = new LuaState();
        a.put(Long.valueOf(luaState.getPointer()), luaState);
        return luaState;
    }

    public static synchronized void removeLuaState(long j) {
        a.put(Long.valueOf(j), null);
    }
}