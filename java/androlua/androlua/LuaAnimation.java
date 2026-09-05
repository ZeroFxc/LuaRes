package com.androlua;

import android.view.animation.Animation;
import android.view.animation.Transformation;
import com.luajava.LuaException;
import com.luajava.LuaFunction;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaAnimation extends Animation {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaContext f738a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaFunction f739b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private LuaFunction f740c;

    public LuaAnimation(LuaFunction luaFunction) {
        this.f739b = luaFunction;
        this.f738a = this.f739b.getLuaState().getContext();
    }

    @Override // android.view.animation.Animation
    protected void applyTransformation(float f, Transformation transformation) {
        Object objCall;
        super.applyTransformation(f, transformation);
        try {
            this.f739b.call(Float.valueOf(f), transformation);
            if (this.f740c == null && (objCall = this.f739b.call(Float.valueOf(f), transformation, this)) != null && (objCall instanceof LuaFunction)) {
                this.f740c = (LuaFunction) objCall;
            }
            if (this.f740c != null) {
                this.f740c.call(Float.valueOf(f), transformation);
            }
        } catch (LuaException e) {
            this.f738a.sendError("applyTransformation", e);
        }
    }

    @Override // android.view.animation.Animation
    protected float resolveSize(int i, float f, int i2, int i3) {
        return super.resolveSize(i, f, i2, i3);
    }
}