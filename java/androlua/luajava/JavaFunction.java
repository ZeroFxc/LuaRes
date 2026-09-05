package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public abstract class JavaFunction {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    protected LuaState f1170a;

    public JavaFunction(LuaState luaState) {
        this.f1170a = luaState;
    }

    public abstract int execute();

    public LuaObject getParam(int i) {
        return this.f1170a.getLuaObject(i);
    }

    public void register(String str) {
        synchronized (this.f1170a) {
            this.f1170a.pushJavaFunction(this);
            this.f1170a.setGlobal(str);
        }
    }
}