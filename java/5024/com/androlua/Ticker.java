package com.androlua;

import android.os.Handler;
import android.os.Message;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class Ticker {
    private Handler a;
    private OnTickListener b;
    private Thread c;
    private long d = 1000;
    private boolean e = true;
    private boolean f = false;
    private long g;
    private long h;

    /* renamed from: com.androlua.Ticker$1 */
    class AnonymousClass1 extends Handler {
        AnonymousClass1() {
        }

        @Override // android.os.Handler
        public void handleMessage(Message message) {
            if (Ticker.this.b != null) {
                Ticker.this.b.onTick();
            }
        }
    }

    /* renamed from: com.androlua.Ticker$2 */
    class AnonymousClass2 extends Thread {
        AnonymousClass2() {
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() throws InterruptedException {
            Ticker.this.f = true;
            while (Ticker.this.f) {
                long jCurrentTimeMillis = System.currentTimeMillis();
                if (!Ticker.this.e) {
                    Ticker ticker = Ticker.this;
                    ticker.g = jCurrentTimeMillis - ticker.h;
                }
                if (jCurrentTimeMillis - Ticker.this.g >= Ticker.this.d) {
                    Ticker.this.g = jCurrentTimeMillis;
                    Ticker.this.a.sendEmptyMessage(0);
                }
                try {
                    Thread.sleep(1L);
                } catch (InterruptedException unused) {
                }
            }
        }
    }

    public interface OnTickListener {
        void onTick();
    }

    public Ticker() {
        a();
    }

    private void a() {
        this.a = new Handler() { // from class: com.androlua.Ticker.1
            AnonymousClass1() {
            }

            @Override // android.os.Handler
            public void handleMessage(Message message) {
                if (Ticker.this.b != null) {
                    Ticker.this.b.onTick();
                }
            }
        };
        this.c = new Thread() { // from class: com.androlua.Ticker.2
            AnonymousClass2() {
            }

            @Override // java.lang.Thread, java.lang.Runnable
            public void run() throws InterruptedException {
                Ticker.this.f = true;
                while (Ticker.this.f) {
                    long jCurrentTimeMillis = System.currentTimeMillis();
                    if (!Ticker.this.e) {
                        Ticker ticker = Ticker.this;
                        ticker.g = jCurrentTimeMillis - ticker.h;
                    }
                    if (jCurrentTimeMillis - Ticker.this.g >= Ticker.this.d) {
                        Ticker.this.g = jCurrentTimeMillis;
                        Ticker.this.a.sendEmptyMessage(0);
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
        this.b = onTickListener;
    }

    public void setPeriod(long j) {
        this.g = System.currentTimeMillis();
        this.d = j;
    }

    public void start() {
        this.c.start();
    }

    public void stop() {
        this.f = false;
    }
}