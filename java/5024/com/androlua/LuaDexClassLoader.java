package com.androlua;

import dalvik.system.DexClassLoader;
import java.util.HashMap;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaDexClassLoader extends DexClassLoader {
    private HashMap<String, Class<?>> a;
    private String b;

    public LuaDexClassLoader(String str, String str2, String str3, ClassLoader classLoader) {
        super(str, str2, str3, classLoader);
        this.a = new HashMap<>();
        this.b = str;
    }

    @Override // dalvik.system.BaseDexClassLoader, java.lang.ClassLoader
    protected Class<?> findClass(String str) {
        Class<?> cls = this.a.get(str);
        if (cls != null) {
            return cls;
        }
        Class<?> clsFindClass = super.findClass(str);
        this.a.put(str, clsFindClass);
        return clsFindClass;
    }

    public String getDexPath() {
        return this.b;
    }
}