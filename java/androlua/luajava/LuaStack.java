package com.luajava;

import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaStack {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static final HashMap<String, LuaState> f1188a = new HashMap<>();

    public static Object call(String str, String str2, Object[] objArr) {
        return new LuaFunction(get(str), str2).call(objArr);
    }

    public static LuaState get(String str) {
        return f1188a.get(str);
    }

    public static void put(String str, LuaState luaState) {
        f1188a.put(str, luaState);
    }
}