package com.androlua;

import com.android.cglib.proxy.Enhancer;
import com.android.cglib.proxy.EnhancerInterface;
import com.android.cglib.proxy.MethodFilter;
import com.android.cglib.proxy.MethodInterceptor;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaEnhancer {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private Enhancer f793a;

    public LuaEnhancer(Class<?> cls) {
        this.f793a = new Enhancer(LuaApplication.getInstance());
        this.f793a.setSuperclass(cls);
    }

    public LuaEnhancer(String str) {
        this(Class.forName(str));
    }

    public Class<?> create() {
        try {
            return this.f793a.create();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public Class<?> create(MethodFilter methodFilter) {
        try {
            this.f793a.setMethodFilter(methodFilter);
            return this.f793a.create();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public void setInterceptor(EnhancerInterface enhancerInterface, MethodInterceptor methodInterceptor) {
        enhancerInterface.setMethodInterceptor_Enhancer(methodInterceptor);
    }
}