package com.androlua;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.drawable.Drawable;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import com.luajava.LuaObject;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaDrawable extends Drawable {
    private final LuaContext a;
    private LuaObject b;
    private Paint c = new Paint();
    private LuaFunction d;

    public LuaDrawable(LuaFunction luaFunction) {
        this.b = luaFunction;
        this.a = this.b.getLuaState().getContext();
    }

    @Override // android.graphics.drawable.Drawable
    public void draw(Canvas canvas) {
        Object objCall;
        try {
            if (this.d == null && (objCall = this.b.call(canvas, this.c, this)) != null && (objCall instanceof LuaFunction)) {
                this.d = (LuaFunction) objCall;
            }
            if (this.d != null) {
                this.d.call(canvas);
            }
        } catch (LuaException e) {
            this.a.sendError("onDraw", e);
        }
    }

    @Override // android.graphics.drawable.Drawable
    public int getOpacity() {
        return 0;
    }

    public Paint getPaint() {
        return this.c;
    }

    @Override // android.graphics.drawable.Drawable
    public void setAlpha(int i) {
        this.c.setAlpha(i);
    }

    @Override // android.graphics.drawable.Drawable
    public void setColorFilter(ColorFilter colorFilter) {
        this.c.setColorFilter(colorFilter);
    }
}