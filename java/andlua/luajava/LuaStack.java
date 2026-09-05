package com.luajava;

import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaStack {
    private static final HashMap<String, LuaState> a = new HashMap<>();

    public static Object call(String str, String str2, Object[] objArr) {
        return new LuaFunction(get(str), str2).call(objArr);
    }

    public static LuaState get(String str) {
        return a.get(str);
    }

    public static void put(String str, LuaState luaState) {
        a.put(str, luaState);
    }
}