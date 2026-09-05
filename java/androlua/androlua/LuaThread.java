package com.androlua;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import com.baidu.mobstat.Config;
import com.luajava.JavaFunction;
import com.luajava.LuaException;
import com.luajava.LuaMetaTable;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import java.io.IOException;
import java.util.regex.Pattern;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaThread extends Thread implements Runnable, LuaMetaTable, LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private boolean f869a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaState f870b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private Handler f871c;
    private LuaContext d;
    private boolean e;
    private String f;
    private Object[] g;
    private byte[] h;
    public boolean isRun;

    private class ThreadHandler extends Handler {
        private ThreadHandler() {
        }

        @Override // android.os.Handler
        public void handleMessage(Message message) {
            super.handleMessage(message);
            Bundle data = message.getData();
            int i = message.what;
            if (i == 0) {
                LuaThread.this.c(data.getString("data"), (Object[]) data.getSerializable("args"));
                return;
            }
            if (i == 1) {
                LuaThread.this.d(data.getString("data"), (Object[]) data.getSerializable("args"));
                return;
            }
            if (i == 2) {
                LuaThread.this.c(data.getString("data"), new Object[0]);
            } else if (i == 3) {
                LuaThread.this.d(data.getString("data"), new Object[0]);
            } else {
                if (i != 4) {
                    return;
                }
                LuaThread.this.a(data.getString("data"), ((Object[]) data.getSerializable("args"))[0]);
            }
        }
    }

    public LuaThread(LuaContext luaContext, LuaObject luaObject) {
        this(luaContext, luaObject, false, (Object[]) null);
    }

    public LuaThread(LuaContext luaContext, LuaObject luaObject, boolean z) {
        this(luaContext, luaObject, z, (Object[]) null);
    }

    public LuaThread(LuaContext luaContext, LuaObject luaObject, boolean z, Object[] objArr) {
        this.isRun = false;
        this.g = new Object[0];
        this.d = luaContext;
        if (objArr != null) {
            this.g = objArr;
        }
        this.e = z;
        this.h = luaObject.dump();
    }

    public LuaThread(LuaContext luaContext, LuaObject luaObject, Object[] objArr) {
        this(luaContext, luaObject, false, objArr);
    }

    public LuaThread(LuaContext luaContext, String str) {
        this(luaContext, str, false, (Object[]) null);
    }

    public LuaThread(LuaContext luaContext, String str, boolean z) {
        this(luaContext, str, z, (Object[]) null);
    }

    public LuaThread(LuaContext luaContext, String str, boolean z, Object[] objArr) {
        this.isRun = false;
        this.g = new Object[0];
        luaContext.regGc(this);
        this.d = luaContext;
        this.f = str;
        this.e = z;
        if (objArr != null) {
            this.g = objArr;
        }
    }

    public LuaThread(LuaContext luaContext, String str, Object[] objArr) {
        this(luaContext, str, false, objArr);
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

    private void a() {
        LuaState luaState;
        String str;
        this.f870b = LuaStateFactory.newLuaState();
        this.f870b.openLibs();
        this.f870b.pushJavaObject(this.d.getContext());
        LuaContext luaContext = this.d;
        if (!(luaContext instanceof LuaActivity)) {
            if (luaContext instanceof LuaService) {
                luaState = this.f870b;
                str = "service";
            }
            this.f870b.pushJavaObject(this);
            this.f870b.setGlobal("this");
            this.f870b.pushContext(this.d);
            new LuaPrint(this.d, this.f870b).register("print");
            this.f870b.getGlobal("package");
            this.f870b.pushString(this.d.getLuaLpath());
            this.f870b.setField(-2, Config.FEED_LIST_ITEM_PATH);
            this.f870b.pushString(this.d.getLuaCpath());
            this.f870b.setField(-2, "cpath");
            this.f870b.pop(1);
            new JavaFunction(this.f870b) { // from class: com.androlua.LuaThread.2
                @Override // com.luajava.JavaFunction
                public int execute() {
                    LuaThread.this.d.set(this.f1170a.toString(2), this.f1170a.toJavaObject(3));
                    return 0;
                }
            }.register("set");
            new JavaFunction(this.f870b) { // from class: com.androlua.LuaThread.3
                @Override // com.luajava.JavaFunction
                public int execute() {
                    LuaContext luaContext2;
                    String string;
                    Object[] objArr;
                    int top = this.f1170a.getTop();
                    if (top <= 2) {
                        if (top == 2) {
                            luaContext2 = LuaThread.this.d;
                            string = this.f1170a.toString(2);
                            objArr = new Object[0];
                        }
                        return 0;
                    }
                    objArr = new Object[top - 2];
                    for (int i = 3; i <= top; i++) {
                        objArr[i - 3] = this.f1170a.toJavaObject(i);
                    }
                    luaContext2 = LuaThread.this.d;
                    string = this.f1170a.toString(2);
                    luaContext2.call(string, objArr);
                    return 0;
                }
            }.register("call");
        }
        luaState = this.f870b;
        str = "activity";
        luaState.setGlobal(str);
        this.f870b.pushJavaObject(this);
        this.f870b.setGlobal("this");
        this.f870b.pushContext(this.d);
        new LuaPrint(this.d, this.f870b).register("print");
        this.f870b.getGlobal("package");
        this.f870b.pushString(this.d.getLuaLpath());
        this.f870b.setField(-2, Config.FEED_LIST_ITEM_PATH);
        this.f870b.pushString(this.d.getLuaCpath());
        this.f870b.setField(-2, "cpath");
        this.f870b.pop(1);
        new JavaFunction(this.f870b) { // from class: com.androlua.LuaThread.2
            @Override // com.luajava.JavaFunction
            public int execute() {
                LuaThread.this.d.set(this.f1170a.toString(2), this.f1170a.toJavaObject(3));
                return 0;
            }
        }.register("set");
        new JavaFunction(this.f870b) { // from class: com.androlua.LuaThread.3
            @Override // com.luajava.JavaFunction
            public int execute() {
                LuaContext luaContext2;
                String string;
                Object[] objArr;
                int top = this.f1170a.getTop();
                if (top <= 2) {
                    if (top == 2) {
                        luaContext2 = LuaThread.this.d;
                        string = this.f1170a.toString(2);
                        objArr = new Object[0];
                    }
                    return 0;
                }
                objArr = new Object[top - 2];
                for (int i = 3; i <= top; i++) {
                    objArr[i - 3] = this.f1170a.toJavaObject(i);
                }
                luaContext2 = LuaThread.this.d;
                string = this.f1170a.toString(2);
                luaContext2.call(string, objArr);
                return 0;
            }
        }.register("call");
    }

    private void a(String str, Object obj) {
        try {
            this.f870b.pushObjectValue(obj);
            this.f870b.setGlobal(str);
        } catch (LuaException e) {
            this.d.sendError(toString(), e);
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private void a(String str, Object... objArr) throws LuaException {
        this.f870b.setTop(0);
        int iLloadFile = this.f870b.LloadFile(str);
        if (iLloadFile == 0) {
            this.f870b.getGlobal("debug");
            this.f870b.getField(-1, "traceback");
            this.f870b.remove(-2);
            this.f870b.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.f870b.pushObjectValue(obj);
            }
            iLloadFile = this.f870b.pcall(length, 0, (-2) - length);
            if (iLloadFile == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadFile) + ": " + this.f870b.toString(-1));
    }

    private void a(byte[] bArr, Object... objArr) {
        try {
            this.f870b.setTop(0);
            int iLloadBuffer = this.f870b.LloadBuffer(bArr, "TimerTask");
            if (iLloadBuffer == 0) {
                this.f870b.getGlobal("debug");
                this.f870b.getField(-1, "traceback");
                this.f870b.remove(-2);
                this.f870b.insert(-2);
                int length = objArr.length;
                for (Object obj : objArr) {
                    this.f870b.pushObjectValue(obj);
                }
                iLloadBuffer = this.f870b.pcall(length, 0, (-2) - length);
                if (iLloadBuffer == 0) {
                    return;
                }
            }
            throw new LuaException(a(iLloadBuffer) + ": " + this.f870b.toString(-1));
        } catch (Exception e) {
            this.d.sendError(toString(), e);
            quit();
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private void b(String str, Object... objArr) throws LuaException {
        this.f870b.setTop(0);
        int iLloadString = this.f870b.LloadString(str);
        if (iLloadString == 0) {
            this.f870b.getGlobal("debug");
            this.f870b.getField(-1, "traceback");
            this.f870b.remove(-2);
            this.f870b.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.f870b.pushObjectValue(obj);
            }
            iLloadString = this.f870b.pcall(length, 0, (-2) - length);
            if (iLloadString == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadString) + ": " + this.f870b.toString(-1));
    }

    private void c(String str, Object... objArr) {
        try {
            if (Pattern.matches("^\\w+$", str)) {
                doAsset(str + ".lua", objArr);
            } else if (Pattern.matches("^[\\w\\.\\_/]+$", str)) {
                this.f870b.getGlobal("luajava");
                this.f870b.pushString(this.d.getLuaDir());
                this.f870b.setField(-2, "luadir");
                this.f870b.pushString(str);
                this.f870b.setField(-2, "luapath");
                this.f870b.pop(1);
                a(str, objArr);
            } else {
                b(str, objArr);
            }
        } catch (Exception e) {
            this.d.sendError(toString(), e);
            quit();
        }
    }

    private void d(String str, Object... objArr) {
        try {
            this.f870b.setTop(0);
            this.f870b.getGlobal(str);
            if (this.f870b.isFunction(-1)) {
                this.f870b.getGlobal("debug");
                this.f870b.getField(-1, "traceback");
                this.f870b.remove(-2);
                this.f870b.insert(-2);
                int length = objArr.length;
                for (Object obj : objArr) {
                    this.f870b.pushObjectValue(obj);
                }
                int iPcall = this.f870b.pcall(length, 1, (-2) - length);
                if (iPcall == 0) {
                    return;
                }
                throw new LuaException(a(iPcall) + ": " + this.f870b.toString(-1));
            }
        } catch (LuaException e) {
            this.d.sendError(toString() + " " + str, e);
        }
    }

    @Override // com.luajava.LuaMetaTable
    public Object __call(Object[] objArr) {
        return null;
    }

    @Override // com.luajava.LuaMetaTable
    public Object __index(final String str) {
        return new LuaMetaTable() { // from class: com.androlua.LuaThread.1
            @Override // com.luajava.LuaMetaTable
            public Object __call(Object[] objArr) {
                LuaThread.this.call(str, objArr);
                return null;
            }

            @Override // com.luajava.LuaMetaTable
            public Object __index(String str2) {
                return null;
            }

            @Override // com.luajava.LuaMetaTable
            public void __newIndex(String str2, Object obj) {
            }
        };
    }

    @Override // com.luajava.LuaMetaTable
    public void __newIndex(String str, Object obj) {
        set(str, obj);
    }

    public void call(String str) {
        push(3, str);
    }

    public void call(String str, Object[] objArr) {
        if (objArr.length == 0) {
            push(3, str);
        } else {
            push(1, str, objArr);
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public void doAsset(String str, Object... objArr) throws LuaException, IOException {
        byte[] asset = LuaUtil.readAsset(this.d.getContext(), str);
        this.f870b.setTop(0);
        int iLloadBuffer = this.f870b.LloadBuffer(asset, str);
        if (iLloadBuffer == 0) {
            this.f870b.getGlobal("debug");
            this.f870b.getField(-1, "traceback");
            this.f870b.remove(-2);
            this.f870b.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.f870b.pushObjectValue(obj);
            }
            iLloadBuffer = this.f870b.pcall(length, 0, (-2) - length);
            if (iLloadBuffer == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadBuffer) + ": " + this.f870b.toString(-1));
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        quit();
        this.f869a = true;
    }

    public Object get(String str) {
        this.f870b.getGlobal(str);
        return this.f870b.toJavaObject(-1);
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.f869a;
    }

    public void push(int i, String str) {
        if (!this.isRun) {
            this.d.sendMsg("thread is not running");
            return;
        }
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        message.setData(bundle);
        message.what = i;
        this.f871c.sendMessage(message);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void push(int i, String str, Object[] objArr) {
        if (!this.isRun) {
            this.d.sendMsg("thread is not running");
            return;
        }
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        bundle.putSerializable("args", objArr);
        message.setData(bundle);
        message.what = i;
        this.f871c.sendMessage(message);
    }

    public void quit() {
        if (this.isRun) {
            this.isRun = false;
            this.f871c.getLooper().quit();
        }
    }

    @Override // java.lang.Thread, java.lang.Runnable
    public void run() {
        try {
            if (this.f870b == null) {
                a();
                if (this.h != null) {
                    a(this.h, this.g);
                } else {
                    c(this.f, this.g);
                }
            }
            if (this.e) {
                Looper.prepare();
                this.f871c = new ThreadHandler();
                this.isRun = true;
                this.f870b.getGlobal("run");
                if (!this.f870b.isNil(-1)) {
                    this.f870b.pop(1);
                    d("run", new Object[0]);
                }
                Looper.loop();
            }
            this.isRun = false;
            this.f870b.gc(2, 1);
            System.gc();
        } catch (LuaException e) {
            this.d.sendError(toString(), e);
        }
    }

    public void set(String str, Object obj) {
        push(4, str, new Object[]{obj});
    }
}