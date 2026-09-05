package com.luajava;

import com.android.cglib.proxy.MethodInterceptor;
import com.android.cglib.proxy.MethodProxy;
import com.androlua.LuaContext;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaMethodInterceptor implements MethodInterceptor {
    private final LuaContext a;
    private LuaObject b;

    private class SuperCall implements LuaMetaTable {
        private final Object b;
        private final MethodProxy c;

        public SuperCall(Object obj, MethodProxy methodProxy) {
            this.b = obj;
            this.c = methodProxy;
        }

        @Override // com.luajava.LuaMetaTable
        public Object __call(Object... objArr) {
            return this.c.invokeSuper(this.b, objArr);
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

    /* JADX WARN: Removed duplicated region for block: B:42:0x008e  */
    /* JADX WARN: Removed duplicated region for block: B:48:0x009c A[Catch: all -> 0x00c9, TryCatch #2 {, blocks: (B:4:0x0005, B:6:0x0015, B:8:0x001e, B:10:0x002a, B:12:0x0032, B:15:0x003b, B:17:0x0041, B:20:0x004a, B:22:0x004c, B:23:0x0050, B:25:0x0052, B:26:0x0056, B:28:0x0058, B:29:0x0068, B:31:0x0070, B:34:0x0079, B:36:0x007f, B:38:0x0083, B:48:0x009c, B:50:0x00a4, B:53:0x00ad, B:55:0x00b3, B:57:0x00bb, B:58:0x00bf, B:60:0x00c1, B:61:0x00c5, B:63:0x00c7, B:46:0x0095, B:43:0x0090, B:7:0x0018), top: B:73:0x0005 }] */
    @Override // com.android.cglib.proxy.MethodInterceptor
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.lang.Object intercept(java.lang.Object r10, java.lang.Object[] r11, com.android.cglib.proxy.MethodProxy r12) {
        /*
            Method dump skipped, instruction units count: 204
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaMethodInterceptor.intercept(java.lang.Object, java.lang.Object[], com.android.cglib.proxy.MethodProxy):java.lang.Object");
    }
}