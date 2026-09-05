package com.androlua.util;

import java.util.Date;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class TimerX {
    private static long a;
    private final TimerImpl b;
    private final FinalizerHelper c;

    private static final class FinalizerHelper {
        private final TimerImpl a;

        FinalizerHelper(TimerImpl timerImpl) {
            this.a = timerImpl;
        }

        protected void finalize() throws Throwable {
            try {
                synchronized (this.a) {
                    this.a.b = true;
                    this.a.notify();
                }
            } finally {
                super.finalize();
            }
        }
    }

    private static final class TimerImpl extends Thread {
        private boolean a;
        private boolean b;
        private TimerHeap c = new TimerHeap();

        private static final class TimerHeap {
            private int a;
            private TimerTaskX[] b;
            private int c;
            private int d;

            private TimerHeap() {
                this.a = 256;
                this.b = new TimerTaskX[this.a];
                this.c = 0;
                this.d = 0;
            }

            private int a(TimerTaskX timerTaskX) {
                int i = 0;
                while (true) {
                    TimerTaskX[] timerTaskXArr = this.b;
                    if (i >= timerTaskXArr.length) {
                        return -1;
                    }
                    if (timerTaskXArr[i] == timerTaskX) {
                        return i;
                    }
                    i++;
                }
            }

            private void a() {
                int i = this.c - 1;
                int i2 = (i - 1) / 2;
                while (true) {
                    TimerTaskX[] timerTaskXArr = this.b;
                    if (timerTaskXArr[i].c >= timerTaskXArr[i2].c) {
                        return;
                    }
                    TimerTaskX timerTaskX = timerTaskXArr[i];
                    timerTaskXArr[i] = timerTaskXArr[i2];
                    timerTaskXArr[i2] = timerTaskX;
                    int i3 = i2;
                    i2 = (i2 - 1) / 2;
                    i = i3;
                }
            }

            private void a(int i) {
                int i2 = (i * 2) + 1;
                while (true) {
                    int i3 = this.c;
                    if (i2 >= i3 || i3 <= 0) {
                        return;
                    }
                    int i4 = i2 + 1;
                    if (i4 < i3) {
                        TimerTaskX[] timerTaskXArr = this.b;
                        if (timerTaskXArr[i4].c < timerTaskXArr[i2].c) {
                            i2 = i4;
                        }
                    }
                    TimerTaskX[] timerTaskXArr2 = this.b;
                    if (timerTaskXArr2[i].c < timerTaskXArr2[i2].c) {
                        return;
                    }
                    TimerTaskX timerTaskX = timerTaskXArr2[i];
                    timerTaskXArr2[i] = timerTaskXArr2[i2];
                    timerTaskXArr2[i2] = timerTaskX;
                    int i5 = i2;
                    i2 = (i2 * 2) + 1;
                    i = i5;
                }
            }

            public void adjustMinimum() {
                a(0);
            }

            public void delete(int i) {
                int i2;
                if (i < 0 || i >= (i2 = this.c)) {
                    return;
                }
                TimerTaskX[] timerTaskXArr = this.b;
                int i3 = i2 - 1;
                this.c = i3;
                timerTaskXArr[i] = timerTaskXArr[i3];
                timerTaskXArr[this.c] = null;
                a(i);
            }

            public void deleteIfCancelled() {
                int i = 0;
                while (i < this.c) {
                    if (this.b[i].b) {
                        this.d++;
                        delete(i);
                        i--;
                    }
                    i++;
                }
            }

            public void insert(TimerTaskX timerTaskX) {
                TimerTaskX[] timerTaskXArr = this.b;
                int length = timerTaskXArr.length;
                int i = this.c;
                if (length == i) {
                    TimerTaskX[] timerTaskXArr2 = new TimerTaskX[i * 2];
                    System.arraycopy(timerTaskXArr, 0, timerTaskXArr2, 0, i);
                    this.b = timerTaskXArr2;
                }
                TimerTaskX[] timerTaskXArr3 = this.b;
                int i2 = this.c;
                this.c = i2 + 1;
                timerTaskXArr3[i2] = timerTaskX;
                a();
            }

            public boolean isEmpty() {
                return this.c == 0;
            }

            public TimerTaskX minimum() {
                return this.b[0];
            }

            public void reset() {
                this.b = new TimerTaskX[this.a];
                this.c = 0;
            }
        }

        TimerImpl(String str, boolean z) {
            setName(str);
            setDaemon(z);
            start();
        }

        private void a(TimerTaskX timerTaskX) {
            this.c.insert(timerTaskX);
            notify();
        }

        public synchronized void cancel() {
            this.a = true;
            this.c.reset();
            notify();
        }

        public int purge() {
            if (this.c.isEmpty()) {
                return 0;
            }
            this.c.d = 0;
            this.c.deleteIfCancelled();
            return this.c.d;
        }

        /* JADX WARN: Code restructure failed: missing block: B:51:0x0098, code lost:
        
            if (r2.isEnabled() == false) goto L94;
         */
        /* JADX WARN: Code restructure failed: missing block: B:52:0x009a, code lost:
        
            r2.run();
         */
        /* JADX WARN: Code restructure failed: missing block: B:54:0x009f, code lost:
        
            r0 = move-exception;
         */
        /* JADX WARN: Code restructure failed: missing block: B:55:0x00a0, code lost:
        
            monitor-enter(r10);
         */
        /* JADX WARN: Code restructure failed: missing block: B:57:0x00a2, code lost:
        
            r10.a = true;
         */
        /* JADX WARN: Code restructure failed: missing block: B:59:0x00a5, code lost:
        
            throw r0;
         */
        /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
        @Override // java.lang.Thread, java.lang.Runnable
        /*
            Code decompiled incorrectly, please refer to instructions dump.
            To view partially-correct code enable 'Show inconsistent code' option in preferences
        */
        public void run() {
            /*
                r10 = this;
            L0:
                monitor-enter(r10)
                boolean r0 = r10.a     // Catch: java.lang.Throwable -> Laf
                if (r0 == 0) goto L7
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                return
            L7:
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.c     // Catch: java.lang.Throwable -> Laf
                boolean r0 = r0.isEmpty()     // Catch: java.lang.Throwable -> Laf
                if (r0 == 0) goto L1a
                boolean r0 = r10.b     // Catch: java.lang.Throwable -> Laf
                if (r0 == 0) goto L15
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                return
            L15:
                r10.wait()     // Catch: java.lang.InterruptedException -> L18 java.lang.Throwable -> Laf
            L18:
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                goto L0
            L1a:
                long r0 = java.lang.System.currentTimeMillis()     // Catch: java.lang.Throwable -> Laf
                com.androlua.util.TimerX$TimerImpl$TimerHeap r2 = r10.c     // Catch: java.lang.Throwable -> Laf
                com.androlua.util.TimerTaskX r2 = r2.minimum()     // Catch: java.lang.Throwable -> Laf
                java.lang.Object r3 = r2.a     // Catch: java.lang.Throwable -> Laf
                monitor-enter(r3)     // Catch: java.lang.Throwable -> Laf
                boolean r4 = r2.b     // Catch: java.lang.Throwable -> Lac
                r5 = 0
                if (r4 == 0) goto L33
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.c     // Catch: java.lang.Throwable -> Lac
                r0.delete(r5)     // Catch: java.lang.Throwable -> Lac
                monitor-exit(r3)     // Catch: java.lang.Throwable -> Lac
                goto L18
            L33:
                long r6 = r2.c     // Catch: java.lang.Throwable -> Lac
                long r6 = r6 - r0
                monitor-exit(r3)     // Catch: java.lang.Throwable -> Lac
                r0 = 0
                int r3 = (r6 > r0 ? 1 : (r6 == r0 ? 0 : -1))
                if (r3 <= 0) goto L41
                r10.wait(r6)     // Catch: java.lang.InterruptedException -> L18 java.lang.Throwable -> Laf
                goto L18
            L41:
                java.lang.Object r3 = r2.a     // Catch: java.lang.Throwable -> Laf
                monitor-enter(r3)     // Catch: java.lang.Throwable -> Laf
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.c     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerTaskX r4 = r4.minimum()     // Catch: java.lang.Throwable -> La9
                long r6 = r4.c     // Catch: java.lang.Throwable -> La9
                long r8 = r2.c     // Catch: java.lang.Throwable -> La9
                int r4 = (r6 > r8 ? 1 : (r6 == r8 ? 0 : -1))
                if (r4 == 0) goto L58
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.c     // Catch: java.lang.Throwable -> La9
                int r5 = com.androlua.util.TimerX.TimerImpl.TimerHeap.a(r4, r2)     // Catch: java.lang.Throwable -> La9
            L58:
                boolean r4 = r2.b     // Catch: java.lang.Throwable -> La9
                if (r4 == 0) goto L69
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.c     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerX$TimerImpl$TimerHeap r1 = r10.c     // Catch: java.lang.Throwable -> La9
                int r1 = com.androlua.util.TimerX.TimerImpl.TimerHeap.a(r1, r2)     // Catch: java.lang.Throwable -> La9
                r0.delete(r1)     // Catch: java.lang.Throwable -> La9
                monitor-exit(r3)     // Catch: java.lang.Throwable -> La9
                goto L18
            L69:
                long r6 = r2.c     // Catch: java.lang.Throwable -> La9
                r2.setScheduledTime(r6)     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.c     // Catch: java.lang.Throwable -> La9
                r4.delete(r5)     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
                int r6 = (r4 > r0 ? 1 : (r4 == r0 ? 0 : -1))
                if (r6 < 0) goto L90
                boolean r0 = r2.e     // Catch: java.lang.Throwable -> La9
                if (r0 == 0) goto L85
                long r0 = r2.c     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
            L81:
                long r0 = r0 + r4
                r2.c = r0     // Catch: java.lang.Throwable -> La9
                goto L8c
            L85:
                long r0 = java.lang.System.currentTimeMillis()     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
                goto L81
            L8c:
                r10.a(r2)     // Catch: java.lang.Throwable -> La9
                goto L92
            L90:
                r2.c = r0     // Catch: java.lang.Throwable -> La9
            L92:
                monitor-exit(r3)     // Catch: java.lang.Throwable -> La9
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                boolean r0 = r2.isEnabled()     // Catch: java.lang.Throwable -> L9f
                if (r0 == 0) goto L0
                r2.run()     // Catch: java.lang.Throwable -> L9f
                goto L0
            L9f:
                r0 = move-exception
                monitor-enter(r10)
                r1 = 1
                r10.a = r1     // Catch: java.lang.Throwable -> La6
                monitor-exit(r10)     // Catch: java.lang.Throwable -> La6
                throw r0
            La6:
                r0 = move-exception
                monitor-exit(r10)     // Catch: java.lang.Throwable -> La6
                throw r0
            La9:
                r0 = move-exception
                monitor-exit(r3)     // Catch: java.lang.Throwable -> La9
                throw r0     // Catch: java.lang.Throwable -> Laf
            Lac:
                r0 = move-exception
                monitor-exit(r3)     // Catch: java.lang.Throwable -> Lac
                throw r0     // Catch: java.lang.Throwable -> Laf
            Laf:
                r0 = move-exception
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                throw r0
                return
            */
            throw new UnsupportedOperationException("Method not decompiled: com.androlua.util.TimerX.TimerImpl.run():void");
        }
    }

    public TimerX() {
        this(false);
    }

    public TimerX(String str) {
        this(str, false);
    }

    public TimerX(String str, boolean z) {
        if (str == null) {
            throw new NullPointerException("name is null");
        }
        this.b = new TimerImpl(str, z);
        this.c = new FinalizerHelper(this.b);
    }

    public TimerX(boolean z) {
        this("Timer-" + a(), z);
    }

    private static synchronized long a() {
        long j;
        j = a;
        a = 1 + j;
        return j;
    }

    private void a(TimerTaskX timerTaskX, long j, long j2, boolean z) {
        synchronized (this.b) {
            if (this.b.a) {
                throw new IllegalStateException("Timer was canceled");
            }
            long jCurrentTimeMillis = j + System.currentTimeMillis();
            if (jCurrentTimeMillis < 0) {
                throw new IllegalArgumentException("Illegal delay to start the TimerTask: " + jCurrentTimeMillis);
            }
            synchronized (timerTaskX.a) {
                if (timerTaskX.a()) {
                    throw new IllegalStateException("TimerTask is scheduled already");
                }
                if (timerTaskX.b) {
                    throw new IllegalStateException("TimerTask is canceled");
                }
                timerTaskX.c = jCurrentTimeMillis;
                timerTaskX.d = j2;
                timerTaskX.e = z;
            }
            this.b.a(timerTaskX);
        }
    }

    public void cancel() {
        this.b.cancel();
    }

    public int purge() {
        int iPurge;
        synchronized (this.b) {
            iPurge = this.b.purge();
        }
        return iPurge;
    }

    public void schedule(TimerTaskX timerTaskX, long j) {
        if (j < 0) {
            throw new IllegalArgumentException();
        }
        a(timerTaskX, j, -1L, false);
    }

    public void schedule(TimerTaskX timerTaskX, long j, long j2) {
        if (j < 0 || j2 <= 0) {
            throw new IllegalArgumentException();
        }
        a(timerTaskX, j, j2, false);
    }

    public void schedule(TimerTaskX timerTaskX, Date date) {
        if (date.getTime() < 0) {
            throw new IllegalArgumentException();
        }
        long time = date.getTime() - System.currentTimeMillis();
        a(timerTaskX, time < 0 ? 0L : time, -1L, false);
    }

    public void schedule(TimerTaskX timerTaskX, Date date, long j) {
        if (j <= 0 || date.getTime() < 0) {
            throw new IllegalArgumentException();
        }
        long time = date.getTime() - System.currentTimeMillis();
        a(timerTaskX, time < 0 ? 0L : time, j, false);
    }

    public void scheduleAtFixedRate(TimerTaskX timerTaskX, long j, long j2) {
        if (j < 0 || j2 <= 0) {
            throw new IllegalArgumentException();
        }
        a(timerTaskX, j, j2, true);
    }

    public void scheduleAtFixedRate(TimerTaskX timerTaskX, Date date, long j) {
        if (j <= 0 || date.getTime() < 0) {
            throw new IllegalArgumentException();
        }
        a(timerTaskX, date.getTime() - System.currentTimeMillis(), j, true);
    }
}