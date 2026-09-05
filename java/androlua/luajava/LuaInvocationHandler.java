package com.luajava;

import android.util.Log;
import com.androlua.LuaContext;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaInvocationHandler implements InvocationHandler {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static ArrayList f1173a = new ArrayList();

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private final LuaContext f1174b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private final LuaObject f1175c;

    public LuaInvocationHandler(LuaObject luaObject) {
        this.f1175c = luaObject;
        f1173a.add(luaObject);
        this.f1174b = luaObject.getLuaState().getContext();
    }

    @Override // java.lang.reflect.InvocationHandler
    public Object invoke(Object obj, Method method, Object[] objArr) {
        Log.i("LuaInvocationHandler", "invoke: " + this.f1175c + ";" + method + ";" + Arrays.toString(objArr));
        synchronized (this.f1175c.f1187b) {
            String name = method.getName();
            LuaObject field = this.f1175c.isFunction() ? this.f1175c : this.f1175c.getField(name);
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
                    }
                }
            } catch (Exception e) {
                this.f1174b.sendError(name, e);
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