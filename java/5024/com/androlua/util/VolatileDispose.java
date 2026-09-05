package com.androlua.util;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class VolatileDispose<T> {
    private volatile T a;

    public T blockedGet() {
        synchronized (this) {
            if (this.a != null) {
                return this.a;
            }
            try {
                wait(1000L);
                return this.a;
            } catch (InterruptedException e) {
                throw new RuntimeException(e);
            }
        }
    }

    public T blockedGetOrThrow(Class<? extends RuntimeException> cls) {
        synchronized (this) {
            if (this.a != null) {
                return this.a;
            }
            try {
                try {
                    wait();
                    return this.a;
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
            this.a = t;
            notify();
        }
    }
}