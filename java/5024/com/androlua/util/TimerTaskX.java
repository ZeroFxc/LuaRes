package com.androlua.util;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public abstract class TimerTaskX implements Runnable {
    final Object a = new Object();
    boolean b;
    long c;
    long d;
    boolean e;
    private long f;
    private boolean g;

    protected TimerTaskX() {
    }

    boolean a() {
        boolean z;
        synchronized (this.a) {
            z = this.c > 0 || this.f > 0;
        }
        return z;
    }

    public boolean cancel() {
        boolean z;
        synchronized (this.a) {
            z = !this.b && this.c > 0;
            this.b = true;
        }
        return z;
    }

    public long getPeriod() {
        return this.d;
    }

    public boolean isEnabled() {
        return this.g;
    }

    @Override // java.lang.Runnable
    public abstract void run();

    public long scheduledExecutionTime() {
        long j;
        synchronized (this.a) {
            j = this.f;
        }
        return j;
    }

    public void setEnabled(boolean z) {
        this.g = z;
    }

    public void setPeriod(long j) {
        this.d = j;
    }

    public void setScheduledTime(long j) {
        synchronized (this.a) {
            this.f = j;
        }
    }
}