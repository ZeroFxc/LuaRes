package com.androlua.util;

import java.util.Date;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class TimerX {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static long f974a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private final TimerImpl f975b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private final FinalizerHelper f976c;

    private static final class FinalizerHelper {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private final TimerImpl f977a;

        FinalizerHelper(TimerImpl timerImpl) {
            this.f977a = timerImpl;
        }

        protected void finalize() throws Throwable {
            try {
                synchronized (this.f977a) {
                    this.f977a.f979b = true;
                    this.f977a.notify();
                }
            } finally {
                super.finalize();
            }
        }
    }

    private static final class TimerImpl extends Thread {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private boolean f978a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private boolean f979b;

        /* JADX INFO: renamed from: c, reason: collision with root package name */
        private TimerHeap f980c = new TimerHeap();

        private static final class TimerHeap {

            /* JADX INFO: renamed from: a, reason: collision with root package name */
            private int f981a;

            /* JADX INFO: renamed from: b, reason: collision with root package name */
            private TimerTaskX[] f982b;

            /* JADX INFO: renamed from: c, reason: collision with root package name */
            private int f983c;
            private int d;

            private TimerHeap() {
                this.f981a = 256;
                this.f982b = new TimerTaskX[this.f981a];
                this.f983c = 0;
                this.d = 0;
            }

            private int a(TimerTaskX timerTaskX) {
                int i = 0;
                while (true) {
                    TimerTaskX[] timerTaskXArr = this.f982b;
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
                int i = this.f983c - 1;
                int i2 = (i - 1) / 2;
                while (true) {
                    TimerTaskX[] timerTaskXArr = this.f982b;
                    if (timerTaskXArr[i].f973c >= timerTaskXArr[i2].f973c) {
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
                    int i3 = this.f983c;
                    if (i2 >= i3 || i3 <= 0) {
                        return;
                    }
                    int i4 = i2 + 1;
                    if (i4 < i3) {
                        TimerTaskX[] timerTaskXArr = this.f982b;
                        if (timerTaskXArr[i4].f973c < timerTaskXArr[i2].f973c) {
                            i2 = i4;
                        }
                    }
                    TimerTaskX[] timerTaskXArr2 = this.f982b;
                    if (timerTaskXArr2[i].f973c < timerTaskXArr2[i2].f973c) {
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
                if (i < 0 || i >= (i2 = this.f983c)) {
                    return;
                }
                TimerTaskX[] timerTaskXArr = this.f982b;
                int i3 = i2 - 1;
                this.f983c = i3;
                timerTaskXArr[i] = timerTaskXArr[i3];
                timerTaskXArr[this.f983c] = null;
                a(i);
            }

            public void deleteIfCancelled() {
                int i = 0;
                while (i < this.f983c) {
                    if (this.f982b[i].f972b) {
                        this.d++;
                        delete(i);
                        i--;
                    }
                    i++;
                }
            }

            public void insert(TimerTaskX timerTaskX) {
                TimerTaskX[] timerTaskXArr = this.f982b;
                int length = timerTaskXArr.length;
                int i = this.f983c;
                if (length == i) {
                    TimerTaskX[] timerTaskXArr2 = new TimerTaskX[i * 2];
                    System.arraycopy(timerTaskXArr, 0, timerTaskXArr2, 0, i);
                    this.f982b = timerTaskXArr2;
                }
                TimerTaskX[] timerTaskXArr3 = this.f982b;
                int i2 = this.f983c;
                this.f983c = i2 + 1;
                timerTaskXArr3[i2] = timerTaskX;
                a();
            }

            public boolean isEmpty() {
                return this.f983c == 0;
            }

            public TimerTaskX minimum() {
                return this.f982b[0];
            }

            public void reset() {
                this.f982b = new TimerTaskX[this.f981a];
                this.f983c = 0;
            }
        }

        TimerImpl(String str, boolean z) {
            setName(str);
            setDaemon(z);
            start();
        }

        private void a(TimerTaskX timerTaskX) {
            this.f980c.insert(timerTaskX);
            notify();
        }

        public synchronized void cancel() {
            this.f978a = true;
            this.f980c.reset();
            notify();
        }

        public int purge() {
            if (this.f980c.isEmpty()) {
                return 0;
            }
            this.f980c.d = 0;
            this.f980c.deleteIfCancelled();
            return this.f980c.d;
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
        
            r10.f978a = true;
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
                boolean r0 = r10.f978a     // Catch: java.lang.Throwable -> Laf
                if (r0 == 0) goto L7
                monitor-exit(r10)     // Catch: java.lang.Throwable -> Laf
                return
            L7:
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.f980c     // Catch: java.lang.Throwable -> Laf
                boolean r0 = r0.isEmpty()     // Catch: java.lang.Throwable -> Laf
                if (r0 == 0) goto L1a
                boolean r0 = r10.f979b     // Catch: java.lang.Throwable -> Laf
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
                com.androlua.util.TimerX$TimerImpl$TimerHeap r2 = r10.f980c     // Catch: java.lang.Throwable -> Laf
                com.androlua.util.TimerTaskX r2 = r2.minimum()     // Catch: java.lang.Throwable -> Laf
                java.lang.Object r3 = r2.f971a     // Catch: java.lang.Throwable -> Laf
                monitor-enter(r3)     // Catch: java.lang.Throwable -> Laf
                boolean r4 = r2.f972b     // Catch: java.lang.Throwable -> Lac
                r5 = 0
                if (r4 == 0) goto L33
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.f980c     // Catch: java.lang.Throwable -> Lac
                r0.delete(r5)     // Catch: java.lang.Throwable -> Lac
                monitor-exit(r3)     // Catch: java.lang.Throwable -> Lac
                goto L18
            L33:
                long r6 = r2.f973c     // Catch: java.lang.Throwable -> Lac
                long r6 = r6 - r0
                monitor-exit(r3)     // Catch: java.lang.Throwable -> Lac
                r0 = 0
                int r3 = (r6 > r0 ? 1 : (r6 == r0 ? 0 : -1))
                if (r3 <= 0) goto L41
                r10.wait(r6)     // Catch: java.lang.InterruptedException -> L18 java.lang.Throwable -> Laf
                goto L18
            L41:
                java.lang.Object r3 = r2.f971a     // Catch: java.lang.Throwable -> Laf
                monitor-enter(r3)     // Catch: java.lang.Throwable -> Laf
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.f980c     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerTaskX r4 = r4.minimum()     // Catch: java.lang.Throwable -> La9
                long r6 = r4.f973c     // Catch: java.lang.Throwable -> La9
                long r8 = r2.f973c     // Catch: java.lang.Throwable -> La9
                int r4 = (r6 > r8 ? 1 : (r6 == r8 ? 0 : -1))
                if (r4 == 0) goto L58
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.f980c     // Catch: java.lang.Throwable -> La9
                int r5 = com.androlua.util.TimerX.TimerImpl.TimerHeap.a(r4, r2)     // Catch: java.lang.Throwable -> La9
            L58:
                boolean r4 = r2.f972b     // Catch: java.lang.Throwable -> La9
                if (r4 == 0) goto L69
                com.androlua.util.TimerX$TimerImpl$TimerHeap r0 = r10.f980c     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerX$TimerImpl$TimerHeap r1 = r10.f980c     // Catch: java.lang.Throwable -> La9
                int r1 = com.androlua.util.TimerX.TimerImpl.TimerHeap.a(r1, r2)     // Catch: java.lang.Throwable -> La9
                r0.delete(r1)     // Catch: java.lang.Throwable -> La9
                monitor-exit(r3)     // Catch: java.lang.Throwable -> La9
                goto L18
            L69:
                long r6 = r2.f973c     // Catch: java.lang.Throwable -> La9
                r2.setScheduledTime(r6)     // Catch: java.lang.Throwable -> La9
                com.androlua.util.TimerX$TimerImpl$TimerHeap r4 = r10.f980c     // Catch: java.lang.Throwable -> La9
                r4.delete(r5)     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
                int r6 = (r4 > r0 ? 1 : (r4 == r0 ? 0 : -1))
                if (r6 < 0) goto L90
                boolean r0 = r2.e     // Catch: java.lang.Throwable -> La9
                if (r0 == 0) goto L85
                long r0 = r2.f973c     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
            L81:
                long r0 = r0 + r4
                r2.f973c = r0     // Catch: java.lang.Throwable -> La9
                goto L8c
            L85:
                long r0 = java.lang.System.currentTimeMillis()     // Catch: java.lang.Throwable -> La9
                long r4 = r2.d     // Catch: java.lang.Throwable -> La9
                goto L81
            L8c:
                r10.a(r2)     // Catch: java.lang.Throwable -> La9
                goto L92
            L90:
                r2.f973c = r0     // Catch: java.lang.Throwable -> La9
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
                r10.f978a = r1     // Catch: java.lang.Throwable -> La6
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
        this.f975b = new TimerImpl(str, z);
        this.f976c = new FinalizerHelper(this.f975b);
    }

    public TimerX(boolean z) {
        this("Timer-" + a(), z);
    }

    private static synchronized long a() {
        long j;
        j = f974a;
        f974a = 1 + j;
        return j;
    }

    private void a(TimerTaskX timerTaskX, long j, long j2, boolean z) {
        synchronized (this.f975b) {
            if (this.f975b.f978a) {
                throw new IllegalStateException("Timer was canceled");
            }
            long jCurrentTimeMillis = j + System.currentTimeMillis();
            if (jCurrentTimeMillis < 0) {
                throw new IllegalArgumentException("Illegal delay to start the TimerTask: " + jCurrentTimeMillis);
            }
            synchronized (timerTaskX.f971a) {
                if (timerTaskX.a()) {
                    throw new IllegalStateException("TimerTask is scheduled already");
                }
                if (timerTaskX.f972b) {
                    throw new IllegalStateException("TimerTask is canceled");
                }
                timerTaskX.f973c = jCurrentTimeMillis;
                timerTaskX.d = j2;
                timerTaskX.e = z;
            }
            this.f975b.a(timerTaskX);
        }
    }

    public void cancel() {
        this.f975b.cancel();
    }

    public int purge() {
        int iPurge;
        synchronized (this.f975b) {
            iPurge = this.f975b.purge();
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