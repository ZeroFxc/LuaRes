package com.androlua;

import com.androlua.util.AsyncTaskX;
import com.luajava.JavaFunction;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaAsyncTask extends AsyncTaskX implements LuaGcable {
    private Object[] l;
    private boolean m;
    private LuaState n;
    private LuaContext o;
    private byte[] p;
    private long q;
    private LuaObject r;
    private LuaObject s;

    /* renamed from: com.androlua.LuaAsyncTask$1 */
    class AnonymousClass1 extends JavaFunction {
        AnonymousClass1(LuaState luaState) {
            super(luaState);
        }

        @Override // com.luajava.JavaFunction
        public int execute() {
            LuaAsyncTask.this.update(this.a.toJavaObject(2));
            return 0;
        }
    }

    static {
        AsyncTaskX.setDefaultExecutor(AsyncTaskX.THREAD_POOL_EXECUTOR);
    }

    public LuaAsyncTask(LuaContext luaContext, long j, LuaObject luaObject) {
        this.q = 0L;
        luaContext.regGc(this);
        this.o = luaContext;
        this.q = j;
        this.r = luaObject;
    }

    public LuaAsyncTask(LuaContext luaContext, LuaObject luaObject, LuaObject luaObject2) {
        this.q = 0L;
        luaContext.regGc(this);
        this.o = luaContext;
        this.p = luaObject.dump();
        this.r = luaObject2;
        LuaObject field = luaObject.getLuaState().getLuaObject("luajava").getField("imported");
        if (field.isNil()) {
            return;
        }
        this.l = field.asArray();
    }

    public LuaAsyncTask(LuaContext luaContext, LuaObject luaObject, LuaObject luaObject2, LuaObject luaObject3) {
        this.q = 0L;
        luaContext.regGc(this);
        this.o = luaContext;
        this.p = luaObject.dump();
        this.s = luaObject2;
        this.r = luaObject3;
    }

    public LuaAsyncTask(LuaContext luaContext, String str, LuaObject luaObject) {
        this.q = 0L;
        luaContext.regGc(this);
        this.o = luaContext;
        this.p = str.getBytes();
        this.r = luaObject;
    }

    private String a(int i) {
        switch (i) {
            case 1:
                return "Yield error";
            case 2:
                return "Runtime error";
            case 3:
                return "Syntax error";
            case 4:
                return "Out of memory";
            case 5:
                return "GC error";
            case 6:
                return "error error";
            default:
                return "Unknown error " + i;
        }
    }

    /* JADX WARN: Can't wrap try/catch for region: R(8:58|(6:(1:60)(12:62|(1:64)|65|98|66|70|(4:72|95|73|(2:75|76))|97|77|(5:79|(1:81)|102|82|(4:84|(1:86)|103|87))|88|89)|97|77|(0)|88|89)|61|65|98|66|70|(0)) */
    /* JADX WARN: Code restructure failed: missing block: B:68:0x00b5, code lost:
    
        r1 = move-exception;
     */
    /* JADX WARN: Code restructure failed: missing block: B:69:0x00b6, code lost:
    
        r9.o.sendError("AsyncTask", r1);
     */
    /* JADX WARN: Removed duplicated region for block: B:72:0x00c2  */
    /* JADX WARN: Removed duplicated region for block: B:79:0x00ff A[Catch: Exception -> 0x016b, TryCatch #1 {Exception -> 0x016b, blocks: (B:77:0x00ed, B:79:0x00ff, B:81:0x011b, B:82:0x0125, B:84:0x012e, B:86:0x0139, B:88:0x0147, B:89:0x016a), top: B:97:0x00ed }] */
    @Override // com.androlua.util.AsyncTaskX
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    protected java.lang.Object a(java.lang.Object[] r10) throws java.lang.InterruptedException, com.luajava.LuaException {
        /*
            Method dump skipped, instructions count: 373
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaAsyncTask.a(java.lang.Object[]):java.lang.Object");
    }

    @Override // com.androlua.util.AsyncTaskX
    protected void b(Object obj) {
        if (isCancelled()) {
            return;
        }
        try {
            if (this.r != null) {
                this.r.call((Object[]) obj);
            }
        } catch (LuaException e) {
            this.o.sendError("onPostExecute", e);
        }
        LuaState luaState = this.n;
        if (luaState != null) {
            luaState.gc(2, 1);
        }
        System.gc();
    }

    @Override // com.androlua.util.AsyncTaskX
    protected void b(Object[] objArr) {
        try {
            if (this.s != null) {
                this.s.call(objArr);
            }
        } catch (LuaException e) {
            this.o.sendError("onProgressUpdate", e);
        }
        super.b(objArr);
    }

    public void execute() {
        super.execute(new Object[0]);
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        if (getStatus() == AsyncTaskX.Status.RUNNING) {
            cancel(true);
        }
        this.m = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.m;
    }

    public void update(int i) {
        c(Integer.valueOf(i));
    }

    public void update(Object obj) {
        c(obj);
    }

    public void update(String str) {
        c(str);
    }
}