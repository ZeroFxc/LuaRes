package com.androlua;

import android.content.Context;
import android.view.View;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaTable;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaView extends View {
    private LuaTable a;
    private LuaObject b;

    public LuaView(Context context) {
        super(context);
    }

    public LuaView(Context context, LuaTable luaTable) {
        super(context);
        this.a = luaTable;
    }

    @Override // android.view.View
    protected void onMeasure(int i, int i2) {
        LuaTable luaTable = this.a;
        if (luaTable != null) {
            try {
                this.b = luaTable.getField("onMeasure");
                if (this.b.isFunction()) {
                    this.b.call(Integer.valueOf(i), Integer.valueOf(i2), this);
                    return;
                }
            } catch (LuaException e) {
                e.printStackTrace();
            }
        }
        super.onMeasure(i, i2);
    }
}