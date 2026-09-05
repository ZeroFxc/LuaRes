package com.androlua;

import com.luajava.LuaTable;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaExAdapter extends LuaExpandableListAdapter {
    public LuaExAdapter(LuaContext luaContext, LuaTable luaTable, LuaTable luaTable2) {
        this(luaContext, null, null, luaTable, luaTable2);
    }

    public LuaExAdapter(LuaContext luaContext, LuaTable<Integer, LuaTable<String, Object>> luaTable, LuaTable<Integer, LuaTable<Integer, LuaTable<String, Object>>> luaTable2, LuaTable luaTable3, LuaTable luaTable4) {
        super(luaContext, luaTable, luaTable2, luaTable3, luaTable4);
    }
}