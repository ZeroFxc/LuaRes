package com.luajava;

import com.android.cglib.proxy.MethodInterceptor;
import com.android.cglib.proxy.MethodProxy;
import com.androlua.LuaContext;
import java.lang.reflect.Method;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaMethodInterceptor implements MethodInterceptor {
    private final LuaContext a;
    private LuaObject b;

    private class SuperCall implements LuaMetaTable {
        private final Object a;
        private final MethodProxy b;

        public SuperCall(Object obj, MethodProxy methodProxy) {
            this.a = obj;
            this.b = methodProxy;
        }

        @Override // com.luajava.LuaMetaTable
        public Object __call(Object... objArr) {
            return this.b.invokeSuper(this.a, objArr);
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
        this.b = luaObject;
        this.a = luaObject.getLuaState().getContext();
    }

    public Object intercept(Object obj, Object[] objArr, MethodProxy methodProxy) {
        synchronized (this.b.b) {
            Method originalMethod = methodProxy.getOriginalMethod();
            String name = originalMethod.getName();
            LuaObject field = this.b.isFunction() ? this.b : this.b.getField(name);
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
                this.a.sendError(name, e);
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