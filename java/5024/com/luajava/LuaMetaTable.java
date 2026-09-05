package com.luajava;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public interface LuaMetaTable {
    Object __call(Object... objArr);

    Object __index(String str);

    void __newIndex(String str, Object obj);
}