package com.androlua;

import android.os.Handler;
import android.os.Message;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Ticker {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private Handler f925a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private OnTickListener f926b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private Thread f927c;
    private long d = 1000;
    private boolean e = true;
    private boolean f = false;
    private long g;
    private long h;

    public interface OnTickListener {
        void onTick();
    }

    public Ticker() {
        a();
    }

    private void a() {
        this.f925a = new Handler() { // from class: com.androlua.Ticker.1
            @Override // android.os.Handler
            public void handleMessage(Message message) {
                if (Ticker.this.f926b != null) {
                    Ticker.this.f926b.onTick();
                }
            }
        };
        this.f927c = new Thread() { // from class: com.androlua.Ticker.2
            @Override // java.lang.Thread, java.lang.Runnable
            public void run() {
                Ticker.this.f = true;
                while (Ticker.this.f) {
                    long jCurrentTimeMillis = System.currentTimeMillis();
                    if (!Ticker.this.e) {
                        Ticker ticker = Ticker.this;
                        ticker.g = jCurrentTimeMillis - ticker.h;
                    }
                    if (jCurrentTimeMillis - Ticker.this.g >= Ticker.this.d) {
                        Ticker.this.g = jCurrentTimeMillis;
                        Ticker.this.f925a.sendEmptyMessage(0);
                    }
                    try {
                        Thread.sleep(1L);
                    } catch (InterruptedException unused) {
                    }
                }
            }
        };
    }

    public boolean getEnabled() {
        return this.e;
    }

    public long getInterval() {
        return this.d;
    }

    public long getPeriod() {
        return this.d;
    }

    public boolean isRun() {
        return this.f;
    }

    public void setEnabled(boolean z) {
        this.e = z;
        if (z) {
            return;
        }
        this.h = System.currentTimeMillis() - this.g;
    }

    public void setInterval(long j) {
        this.g = System.currentTimeMillis();
        this.d = j;
    }

    public void setOnTickListener(OnTickListener onTickListener) {
        this.f926b = onTickListener;
    }

    public void setPeriod(long j) {
        this.g = System.currentTimeMillis();
        this.d = j;
    }

    public void start() {
        this.f927c.start();
    }

    public void stop() {
        this.f = false;
    }
}