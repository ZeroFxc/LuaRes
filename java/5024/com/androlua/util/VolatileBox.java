package com.androlua.util;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class VolatileBox<T> {
    private volatile T a;

    public VolatileBox() {
    }

    public VolatileBox(T t) {
        set(t);
    }

    public T blockedGet() {
        synchronized (this) {
            try {
                wait();
            } catch (InterruptedException e) {
                throw new RuntimeException(e);
            }
        }
        return this.a;
    }

    public T blockedGetOrThrow(Class<? extends RuntimeException> cls) {
        synchronized (this) {
            try {
                try {
                    wait();
                } catch (IllegalAccessException e) {
                    throw new RuntimeException(e);
                } catch (InstantiationException e2) {
                    throw new RuntimeException(e2);
                }
            } catch (InterruptedException unused) {
                throw cls.newInstance();
            }
        }
        return this.a;
    }

    public T get() {
        return this.a;
    }

    public boolean isNull() {
        return this.a == null;
    }

    public boolean notNull() {
        return this.a != null;
    }

    public void set(T t) {
        this.a = t;
    }

    public void setAndNotify(T t) {
        this.a = t;
        synchronized (this) {
            notify();
        }
    }
}