package com.luajava;

import android.util.Log;
import com.androlua.LuaContext;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaInvocationHandler implements InvocationHandler {
    private static ArrayList a = new ArrayList();
    private final LuaContext b;
    private final LuaObject c;

    public LuaInvocationHandler(LuaObject luaObject) {
        this.c = luaObject;
        a.add(luaObject);
        this.b = luaObject.getLuaState().getContext();
    }

    @Override // java.lang.reflect.InvocationHandler
    public Object invoke(Object obj, Method method, Object[] objArr) {
        Log.i("LuaInvocationHandler", "invoke: " + this.c + ";" + method + ";" + Arrays.toString(objArr));
        synchronized (this.c.b) {
            String name = method.getName();
            LuaObject field = this.c.isFunction() ? this.c : this.c.getField(name);
            Class<?> returnType = method.getReturnType();
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
                    } else if (objCall != null && (objCall instanceof Long)) {
                        objCall = LuaState.convertLuaNumber((Long) objCall, returnType);
                    }
                }
            } catch (Exception e) {
                this.b.sendError(name, e);
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