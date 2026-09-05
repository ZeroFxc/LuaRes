package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\andlua.dex */
public abstract class JavaFunction {
    protected LuaState a;

    public JavaFunction(LuaState luaState) {
        this.a = luaState;
    }

    public abstract int execute();

    public LuaObject getParam(int i) {
        return this.a.getLuaObject(i);
    }

    public void register(String str) {
        synchronized (this.a) {
            this.a.pushJavaFunction(this);
            this.a.setGlobal(str);
        }
    }
}