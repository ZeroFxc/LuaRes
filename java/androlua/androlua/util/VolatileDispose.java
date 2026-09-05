package com.androlua.util;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class VolatileDispose<T> {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private volatile T f985a;

    public T blockedGet() {
        synchronized (this) {
            if (this.f985a != null) {
                return this.f985a;
            }
            try {
                wait(1000L);
                return this.f985a;
            } catch (InterruptedException e) {
                throw new RuntimeException(e);
            }
        }
    }

    public T blockedGetOrThrow(Class<? extends RuntimeException> cls) {
        synchronized (this) {
            if (this.f985a != null) {
                return this.f985a;
            }
            try {
                try {
                    wait();
                    return this.f985a;
                } catch (IllegalAccessException e) {
                    throw new RuntimeException(e);
                } catch (InstantiationException e2) {
                    throw new RuntimeException(e2);
                }
            } catch (InterruptedException unused) {
                throw cls.newInstance();
            }
        }
    }

    public void setAndNotify(T t) {
        synchronized (this) {
            this.f985a = t;
            notify();
        }
    }
}