package com.luajava;

import com.android.cglib.proxy.MethodInterceptor;
import com.android.cglib.proxy.MethodProxy;
import com.androlua.LuaContext;
import java.lang.reflect.Method;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaMethodInterceptor implements MethodInterceptor {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaContext f1181a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaObject f1182b;

    private class SuperCall implements LuaMetaTable {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private final Object f1183a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private final MethodProxy f1184b;

        public SuperCall(Object obj, MethodProxy methodProxy) {
            this.f1183a = obj;
            this.f1184b = methodProxy;
        }

        @Override // com.luajava.LuaMetaTable
        public Object __call(Object... objArr) {
            return this.f1184b.invokeSuper(this.f1183a, objArr);
        }

        @Override // com.luajava.LuaMetaTable
        public Object __index(String str) {
            return null;
        }

        @Override // com.luajava.LuaMetaTable
        public void __newIndex(String str, Object obj) {
        }
    }

    public LuaMethodInterceptor(LuaObject luaObject) {
        this.f1182b = luaObject;
        this.f1181a = luaObject.getLuaState().getContext();
    }

    @Override // com.android.cglib.proxy.MethodInterceptor
    public Object intercept(Object obj, Object[] objArr, MethodProxy methodProxy) {
        synchronized (this.f1182b.f1187b) {
            Method originalMethod = methodProxy.getOriginalMethod();
            String name = originalMethod.getName();
            LuaObject field = this.f1182b.isFunction() ? this.f1182b : this.f1182b.getField(name);
            Class<?> returnType = originalMethod.getReturnType();
            Object objCall = null;
            if (field.isNil()) {
                if (!returnType.equals(Boolean.TYPE) && !returnType.equals(Boolean.class)) {
                    if (!returnType.isPrimitive() && !Number.class.isAssignableFrom(returnType)) {
                        return null;
                    }
                    return 0;
                }
                return false;
            }
            Object[] objArr2 = new Object[objArr.length + 1];
            System.arraycopy(objArr, 0, objArr2, 1, objArr.length);
            objArr2[0] = new SuperCall(obj, methodProxy);
            try {
                if (returnType.equals(Void.class) || returnType.equals(Void.TYPE)) {
                    field.call(objArr2);
                } else {
                    objCall = field.call(objArr2);
                    if (objCall != null && (objCall instanceof Double)) {
                        objCall = LuaState.convertLuaNumber((Double) objCall, returnType);
                    }
                }
            } catch (LuaException e) {
                this.f1181a.sendError(name, e);
            }
            if (objCall == null) {
                if (!returnType.equals(Boolean.TYPE) && !returnType.equals(Boolean.class)) {
                    if (returnType.isPrimitive() || Number.class.isAssignableFrom(returnType)) {
                        return 0;
                    }
                }
                return false;
            }
            return objCall;
        }
    }
}