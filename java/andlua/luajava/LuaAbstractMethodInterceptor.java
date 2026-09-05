package com.luajava;

import com.android.cglib.proxy.MethodInterceptor;
import com.androlua.LuaContext;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaAbstractMethodInterceptor implements MethodInterceptor {
    private final LuaContext a;
    private LuaObject b;

    public LuaAbstractMethodInterceptor(LuaObject luaObject) {
        this.b = luaObject;
        this.a = luaObject.getLuaState().getContext();
    }

    /* JADX WARN: Removed duplicated region for block: B:41:0x007e  */
    /* JADX WARN: Removed duplicated region for block: B:47:0x008c A[Catch: all -> 0x00b9, TryCatch #2 {, blocks: (B:4:0x0005, B:6:0x0015, B:8:0x001e, B:10:0x002a, B:12:0x0032, B:15:0x003b, B:17:0x0041, B:20:0x004a, B:22:0x004c, B:23:0x0050, B:25:0x0052, B:26:0x0056, B:28:0x0058, B:30:0x0060, B:33:0x0069, B:35:0x006f, B:37:0x0073, B:47:0x008c, B:49:0x0094, B:52:0x009d, B:54:0x00a3, B:56:0x00ab, B:57:0x00af, B:59:0x00b1, B:60:0x00b5, B:62:0x00b7, B:45:0x0085, B:42:0x0080, B:7:0x0018), top: B:72:0x0005 }] */
    @Override // com.android.cglib.proxy.MethodInterceptor
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.lang.Object intercept(java.lang.Object r6, java.lang.Object[] r7, com.android.cglib.proxy.MethodProxy r8) {
        /*
            r5 = this;
            com.luajava.LuaObject r6 = r5.b
            com.luajava.LuaState r6 = r6.b
            monitor-enter(r6)
            java.lang.reflect.Method r8 = r8.getOriginalMethod()     // Catch: java.lang.Throwable -> Lb9
            java.lang.String r0 = r8.getName()     // Catch: java.lang.Throwable -> Lb9
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb9
            boolean r1 = r1.isFunction()     // Catch: java.lang.Throwable -> Lb9
            if (r1 == 0) goto L18
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb9
            goto L1e
        L18:
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb9
            com.luajava.LuaObject r1 = r1.getField(r0)     // Catch: java.lang.Throwable -> Lb9
        L1e:
            java.lang.Class r8 = r8.getReturnType()     // Catch: java.lang.Throwable -> Lb9
            boolean r2 = r1.isNil()     // Catch: java.lang.Throwable -> Lb9
            r3 = 0
            r4 = 0
            if (r2 == 0) goto L58
            java.lang.Class r7 = java.lang.Boolean.TYPE     // Catch: java.lang.Throwable -> Lb9
            boolean r7 = r8.equals(r7)     // Catch: java.lang.Throwable -> Lb9
            if (r7 != 0) goto L52
            java.lang.Class<java.lang.Boolean> r7 = java.lang.Boolean.class
            boolean r7 = r8.equals(r7)     // Catch: java.lang.Throwable -> Lb9
            if (r7 == 0) goto L3b
            goto L52
        L3b:
            boolean r7 = r8.isPrimitive()     // Catch: java.lang.Throwable -> Lb9
            if (r7 != 0) goto L4c
            java.lang.Class<java.lang.Number> r7 = java.lang.Number.class
            boolean r7 = r7.isAssignableFrom(r8)     // Catch: java.lang.Throwable -> Lb9
            if (r7 == 0) goto L4a
            goto L4c
        L4a:
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r3
        L4c:
            java.lang.Integer r7 = java.lang.Integer.valueOf(r4)     // Catch: java.lang.Throwable -> Lb9
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r7
        L52:
            java.lang.Boolean r7 = java.lang.Boolean.valueOf(r4)     // Catch: java.lang.Throwable -> Lb9
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r7
        L58:
            java.lang.Class<java.lang.Void> r2 = java.lang.Void.class
            boolean r2 = r8.equals(r2)     // Catch: com.luajava.LuaException -> L84 java.lang.Throwable -> Lb9
            if (r2 != 0) goto L80
            java.lang.Class r2 = java.lang.Void.TYPE     // Catch: com.luajava.LuaException -> L84 java.lang.Throwable -> Lb9
            boolean r2 = r8.equals(r2)     // Catch: com.luajava.LuaException -> L84 java.lang.Throwable -> Lb9
            if (r2 == 0) goto L69
            goto L80
        L69:
            java.lang.Object r7 = r1.call(r7)     // Catch: com.luajava.LuaException -> L84 java.lang.Throwable -> Lb9
            if (r7 == 0) goto L7e
            boolean r1 = r7 instanceof java.lang.Double     // Catch: com.luajava.LuaException -> L7b java.lang.Throwable -> Lb9
            if (r1 == 0) goto L7e
            r1 = r7
            java.lang.Double r1 = (java.lang.Double) r1     // Catch: com.luajava.LuaException -> L7b java.lang.Throwable -> Lb9
            java.lang.Number r3 = com.luajava.LuaState.convertLuaNumber(r1, r8)     // Catch: com.luajava.LuaException -> L7b java.lang.Throwable -> Lb9
            goto L8a
        L7b:
            r1 = move-exception
            r3 = r7
            goto L85
        L7e:
            r3 = r7
            goto L8a
        L80:
            r1.call(r7)     // Catch: com.luajava.LuaException -> L84 java.lang.Throwable -> Lb9
            goto L8a
        L84:
            r1 = move-exception
        L85:
            com.androlua.LuaContext r7 = r5.a     // Catch: java.lang.Throwable -> Lb9
            r7.sendError(r0, r1)     // Catch: java.lang.Throwable -> Lb9
        L8a:
            if (r3 != 0) goto Lb7
            java.lang.Class r7 = java.lang.Boolean.TYPE     // Catch: java.lang.Throwable -> Lb9
            boolean r7 = r8.equals(r7)     // Catch: java.lang.Throwable -> Lb9
            if (r7 != 0) goto Lb1
            java.lang.Class<java.lang.Boolean> r7 = java.lang.Boolean.class
            boolean r7 = r8.equals(r7)     // Catch: java.lang.Throwable -> Lb9
            if (r7 == 0) goto L9d
            goto Lb1
        L9d:
            boolean r7 = r8.isPrimitive()     // Catch: java.lang.Throwable -> Lb9
            if (r7 != 0) goto Lab
            java.lang.Class<java.lang.Number> r7 = java.lang.Number.class
            boolean r7 = r7.isAssignableFrom(r8)     // Catch: java.lang.Throwable -> Lb9
            if (r7 == 0) goto Lb7
        Lab:
            java.lang.Integer r7 = java.lang.Integer.valueOf(r4)     // Catch: java.lang.Throwable -> Lb9
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r7
        Lb1:
            java.lang.Boolean r7 = java.lang.Boolean.valueOf(r4)     // Catch: java.lang.Throwable -> Lb9
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r7
        Lb7:
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            return r3
        Lb9:
            r7 = move-exception
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb9
            throw r7
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaAbstractMethodInterceptor.intercept(java.lang.Object, java.lang.Object[], com.android.cglib.proxy.MethodProxy):java.lang.Object");
    }
}