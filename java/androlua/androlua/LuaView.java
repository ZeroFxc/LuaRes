package com.androlua;

import android.content.Context;
import android.view.View;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaTable;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaView extends View {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private LuaTable f881a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaObject f882b;

    public LuaView(Context context) {
        super(context);
    }

    public LuaView(Context context, LuaTable luaTable) {
        super(context);
        this.f881a = luaTable;
    }

    @Override // android.view.View
    protected void onMeasure(int i, int i2) {
        LuaTable luaTable = this.f881a;
        if (luaTable != null) {
            try {
                this.f882b = luaTable.getField("onMeasure");
                if (this.f882b.isFunction()) {
                    this.f882b.call(Integer.valueOf(i), Integer.valueOf(i2), this);
                    return;
                }
            } catch (LuaException e) {
                e.printStackTrace();
            }
        }
        super.onMeasure(i, i2);
    }
}