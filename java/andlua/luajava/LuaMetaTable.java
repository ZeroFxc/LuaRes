package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public interface LuaMetaTable {
    Object __call(Object... objArr);

    Object __index(String str);

    void __newIndex(String str, Object obj);
}