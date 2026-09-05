package com.androlua;

import android.view.animation.Animation;
import android.view.animation.Transformation;
import com.luajava.LuaException;
import com.luajava.LuaFunction;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaAnimation extends Animation {
    private final LuaContext a;
    private LuaFunction b;
    private LuaFunction c;

    public LuaAnimation(LuaFunction luaFunction) {
        this.b = luaFunction;
        this.a = this.b.getLuaState().getContext();
    }

    @Override // android.view.animation.Animation
    protected void applyTransformation(float f, Transformation transformation) {
        Object objCall;
        super.applyTransformation(f, transformation);
        try {
            this.b.call(Float.valueOf(f), transformation);
            if (this.c == null && (objCall = this.b.call(Float.valueOf(f), transformation, this)) != null && (objCall instanceof LuaFunction)) {
                this.c = (LuaFunction) objCall;
            }
            if (this.c != null) {
                this.c.call(Float.valueOf(f), transformation);
            }
        } catch (LuaException e) {
            this.a.sendError("applyTransformation", e);
        }
    }

    @Override // android.view.animation.Animation
    protected float resolveSize(int i, float f, int i2, int i3) {
        return super.resolveSize(i, f, i2, i3);
    }
}