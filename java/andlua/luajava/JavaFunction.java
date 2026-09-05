package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public abstract class JavaFunction {
    protected LuaState b;

    public JavaFunction(LuaState luaState) {
        this.b = luaState;
    }

    public abstract int execute();

    public LuaObject getParam(int i) {
        return this.b.getLuaObject(i);
    }

    public void register(String str) {
        synchronized (this.b) {
            this.b.pushJavaFunction(this);
            this.b.setGlobal(str);
        }
    }
}