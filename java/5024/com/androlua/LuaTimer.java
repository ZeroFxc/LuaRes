package com.androlua;

import com.androlua.util.TimerX;
import com.luajava.LuaObject;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaTimer extends TimerX implements LuaGcable {
    private boolean d;
    private LuaTimerTask e;

    public LuaTimer(LuaContext luaContext, LuaObject luaObject) {
        this(luaContext, luaObject, (Object[]) null);
    }

    public LuaTimer(LuaContext luaContext, LuaObject luaObject, Object[] objArr) {
        super("LuaTimer");
        luaContext.regGc(this);
        this.e = new LuaTimerTask(luaContext, luaObject, objArr);
    }

    public LuaTimer(LuaContext luaContext, String str) {
        this(luaContext, str, (Object[]) null);
    }

    public LuaTimer(LuaContext luaContext, String str, Object[] objArr) {
        super("LuaTimer");
        luaContext.regGc(this);
        this.e = new LuaTimerTask(luaContext, str, objArr);
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        stop();
        this.d = true;
    }

    public boolean getEnabled() {
        return this.e.isEnabled();
    }

    public long getPeriod() {
        return this.e.getPeriod();
    }

    public boolean isEnabled() {
        return this.e.isEnabled();
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.d;
    }

    public void setEnabled(boolean z) {
        this.e.setEnabled(z);
    }

    public void setPeriod(long j) {
        this.e.setPeriod(j);
    }

    public void start(long j) {
        schedule(this.e, j);
    }

    public void start(long j, long j2) {
        schedule(this.e, j, j2);
    }

    public void stop() {
        this.e.cancel();
    }
}