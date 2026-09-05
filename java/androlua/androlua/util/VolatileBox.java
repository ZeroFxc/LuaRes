package com.androlua.util;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class VolatileBox<T> {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private volatile T f984a;

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
        return this.f984a;
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
        return this.f984a;
    }

    public T get() {
        return this.f984a;
    }

    public boolean isNull() {
        return this.f984a == null;
    }

    public boolean notNull() {
        return this.f984a != null;
    }

    public void set(T t) {
        this.f984a = t;
    }

    public void setAndNotify(T t) {
        this.f984a = t;
        synchronized (this) {
            notify();
        }
    }
}