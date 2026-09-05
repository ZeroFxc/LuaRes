package com.luajava;

import java.util.HashMap;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public final class LuaStateFactory {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static final Map<Long, LuaState> f1192a = new HashMap();

    private LuaStateFactory() {
    }

    public static synchronized LuaState getExistingState(long j) {
        LuaState luaState;
        luaState = f1192a.get(Long.valueOf(j));
        if (luaState == null) {
            luaState = new LuaState(j);
            f1192a.put(Long.valueOf(j), luaState);
        }
        return luaState;
    }

    public static synchronized long insertLuaState(LuaState luaState) {
        f1192a.put(Long.valueOf(luaState.getPointer()), luaState);
        return luaState.getPointer();
    }

    public static synchronized LuaState newLuaState() {
        LuaState luaState;
        luaState = new LuaState();
        f1192a.put(Long.valueOf(luaState.getPointer()), luaState);
        return luaState;
    }

    public static synchronized void removeLuaState(long j) {
        f1192a.put(Long.valueOf(j), null);
    }
}