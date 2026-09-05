package com.androlua.util;

import android.os.Binder;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.Process;
import android.util.Log;
import java.util.ArrayDeque;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.Callable;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.FutureTask;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public abstract class AsyncTaskX<Params, Progress, Result> {
    public static final Executor SERIAL_EXECUTOR;
    public static final Executor THREAD_POOL_EXECUTOR;
    private static final int a = Runtime.getRuntime().availableProcessors();
    private static final ThreadFactory b = new ThreadFactory() { // from class: com.androlua.util.AsyncTaskX.1
        private final AtomicInteger a = new AtomicInteger(1);

        AnonymousClass1() {
        }

        @Override // java.util.concurrent.ThreadFactory
        public Thread newThread(Runnable runnable) {
            return new Thread(runnable, "AsyncTask #" + this.a.getAndIncrement());
        }
    };
    private static final BlockingQueue<Runnable> c = new LinkedBlockingQueue(8192);
    private static volatile Executor d;
    private static InternalHandler e;
    private final WorkerRunnable<Params, Result> f;
    private final FutureTask<Result> g;
    private volatile Status h;
    private final AtomicBoolean i;
    private final AtomicBoolean j;
    private final Handler k;

    /* renamed from: com.androlua.util.AsyncTaskX$1 */
    class AnonymousClass1 implements ThreadFactory {
        private final AtomicInteger a = new AtomicInteger(1);

        AnonymousClass1() {
        }

        @Override // java.util.concurrent.ThreadFactory
        public Thread newThread(Runnable runnable) {
            return new Thread(runnable, "AsyncTask #" + this.a.getAndIncrement());
        }
    }

    /* renamed from: com.androlua.util.AsyncTaskX$2 */
    class AnonymousClass2 extends WorkerRunnable<Params, Result> {
        AnonymousClass2() {
        }

        @Override // java.util.concurrent.Callable
        public Result call() {
            AsyncTaskX.this.j.set(true);
            Result result = null;
            try {
                try {
                    Process.setThreadPriority(10);
                    result = (Result) AsyncTaskX.this.a((Object[]) this.a);
                    Binder.flushPendingCommands();
                    return result;
                } catch (Throwable th) {
                    AsyncTaskX.this.i.set(true);
                    throw th;
                }
            } finally {
                AsyncTaskX.a(AsyncTaskX.this, result);
            }
        }
    }

    /* renamed from: com.androlua.util.AsyncTaskX$3 */
    class AnonymousClass3 extends FutureTask<Result> {
        AnonymousClass3(Callable callable) {
            super(callable);
        }

        @Override // java.util.concurrent.FutureTask
        protected void done() {
            try {
                AsyncTaskX.this.e(get());
            } catch (InterruptedException e) {
                Log.w("AsyncTaskX", e);
            } catch (CancellationException unused) {
                AsyncTaskX.this.e(null);
            } catch (ExecutionException e2) {
                throw new RuntimeException("An error occurred while executing doInBackground()", e2.getCause());
            }
        }
    }

    /* renamed from: com.androlua.util.AsyncTaskX$4 */
    static /* synthetic */ class AnonymousClass4 {
        static final /* synthetic */ int[] a = new int[Status.values().length];

        static {
            try {
                a[Status.RUNNING.ordinal()] = 1;
            } catch (NoSuchFieldError unused) {
            }
            try {
                a[Status.FINISHED.ordinal()] = 2;
            } catch (NoSuchFieldError unused2) {
            }
        }
    }

    private static class AsyncTaskResult<Data> {
        final AsyncTaskX a;
        final Data[] b;

        AsyncTaskResult(AsyncTaskX asyncTaskX, Data... dataArr) {
            this.a = asyncTaskX;
            this.b = dataArr;
        }
    }

    private static class InternalHandler extends Handler {
        public InternalHandler(Looper looper) {
            super(looper);
        }

        @Override // android.os.Handler
        public void handleMessage(Message message) {
            AsyncTaskResult asyncTaskResult = (AsyncTaskResult) message.obj;
            int i = message.what;
            if (i == 1) {
                asyncTaskResult.a.c((AsyncTaskX) asyncTaskResult.b[0]);
            } else {
                if (i != 2) {
                    return;
                }
                asyncTaskResult.a.b((Object[]) asyncTaskResult.b);
            }
        }
    }

    private static class SerialExecutor implements Executor {
        final ArrayDeque<Runnable> a;
        Runnable b;

        /* renamed from: com.androlua.util.AsyncTaskX$SerialExecutor$1 */
        class AnonymousClass1 implements Runnable {
            final /* synthetic */ Runnable a;

            AnonymousClass1(Runnable runnable) {
                runnable = runnable;
            }

            @Override // java.lang.Runnable
            public void run() {
                try {
                    runnable.run();
                } finally {
                    SerialExecutor.this.a();
                }
            }
        }

        private SerialExecutor() {
            this.a = new ArrayDeque<>();
        }

        /* synthetic */ SerialExecutor(AnonymousClass1 anonymousClass1) {
            this();
        }

        protected synchronized void a() {
            Runnable runnablePoll = this.a.poll();
            this.b = runnablePoll;
            if (runnablePoll != null) {
                AsyncTaskX.THREAD_POOL_EXECUTOR.execute(this.b);
            }
        }

        @Override // java.util.concurrent.Executor
        public synchronized void execute(Runnable runnable) {
            this.a.offer(new Runnable() { // from class: com.androlua.util.AsyncTaskX.SerialExecutor.1
                final /* synthetic */ Runnable a;

                AnonymousClass1(Runnable runnable2) {
                    runnable = runnable2;
                }

                @Override // java.lang.Runnable
                public void run() {
                    try {
                        runnable.run();
                    } finally {
                        SerialExecutor.this.a();
                    }
                }
            });
            if (this.b == null) {
                a();
            }
        }
    }

    public enum Status {
        PENDING,
        RUNNING,
        FINISHED
    }

    private static abstract class WorkerRunnable<Params, Result> implements Callable<Result> {
        Params[] a;

        private WorkerRunnable() {
        }

        /* synthetic */ WorkerRunnable(AnonymousClass1 anonymousClass1) {
            this();
        }
    }

    static {
        ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(1024, 1024, 30L, TimeUnit.SECONDS, c, b);
        threadPoolExecutor.allowCoreThreadTimeOut(true);
        THREAD_POOL_EXECUTOR = threadPoolExecutor;
        SERIAL_EXECUTOR = new SerialExecutor();
        d = THREAD_POOL_EXECUTOR;
    }

    public AsyncTaskX() {
        this((Looper) null);
    }

    public AsyncTaskX(Handler handler) {
        this(handler != null ? handler.getLooper() : null);
    }

    public AsyncTaskX(Looper looper) {
        this.h = Status.PENDING;
        this.i = new AtomicBoolean();
        this.j = new AtomicBoolean();
        this.k = (looper == null || looper == Looper.getMainLooper()) ? d() : new Handler(looper);
        this.f = new WorkerRunnable<Params, Result>() { // from class: com.androlua.util.AsyncTaskX.2
            AnonymousClass2() {
            }

            @Override // java.util.concurrent.Callable
            public Result call() {
                AsyncTaskX.this.j.set(true);
                Result result = null;
                try {
                    try {
                        Process.setThreadPriority(10);
                        result = (Result) AsyncTaskX.this.a((Object[]) this.a);
                        Binder.flushPendingCommands();
                        return result;
                    } catch (Throwable th) {
                        AsyncTaskX.this.i.set(true);
                        throw th;
                    }
                } finally {
                    AsyncTaskX.a(AsyncTaskX.this, result);
                }
            }
        };
        this.g = new FutureTask<Result>(this.f) { // from class: com.androlua.util.AsyncTaskX.3
            AnonymousClass3(Callable callable) {
                super(callable);
            }

            @Override // java.util.concurrent.FutureTask
            protected void done() {
                try {
                    AsyncTaskX.this.e(get());
                } catch (InterruptedException e2) {
                    Log.w("AsyncTaskX", e2);
                } catch (CancellationException unused) {
                    AsyncTaskX.this.e(null);
                } catch (ExecutionException e22) {
                    throw new RuntimeException("An error occurred while executing doInBackground()", e22.getCause());
                }
            }
        };
    }

    static /* synthetic */ Object a(AsyncTaskX asyncTaskX, Object obj) {
        asyncTaskX.d(obj);
        return obj;
    }

    private Handler c() {
        return this.k;
    }

    private void c(Result result) {
        if (isCancelled()) {
            a((AsyncTaskX<Params, Progress, Result>) result);
        } else {
            b((AsyncTaskX<Params, Progress, Result>) result);
        }
        this.h = Status.FINISHED;
    }

    private static Handler d() {
        InternalHandler internalHandler;
        synchronized (AsyncTaskX.class) {
            if (e == null) {
                e = new InternalHandler(Looper.getMainLooper());
            }
            internalHandler = e;
        }
        return internalHandler;
    }

    private Result d(Result result) {
        c().obtainMessage(1, new AsyncTaskResult(this, result)).sendToTarget();
        return result;
    }

    private void e(Result result) {
        if (this.j.get()) {
            return;
        }
        d(result);
    }

    public static void execute(Runnable runnable) {
        d.execute(runnable);
    }

    public static void setDefaultExecutor(Executor executor) {
        d = executor;
    }

    protected abstract Result a(Params... paramsArr);

    protected void a() {
    }

    protected void a(Result result) {
        a();
    }

    protected void b() {
    }

    protected void b(Result result) {
    }

    protected void b(Progress... progressArr) {
    }

    protected final void c(Progress... progressArr) {
        if (isCancelled()) {
            return;
        }
        c().obtainMessage(2, new AsyncTaskResult(this, progressArr)).sendToTarget();
    }

    public final boolean cancel(boolean z) {
        this.i.set(true);
        return this.g.cancel(z);
    }

    public final AsyncTaskX<Params, Progress, Result> execute(Params... paramsArr) {
        return executeOnExecutor(d, paramsArr);
    }

    public final AsyncTaskX<Params, Progress, Result> executeOnExecutor(Executor executor, Params... paramsArr) {
        if (this.h != Status.PENDING) {
            int i = AnonymousClass4.a[this.h.ordinal()];
            if (i == 1) {
                throw new IllegalStateException("Cannot execute task: the task is already running.");
            }
            if (i == 2) {
                throw new IllegalStateException("Cannot execute task: the task has already been executed (a task can be executed only once)");
            }
        }
        this.h = Status.RUNNING;
        b();
        this.f.a = paramsArr;
        executor.execute(this.g);
        return this;
    }

    public final Result get() {
        return this.g.get();
    }

    public final Result get(long j, TimeUnit timeUnit) {
        return this.g.get(j, timeUnit);
    }

    public final Status getStatus() {
        return this.h;
    }

    public final boolean isCancelled() {
        return this.i.get();
    }
}