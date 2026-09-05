package com.androlua;

import dalvik.system.DexClassLoader;
import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaDexClassLoader extends DexClassLoader {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private HashMap<String, Class<?>> f772a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private String f773b;

    public LuaDexClassLoader(String str, String str2, String str3, ClassLoader classLoader) {
        super(str, str2, str3, classLoader);
        this.f772a = new HashMap<>();
        this.f773b = str;
    }

    @Override // dalvik.system.BaseDexClassLoader, java.lang.ClassLoader
    protected Class<?> findClass(String str) {
        Class<?> cls = this.f772a.get(str);
        if (cls != null) {
            return cls;
        }
        Class<?> clsFindClass = super.findClass(str);
        this.f772a.put(str, clsFindClass);
        return clsFindClass;
    }

    public String getDexPath() {
        return this.f773b;
    }
}