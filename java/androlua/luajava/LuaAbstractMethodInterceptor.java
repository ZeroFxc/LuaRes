package com.luajava;

import com.android.cglib.proxy.MethodInterceptor;
import com.android.cglib.proxy.MethodProxy;
import com.androlua.LuaContext;
import java.lang.reflect.Method;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaAbstractMethodInterceptor implements MethodInterceptor {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaContext f1171a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaObject f1172b;

    public LuaAbstractMethodInterceptor(LuaObject luaObject) {
        this.f1172b = luaObject;
        this.f1171a = luaObject.getLuaState().getContext();
    }

    @Override // com.android.cglib.proxy.MethodInterceptor
    public Object intercept(Object obj, Object[] objArr, MethodProxy methodProxy) {
        synchronized (this.f1172b.f1187b) {
            Method originalMethod = methodProxy.getOriginalMethod();
            String name = originalMethod.getName();
            LuaObject field = this.f1172b.isFunction() ? this.f1172b : this.f1172b.getField(name);
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
            try {
                if (returnType.equals(Void.class) || returnType.equals(Void.TYPE)) {
                    field.call(objArr);
                } else {
                    objCall = field.call(objArr);
                    if (objCall != null && (objCall instanceof Double)) {
                        objCall = LuaState.convertLuaNumber((Double) objCall, returnType);
                    }
                }
            } catch (LuaException e) {
                this.f1171a.sendError(name, e);
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