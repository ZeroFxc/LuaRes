package com.androlua;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.drawable.Drawable;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import com.luajava.LuaObject;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaDrawable extends Drawable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaContext f780a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaObject f781b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private Paint f782c = new Paint();
    private LuaFunction d;

    public LuaDrawable(LuaFunction luaFunction) {
        this.f781b = luaFunction;
        this.f780a = this.f781b.getLuaState().getContext();
    }

    @Override // android.graphics.drawable.Drawable
    public void draw(Canvas canvas) {
        Object objCall;
        try {
            if (this.d == null && (objCall = this.f781b.call(canvas, this.f782c, this)) != null && (objCall instanceof LuaFunction)) {
                this.d = (LuaFunction) objCall;
            }
            if (this.d != null) {
                this.d.call(canvas);
            }
        } catch (LuaException e) {
            this.f780a.sendError("onDraw", e);
        }
    }

    @Override // android.graphics.drawable.Drawable
    public int getOpacity() {
        return 0;
    }

    public Paint getPaint() {
        return this.f782c;
    }

    @Override // android.graphics.drawable.Drawable
    public void setAlpha(int i) {
        this.f782c.setAlpha(i);
    }

    @Override // android.graphics.drawable.Drawable
    public void setColorFilter(ColorFilter colorFilter) {
        this.f782c.setColorFilter(colorFilter);
    }
}