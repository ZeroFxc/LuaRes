package com.luajava;

import android.util.Log;
import com.androlua.LuaContext;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\andlua.dex */
public class LuaInvocationHandler implements InvocationHandler {
    private static ArrayList c = new ArrayList();
    private final LuaContext a;
    private final LuaObject b;

    public LuaInvocationHandler(LuaObject luaObject) {
        this.b = luaObject;
        c.add(luaObject);
        this.a = luaObject.getLuaState().getContext();
    }

    @Override // java.lang.reflect.InvocationHandler
    public Object invoke(Object obj, Method method, Object[] objArr) {
        Log.i("LuaInvocationHandler", "invoke: " + this.b + ";" + method + ";" + Arrays.toString(objArr));
        synchronized (this.b.b) {
            String name = method.getName();
            LuaObject field = this.b.isFunction() ? this.b : this.b.getField(name);
            Class<?> returnType = method.getReturnType();
            Object objCall = null;
            if (field.isNil()) {
                if (!returnType.equals(Boolean.TYPE) && !returnType.equals(Boolean.class)) {
                    if (!returnType.isPrimitive() && !Number.class.isAssignableFrom(returnType)) {
                        return null;
                    }
                    return 0;
                }
                return Boolean.FALSE;
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
            } catch (Exception e) {
                this.a.sendError(name, e);
            }
            if (objCall == null) {
                if (!returnType.equals(Boolean.TYPE) && !returnType.equals(Boolean.class)) {
                    if (returnType.isPrimitive() || Number.class.isAssignableFrom(returnType)) {
                        return 0;
                    }
                }
                return Boolean.FALSE;
            }
            return objCall;
        }
    }
}