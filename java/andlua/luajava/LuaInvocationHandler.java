package com.luajava;

import com.androlua.LuaContext;
import java.lang.reflect.InvocationHandler;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaInvocationHandler implements InvocationHandler {
    private final LuaContext a;
    private LuaObject b;

    public LuaInvocationHandler(LuaObject luaObject) {
        this.b = luaObject;
        this.a = luaObject.getLuaState().getContext();
    }

    /* JADX WARN: Removed duplicated region for block: B:41:0x007a  */
    /* JADX WARN: Removed duplicated region for block: B:47:0x0088 A[Catch: all -> 0x00b5, TryCatch #0 {, blocks: (B:4:0x0005, B:6:0x0011, B:8:0x001a, B:10:0x0026, B:12:0x002e, B:15:0x0037, B:17:0x003d, B:20:0x0046, B:22:0x0048, B:23:0x004c, B:25:0x004e, B:26:0x0052, B:28:0x0054, B:30:0x005c, B:33:0x0065, B:35:0x006b, B:37:0x006f, B:47:0x0088, B:49:0x0090, B:52:0x0099, B:54:0x009f, B:56:0x00a7, B:57:0x00ab, B:59:0x00ad, B:60:0x00b1, B:62:0x00b3, B:45:0x0081, B:42:0x007c, B:7:0x0014), top: B:67:0x0005 }] */
    @Override // java.lang.reflect.InvocationHandler
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.lang.Object invoke(java.lang.Object r6, java.lang.reflect.Method r7, java.lang.Object[] r8) {
        /*
            r5 = this;
            com.luajava.LuaObject r6 = r5.b
            com.luajava.LuaState r6 = r6.b
            monitor-enter(r6)
            java.lang.String r0 = r7.getName()     // Catch: java.lang.Throwable -> Lb5
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb5
            boolean r1 = r1.isFunction()     // Catch: java.lang.Throwable -> Lb5
            if (r1 == 0) goto L14
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb5
            goto L1a
        L14:
            com.luajava.LuaObject r1 = r5.b     // Catch: java.lang.Throwable -> Lb5
            com.luajava.LuaObject r1 = r1.getField(r0)     // Catch: java.lang.Throwable -> Lb5
        L1a:
            java.lang.Class r7 = r7.getReturnType()     // Catch: java.lang.Throwable -> Lb5
            boolean r2 = r1.isNil()     // Catch: java.lang.Throwable -> Lb5
            r3 = 0
            r4 = 0
            if (r2 == 0) goto L54
            java.lang.Class r8 = java.lang.Boolean.TYPE     // Catch: java.lang.Throwable -> Lb5
            boolean r8 = r7.equals(r8)     // Catch: java.lang.Throwable -> Lb5
            if (r8 != 0) goto L4e
            java.lang.Class<java.lang.Boolean> r8 = java.lang.Boolean.class
            boolean r8 = r7.equals(r8)     // Catch: java.lang.Throwable -> Lb5
            if (r8 == 0) goto L37
            goto L4e
        L37:
            boolean r8 = r7.isPrimitive()     // Catch: java.lang.Throwable -> Lb5
            if (r8 != 0) goto L48
            java.lang.Class<java.lang.Number> r8 = java.lang.Number.class
            boolean r7 = r8.isAssignableFrom(r7)     // Catch: java.lang.Throwable -> Lb5
            if (r7 == 0) goto L46
            goto L48
        L46:
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r3
        L48:
            java.lang.Integer r7 = java.lang.Integer.valueOf(r4)     // Catch: java.lang.Throwable -> Lb5
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r7
        L4e:
            java.lang.Boolean r7 = java.lang.Boolean.valueOf(r4)     // Catch: java.lang.Throwable -> Lb5
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r7
        L54:
            java.lang.Class<java.lang.Void> r2 = java.lang.Void.class
            boolean r2 = r7.equals(r2)     // Catch: com.luajava.LuaException -> L80 java.lang.Throwable -> Lb5
            if (r2 != 0) goto L7c
            java.lang.Class r2 = java.lang.Void.TYPE     // Catch: com.luajava.LuaException -> L80 java.lang.Throwable -> Lb5
            boolean r2 = r7.equals(r2)     // Catch: com.luajava.LuaException -> L80 java.lang.Throwable -> Lb5
            if (r2 == 0) goto L65
            goto L7c
        L65:
            java.lang.Object r8 = r1.call(r8)     // Catch: com.luajava.LuaException -> L80 java.lang.Throwable -> Lb5
            if (r8 == 0) goto L7a
            boolean r1 = r8 instanceof java.lang.Double     // Catch: com.luajava.LuaException -> L77 java.lang.Throwable -> Lb5
            if (r1 == 0) goto L7a
            r1 = r8
            java.lang.Double r1 = (java.lang.Double) r1     // Catch: com.luajava.LuaException -> L77 java.lang.Throwable -> Lb5
            java.lang.Number r3 = com.luajava.LuaState.convertLuaNumber(r1, r7)     // Catch: com.luajava.LuaException -> L77 java.lang.Throwable -> Lb5
            goto L86
        L77:
            r1 = move-exception
            r3 = r8
            goto L81
        L7a:
            r3 = r8
            goto L86
        L7c:
            r1.call(r8)     // Catch: com.luajava.LuaException -> L80 java.lang.Throwable -> Lb5
            goto L86
        L80:
            r1 = move-exception
        L81:
            com.androlua.LuaContext r8 = r5.a     // Catch: java.lang.Throwable -> Lb5
            r8.sendError(r0, r1)     // Catch: java.lang.Throwable -> Lb5
        L86:
            if (r3 != 0) goto Lb3
            java.lang.Class r8 = java.lang.Boolean.TYPE     // Catch: java.lang.Throwable -> Lb5
            boolean r8 = r7.equals(r8)     // Catch: java.lang.Throwable -> Lb5
            if (r8 != 0) goto Lad
            java.lang.Class<java.lang.Boolean> r8 = java.lang.Boolean.class
            boolean r8 = r7.equals(r8)     // Catch: java.lang.Throwable -> Lb5
            if (r8 == 0) goto L99
            goto Lad
        L99:
            boolean r8 = r7.isPrimitive()     // Catch: java.lang.Throwable -> Lb5
            if (r8 != 0) goto La7
            java.lang.Class<java.lang.Number> r8 = java.lang.Number.class
            boolean r7 = r8.isAssignableFrom(r7)     // Catch: java.lang.Throwable -> Lb5
            if (r7 == 0) goto Lb3
        La7:
            java.lang.Integer r7 = java.lang.Integer.valueOf(r4)     // Catch: java.lang.Throwable -> Lb5
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r7
        Lad:
            java.lang.Boolean r7 = java.lang.Boolean.valueOf(r4)     // Catch: java.lang.Throwable -> Lb5
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r7
        Lb3:
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            return r3
        Lb5:
            r7 = move-exception
            monitor-exit(r6)     // Catch: java.lang.Throwable -> Lb5
            throw r7
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaInvocationHandler.invoke(java.lang.Object, java.lang.reflect.Method, java.lang.Object[]):java.lang.Object");
    }
}