package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaFunction<T> extends LuaObject implements LuaMetaTable {
    protected LuaFunction(LuaState luaState, int i) {
        super(luaState, i);
    }

    protected LuaFunction(LuaState luaState, String str) {
        super(luaState, str);
    }

    @Override // com.luajava.LuaMetaTable
    public T __call(Object[] objArr) {
        return (T) super.call(objArr);
    }

    @Override // com.luajava.LuaMetaTable
    public Object __index(String str) {
        return null;
    }

    @Override // com.luajava.LuaMetaTable
    public void __newIndex(String str, Object obj) {
    }

    @Override // com.luajava.LuaObject
    public T call(Object... objArr) {
        return (T) super.call(objArr);
    }
}