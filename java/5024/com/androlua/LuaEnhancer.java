package com.androlua;

import com.android.cglib.proxy.Enhancer;
import com.android.cglib.proxy.EnhancerInterface;
import com.android.cglib.proxy.MethodFilter;
import com.android.cglib.proxy.MethodInterceptor;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaEnhancer {
    private Enhancer a;

    public LuaEnhancer(Class<?> cls) {
        this.a = new Enhancer(LuaApplication.getInstance());
        this.a.setSuperclass(cls);
    }

    public LuaEnhancer(String str) {
        this(Class.forName(str));
    }

    public Class<?> create() {
        try {
            return this.a.create();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public Class<?> create(MethodFilter methodFilter) {
        try {
            this.a.setMethodFilter(methodFilter);
            return this.a.create();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public void setInterceptor(EnhancerInterface enhancerInterface, MethodInterceptor methodInterceptor) {
        enhancerInterface.setMethodInterceptor_Enhancer(methodInterceptor);
    }
}