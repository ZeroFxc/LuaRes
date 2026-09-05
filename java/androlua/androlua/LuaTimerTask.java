package com.androlua;

import com.androlua.util.TimerTaskX;
import com.baidu.mobstat.Config;
import com.luajava.JavaFunction;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import java.io.IOException;
import java.util.regex.Pattern;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaTimerTask extends TimerTaskX {
    private LuaState h;
    private LuaContext i;
    private String j;
    private Object[] k;
    private boolean l;
    private byte[] m;

    public LuaTimerTask(LuaContext luaContext, LuaObject luaObject) {
        this(luaContext, luaObject, (Object[]) null);
    }

    public LuaTimerTask(LuaContext luaContext, LuaObject luaObject, Object[] objArr) {
        this.k = new Object[0];
        this.l = true;
        this.i = luaContext;
        if (objArr != null) {
            this.k = objArr;
        }
        this.m = luaObject.dump();
    }

    public LuaTimerTask(LuaContext luaContext, String str) {
        this(luaContext, str, (Object[]) null);
    }

    public LuaTimerTask(LuaContext luaContext, String str, Object[] objArr) {
        this.k = new Object[0];
        this.l = true;
        this.i = luaContext;
        this.j = str;
        if (objArr != null) {
            this.k = objArr;
        }
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

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private void a(String str, Object... objArr) throws LuaException {
        this.h.setTop(0);
        int iLloadFile = this.h.LloadFile(str);
        if (iLloadFile == 0) {
            this.h.getGlobal("debug");
            this.h.getField(-1, "traceback");
            this.h.remove(-2);
            this.h.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.h.pushObjectValue(obj);
            }
            iLloadFile = this.h.pcall(length, 0, (-2) - length);
            if (iLloadFile == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadFile) + ": " + this.h.toString(-1));
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private void a(byte[] bArr, Object... objArr) throws LuaException {
        this.h.setTop(0);
        int iLloadBuffer = this.h.LloadBuffer(bArr, "TimerTask");
        if (iLloadBuffer == 0) {
            this.h.getGlobal("debug");
            this.h.getField(-1, "traceback");
            this.h.remove(-2);
            this.h.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.h.pushObjectValue(obj);
            }
            iLloadBuffer = this.h.pcall(length, 0, (-2) - length);
            if (iLloadBuffer == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadBuffer) + ": " + this.h.toString(-1));
    }

    private void b() {
        LuaState luaState;
        String str;
        this.h = LuaStateFactory.newLuaState();
        this.h.openLibs();
        this.h.pushJavaObject(this.i);
        LuaContext luaContext = this.i;
        if (!(luaContext instanceof LuaActivity)) {
            if (luaContext instanceof LuaService) {
                luaState = this.h;
                str = "service";
            }
            this.h.pushJavaObject(this);
            this.h.setGlobal("this");
            this.h.pushContext(this.i);
            new LuaPrint(this.i, this.h).register("print");
            this.h.getGlobal("package");
            this.h.pushString(this.i.getLuaLpath());
            this.h.setField(-2, Config.FEED_LIST_ITEM_PATH);
            this.h.pushString(this.i.getLuaCpath());
            this.h.setField(-2, "cpath");
            this.h.pop(1);
            new JavaFunction(this.h) { // from class: com.androlua.LuaTimerTask.1
                @Override // com.luajava.JavaFunction
                public int execute() {
                    LuaTimerTask.this.i.set(this.f1170a.toString(2), this.f1170a.toJavaObject(3));
                    return 0;
                }
            }.register("set");
            new JavaFunction(this.h) { // from class: com.androlua.LuaTimerTask.2
                @Override // com.luajava.JavaFunction
                public int execute() {
                    LuaContext luaContext2;
                    String string;
                    Object[] objArr;
                    int top = this.f1170a.getTop();
                    if (top <= 2) {
                        if (top == 2) {
                            luaContext2 = LuaTimerTask.this.i;
                            string = this.f1170a.toString(2);
                            objArr = new Object[0];
                        }
                        return 0;
                    }
                    objArr = new Object[top - 2];
                    for (int i = 3; i <= top; i++) {
                        objArr[i - 3] = this.f1170a.toJavaObject(i);
                    }
                    luaContext2 = LuaTimerTask.this.i;
                    string = this.f1170a.toString(2);
                    luaContext2.call(string, objArr);
                    return 0;
                }
            }.register("call");
        }
        luaState = this.h;
        str = "activity";
        luaState.setGlobal(str);
        this.h.pushJavaObject(this);
        this.h.setGlobal("this");
        this.h.pushContext(this.i);
        new LuaPrint(this.i, this.h).register("print");
        this.h.getGlobal("package");
        this.h.pushString(this.i.getLuaLpath());
        this.h.setField(-2, Config.FEED_LIST_ITEM_PATH);
        this.h.pushString(this.i.getLuaCpath());
        this.h.setField(-2, "cpath");
        this.h.pop(1);
        new JavaFunction(this.h) { // from class: com.androlua.LuaTimerTask.1
            @Override // com.luajava.JavaFunction
            public int execute() {
                LuaTimerTask.this.i.set(this.f1170a.toString(2), this.f1170a.toJavaObject(3));
                return 0;
            }
        }.register("set");
        new JavaFunction(this.h) { // from class: com.androlua.LuaTimerTask.2
            @Override // com.luajava.JavaFunction
            public int execute() {
                LuaContext luaContext2;
                String string;
                Object[] objArr;
                int top = this.f1170a.getTop();
                if (top <= 2) {
                    if (top == 2) {
                        luaContext2 = LuaTimerTask.this.i;
                        string = this.f1170a.toString(2);
                        objArr = new Object[0];
                    }
                    return 0;
                }
                objArr = new Object[top - 2];
                for (int i = 3; i <= top; i++) {
                    objArr[i - 3] = this.f1170a.toJavaObject(i);
                }
                luaContext2 = LuaTimerTask.this.i;
                string = this.f1170a.toString(2);
                luaContext2.call(string, objArr);
                return 0;
            }
        }.register("call");
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private void b(String str, Object... objArr) throws LuaException {
        this.h.setTop(0);
        int iLloadString = this.h.LloadString(str);
        if (iLloadString == 0) {
            this.h.getGlobal("debug");
            this.h.getField(-1, "traceback");
            this.h.remove(-2);
            this.h.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.h.pushObjectValue(obj);
            }
            iLloadString = this.h.pcall(length, 0, (-2) - length);
            if (iLloadString == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadString) + ": " + this.h.toString(-1));
    }

    private void c(String str, Object... objArr) {
        try {
            if (Pattern.matches("^\\w+$", str)) {
                doAsset(str + ".lua", objArr);
            } else if (Pattern.matches("^[\\w\\.\\_/]+$", str)) {
                this.h.getGlobal("luajava");
                this.h.pushString(this.i.getLuaDir());
                this.h.setField(-2, "luadir");
                this.h.pushString(str);
                this.h.setField(-2, "luapath");
                this.h.pop(1);
                a(str, objArr);
            } else {
                b(str, objArr);
            }
        } catch (Exception e) {
            this.i.sendError(toString(), e);
        }
    }

    private void d(String str, Object... objArr) {
        try {
            this.h.setTop(0);
            this.h.getGlobal(str);
            if (this.h.isFunction(-1)) {
                this.h.getGlobal("debug");
                this.h.getField(-1, "traceback");
                this.h.remove(-2);
                this.h.insert(-2);
                int length = objArr.length;
                for (Object obj : objArr) {
                    this.h.pushObjectValue(obj);
                }
                int iPcall = this.h.pcall(length, 1, (-2) - length);
                if (iPcall == 0) {
                    return;
                }
                throw new LuaException(a(iPcall) + ": " + this.h.toString(-1));
            }
        } catch (LuaException e) {
            this.i.sendError(toString() + " " + str, e);
        }
    }

    @Override // com.androlua.util.TimerTaskX
    public boolean cancel() {
        return super.cancel();
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public void doAsset(String str, Object... objArr) throws LuaException, IOException {
        byte[] asset = LuaUtil.readAsset(this.i.getContext(), str);
        this.h.setTop(0);
        int iLloadBuffer = this.h.LloadBuffer(asset, str);
        if (iLloadBuffer == 0) {
            this.h.getGlobal("debug");
            this.h.getField(-1, "traceback");
            this.h.remove(-2);
            this.h.insert(-2);
            int length = objArr.length;
            for (Object obj : objArr) {
                this.h.pushObjectValue(obj);
            }
            iLloadBuffer = this.h.pcall(length, 0, (-2) - length);
            if (iLloadBuffer == 0) {
                return;
            }
        }
        throw new LuaException(a(iLloadBuffer) + ": " + this.h.toString(-1));
    }

    public Object get(String str) {
        this.h.getGlobal(str);
        return this.h.toJavaObject(-1);
    }

    @Override // com.androlua.util.TimerTaskX
    public boolean isEnabled() {
        return this.l;
    }

    @Override // com.androlua.util.TimerTaskX, java.lang.Runnable
    public void run() {
        String str;
        Object[] objArr;
        byte[] bArr;
        Object[] objArr2;
        if (this.l) {
            try {
                if (this.h == null) {
                    b();
                    if (this.m != null) {
                        bArr = this.m;
                        objArr2 = this.k;
                        a(bArr, objArr2);
                    } else {
                        str = this.j;
                        objArr = this.k;
                        c(str, objArr);
                    }
                } else {
                    this.h.getGlobal("run");
                    if (!this.h.isNil(-1)) {
                        d("run", new Object[0]);
                    } else if (this.m != null) {
                        bArr = this.m;
                        objArr2 = this.k;
                        a(bArr, objArr2);
                    } else {
                        str = this.j;
                        objArr = this.k;
                        c(str, objArr);
                    }
                }
            } catch (LuaException e) {
                this.i.sendError(toString(), e);
            }
            this.h.gc(2, 1);
            System.gc();
        }
    }

    public void set(String str, Object obj) {
        this.h.pushObjectValue(obj);
        this.h.setGlobal(str);
    }

    public void setArg(LuaObject luaObject) {
        this.k = luaObject.asArray();
    }

    public void setArg(Object[] objArr) {
        this.k = objArr;
    }

    @Override // com.androlua.util.TimerTaskX
    public void setEnabled(boolean z) {
        this.l = z;
    }
}