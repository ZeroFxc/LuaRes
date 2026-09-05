package com.androlua.util;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public abstract class TimerTaskX implements Runnable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    final Object f971a = new Object();

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    boolean f972b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    long f973c;
    long d;
    boolean e;
    private long f;
    private boolean g;

    protected TimerTaskX() {
    }

    boolean a() {
        boolean z;
        synchronized (this.f971a) {
            z = this.f973c > 0 || this.f > 0;
        }
        return z;
    }

    public boolean cancel() {
        boolean z;
        synchronized (this.f971a) {
            z = !this.f972b && this.f973c > 0;
            this.f972b = true;
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
        synchronized (this.f971a) {
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
        synchronized (this.f971a) {
            this.f = j;
        }
    }
}