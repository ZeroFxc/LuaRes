package com.luajava;

import com.androlua.BuildConfig;
import java.io.Serializable;
import java.lang.reflect.Array;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;
import java.util.StringTokenizer;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaObject implements Serializable {
    protected int a;
    protected final LuaState b;

    protected LuaObject(LuaObject luaObject, LuaObject luaObject2) throws LuaException {
        if (luaObject.getLuaState() != luaObject2.getLuaState()) {
            throw new LuaException("LuaStates must be the same!");
        }
        synchronized (luaObject.getLuaState()) {
            if (!luaObject.isTable() && !luaObject.isUserdata()) {
                throw new LuaException("Object parent should be a table or userdata .");
            }
            this.b = luaObject.getLuaState();
            luaObject.push();
            luaObject2.push();
            this.b.getTable(-2);
            this.b.remove(-2);
            a(-1);
            this.b.pop(1);
        }
    }

    protected LuaObject(LuaObject luaObject, Number number) {
        synchronized (luaObject.getLuaState()) {
            this.b = luaObject.getLuaState();
            if (!luaObject.isTable() && !luaObject.isUserdata()) {
                throw new LuaException("Object parent should be a table or userdata .");
            }
            luaObject.push();
            this.b.pushNumber(number.doubleValue());
            this.b.getTable(-2);
            this.b.remove(-2);
            a(-1);
            this.b.pop(1);
        }
    }

    protected LuaObject(LuaObject luaObject, String str) {
        synchronized (luaObject.getLuaState()) {
            this.b = luaObject.getLuaState();
            if (!luaObject.isTable() && !luaObject.isUserdata()) {
                throw new LuaException("Object parent should be a table or userdata .");
            }
            luaObject.push();
            this.b.pushString(str);
            this.b.getTable(-2);
            this.b.remove(-2);
            a(-1);
            this.b.pop(1);
        }
    }

    protected LuaObject(LuaState luaState) {
        this.b = luaState;
    }

    protected LuaObject(LuaState luaState, int i) {
        synchronized (luaState) {
            this.b = luaState;
            a(i);
        }
    }

    protected LuaObject(LuaState luaState, String str) {
        synchronized (luaState) {
            this.b = luaState;
            luaState.getGlobal(str);
            a(-1);
            luaState.pop(1);
        }
    }

    public LuaObject _call(Object... objArr) {
        return _call_aux(objArr, 1)[0];
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public LuaObject[] _call_aux(Object[] objArr, int i) {
        int i2;
        LuaObject[] luaObjectArr;
        String string;
        StringBuilder sb;
        String string2;
        synchronized (this.b) {
            if (!isFunction() && !isTable() && !isUserdata()) {
                throw new LuaException("Invalid object. Not a function, table or userdata .");
            }
            int top = this.b.getTop();
            push();
            if (objArr != null) {
                for (Object obj : objArr) {
                    this.b.pushObjectValue(obj);
                }
            } else {
                i2 = 0;
            }
            int iPcall = this.b.pcall(i2, i, 0);
            if (iPcall != 0) {
                if (this.b.isString(-1)) {
                    string = this.b.toString(-1);
                    this.b.pop(1);
                } else {
                    string = BuildConfig.FLAVOR;
                }
                if (iPcall == 2) {
                    sb = new StringBuilder();
                    sb.append("Runtime error. ");
                    sb.append(string);
                } else if (iPcall == 4) {
                    sb = new StringBuilder();
                    sb.append("Memory allocation error. ");
                    sb.append(string);
                } else {
                    if (iPcall != 6) {
                        string2 = "Lua Error code " + iPcall + ". " + string;
                        throw new LuaException(string2);
                    }
                    sb = new StringBuilder();
                    sb.append("Error while running the error handler function. ");
                    sb.append(string);
                }
                string2 = sb.toString();
                throw new LuaException(string2);
            }
            if (i == -1) {
                i = this.b.getTop() - top;
            }
            if (this.b.getTop() - top < i) {
                throw new LuaException("Invalid Number of Results .");
            }
            luaObjectArr = new LuaObject[i];
            while (i > 0) {
                luaObjectArr[i - 1] = this.b.getLuaObject(-1);
                this.b.pop(1);
                i--;
            }
        }
        return luaObjectArr;
    }

    protected void a(int i) {
        synchronized (this.b) {
            this.b.pushValue(i);
            this.a = this.b.Lref(LuaState.LUA_REGISTRYINDEX);
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public Object[] asArray() {
        Object[] objArr;
        synchronized (this.b) {
            if (!isTable()) {
                throw new LuaException("Invalid object. Not a table .");
            }
            push();
            int iObjLen = this.b.objLen(-1);
            Object objNewInstance = Array.newInstance((Class<?>) Object.class, iObjLen);
            for (int i = 1; i <= iObjLen; i++) {
                this.b.pushInteger(i);
                this.b.getTable(-2);
                try {
                    Array.set(objNewInstance, i - 1, this.b.toJavaObject(-1));
                } catch (LuaException unused) {
                }
                this.b.pop(1);
            }
            this.b.pop(1);
            objArr = (Object[]) objNewInstance;
        }
        return objArr;
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public Map asMap(LuaState luaState, Class<?> cls, int i) {
        HashMap map;
        synchronized (luaState) {
            if (!isTable()) {
                throw new LuaException("Invalid object. Not a table .");
            }
            map = new HashMap();
            push();
            luaState.pushNil();
            while (luaState.next(i) != 0) {
                try {
                    map.put(luaState.toJavaObject(-2), luaState.toJavaObject(-1));
                } catch (LuaException unused) {
                }
                luaState.pop(1);
            }
            luaState.pop(1);
        }
        return map;
    }

    public Object call(Object... objArr) {
        return call_aux(objArr, 1)[0];
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public Object[] call_aux(Object[] objArr, int i) {
        Object[] objArr2;
        String string;
        StringBuilder sb;
        String string2;
        synchronized (this.b) {
            if (!isFunction() && !isTable() && !isUserdata()) {
                throw new LuaException("Invalid object. Not a function, table or userdata .");
            }
            int top = this.b.getTop();
            push();
            this.b.getGlobal("debug");
            this.b.getField(-1, "traceback");
            this.b.remove(-2);
            this.b.insert(-2);
            int i2 = 0;
            if (objArr != null) {
                int length = objArr.length;
                while (i2 < length) {
                    this.b.pushObjectValue(objArr[i2]);
                    i2++;
                }
                i2 = length;
            }
            int iPcall = this.b.pcall(i2, i, (-2) - i2);
            if (iPcall != 0) {
                if (this.b.isString(-1)) {
                    string = this.b.toString(-1);
                    this.b.pop(1);
                } else {
                    string = BuildConfig.FLAVOR;
                }
                if (iPcall == 2) {
                    sb = new StringBuilder();
                    sb.append("Runtime error. ");
                    sb.append(string);
                } else if (iPcall == 4) {
                    sb = new StringBuilder();
                    sb.append("Memory allocation error. ");
                    sb.append(string);
                } else {
                    if (iPcall != 6) {
                        string2 = "Lua Error code " + iPcall + ". " + string;
                        throw new LuaException(string2);
                    }
                    sb = new StringBuilder();
                    sb.append("Error while running the error handler function. ");
                    sb.append(string);
                }
                string2 = sb.toString();
                throw new LuaException(string2);
            }
            if (i == -1) {
                i = this.b.getTop() - top;
            }
            if (this.b.getTop() - top < i) {
                throw new LuaException("Invalid Number of Results .");
            }
            objArr2 = new Object[i];
            while (i > 0) {
                objArr2[i - 1] = this.b.toJavaObject(-1);
                this.b.pop(1);
                i--;
            }
        }
        return objArr2;
    }

    public Object createProxy(Class cls) {
        Object objNewProxyInstance;
        synchronized (this.b) {
            if (!isTable() && !isFunction()) {
                throw new LuaException("Invalid Object. Must be Table or Function.");
            }
            if (isFunction() && cls.getMethods().length != 1) {
                throw new LuaException("Invalid Object. Must be a interface Method of Function.");
            }
            if (isTable() && getTable().isList()) {
                throw new LuaException("Invalid Object. Must be Table is Not Array.");
            }
            objNewProxyInstance = Proxy.newProxyInstance(cls.getClassLoader(), new Class[]{cls}, new LuaInvocationHandler(this));
        }
        return objNewProxyInstance;
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public Object createProxy(String str) {
        Object objNewProxyInstance;
        synchronized (this.b) {
            if (!isTable()) {
                throw new LuaException("Invalid Object. Must be Table.");
            }
            StringTokenizer stringTokenizer = new StringTokenizer(str, ",");
            Class[] clsArr = new Class[stringTokenizer.countTokens()];
            int i = 0;
            while (stringTokenizer.hasMoreTokens()) {
                clsArr[i] = Class.forName(stringTokenizer.nextToken());
                i++;
            }
            objNewProxyInstance = Proxy.newProxyInstance(getClass().getClassLoader(), clsArr, new LuaInvocationHandler(this));
        }
        return objNewProxyInstance;
    }

    public byte[] dump() {
        byte[] bArrDump;
        synchronized (this.b) {
            if (!isFunction()) {
                throw new LuaException("Invalid object. Not a function .");
            }
            push();
            bArrDump = this.b.dump(-1);
            this.b.pop(1);
        }
        return bArrDump;
    }

    protected void finalize() {
        try {
            synchronized (this.b) {
                if (this.b.getPointer() != 0) {
                    this.b.LunRef(LuaState.LUA_REGISTRYINDEX, this.a);
                }
            }
        } catch (Throwable unused) {
            System.err.println("Unable to release object " + this.a);
        }
    }

    public boolean getBoolean() {
        boolean z;
        synchronized (this.b) {
            push();
            z = this.b.toBoolean(-1);
            this.b.pop(1);
        }
        return z;
    }

    public LuaObject getField(String str) {
        return this.b.getLuaObject(this, str);
    }

    public LuaFunction<?> getFunction() {
        LuaFunction<?> luaFunction;
        synchronized (this.b) {
            push();
            luaFunction = new LuaFunction<>(this.b, -1);
            this.b.pop(1);
        }
        return luaFunction;
    }

    public LuaObject getI(long j) {
        return this.b.getLuaObject(this, Long.valueOf(j));
    }

    public long getInteger() {
        long integer;
        synchronized (this.b) {
            push();
            integer = this.b.toInteger(-1);
            this.b.pop(1);
        }
        return integer;
    }

    public LuaState getLuaState() {
        return this.b;
    }

    public double getNumber() {
        double number;
        synchronized (this.b) {
            push();
            number = this.b.toNumber(-1);
            this.b.pop(1);
        }
        return number;
    }

    public Object getObject() {
        Object objectFromUserdata;
        synchronized (this.b) {
            push();
            objectFromUserdata = this.b.getObjectFromUserdata(-1);
            this.b.pop(1);
        }
        return objectFromUserdata;
    }

    public String getString() {
        String string;
        synchronized (this.b) {
            push();
            string = this.b.toString(-1);
            this.b.pop(1);
        }
        return string;
    }

    public LuaTable<?, ?> getTable() {
        LuaTable<?, ?> luaTable;
        synchronized (this.b) {
            push();
            luaTable = new LuaTable<>(this.b, -1);
            this.b.pop(1);
        }
        return luaTable;
    }

    public boolean isBoolean() {
        boolean zIsBoolean;
        synchronized (this.b) {
            push();
            zIsBoolean = this.b.isBoolean(-1);
            this.b.pop(1);
        }
        return zIsBoolean;
    }

    public boolean isFunction() {
        boolean zIsFunction;
        synchronized (this.b) {
            push();
            zIsFunction = this.b.isFunction(-1);
            this.b.pop(1);
        }
        return zIsFunction;
    }

    public boolean isInteger() {
        boolean zIsInteger;
        synchronized (this.b) {
            push();
            zIsInteger = this.b.isInteger(-1);
            this.b.pop(1);
        }
        return zIsInteger;
    }

    public boolean isJavaFunction() {
        boolean zIsJavaFunction;
        synchronized (this.b) {
            push();
            zIsJavaFunction = this.b.isJavaFunction(-1);
            this.b.pop(1);
        }
        return zIsJavaFunction;
    }

    public boolean isJavaObject() {
        boolean zIsObject;
        synchronized (this.b) {
            push();
            zIsObject = this.b.isObject(-1);
            this.b.pop(1);
        }
        return zIsObject;
    }

    public boolean isNil() {
        boolean zIsNil;
        synchronized (this.b) {
            push();
            zIsNil = this.b.isNil(-1);
            this.b.pop(1);
        }
        return zIsNil;
    }

    public boolean isNumber() {
        boolean zIsNumber;
        synchronized (this.b) {
            push();
            zIsNumber = this.b.isNumber(-1);
            this.b.pop(1);
        }
        return zIsNumber;
    }

    public boolean isString() {
        boolean zIsString;
        synchronized (this.b) {
            push();
            zIsString = this.b.isString(-1);
            this.b.pop(1);
        }
        return zIsString;
    }

    public boolean isTable() {
        boolean zIsTable;
        synchronized (this.b) {
            push();
            zIsTable = this.b.isTable(-1);
            this.b.pop(1);
        }
        return zIsTable;
    }

    public boolean isUserdata() {
        boolean zIsUserdata;
        synchronized (this.b) {
            push();
            zIsUserdata = this.b.isUserdata(-1);
            this.b.pop(1);
        }
        return zIsUserdata;
    }

    public void pop() {
        this.b.pop(1);
    }

    public void push() {
        this.b.rawGetI(LuaState.LUA_REGISTRYINDEX, this.a);
    }

    public void setField(String str, Object obj) {
        push();
        try {
            this.b.pushObjectValue(obj);
        } catch (LuaException unused) {
            this.b.pushNil();
        }
        this.b.setField(-2, str);
        this.b.pop(1);
    }

    public void setI(long j, Object obj) {
        push();
        try {
            this.b.pushObjectValue(obj);
        } catch (LuaException unused) {
            this.b.pushNil();
        }
        this.b.setI(-2, j);
        this.b.pop(1);
    }

    public String toString() {
        synchronized (this.b) {
            try {
                try {
                    if (isNil()) {
                        return "nil";
                    }
                    if (isBoolean()) {
                        return String.valueOf(getBoolean());
                    }
                    if (isNumber()) {
                        return String.valueOf(getNumber());
                    }
                    if (isString()) {
                        return getString();
                    }
                    if (isFunction()) {
                        return "Lua Function";
                    }
                    if (isJavaObject()) {
                        return getObject().toString();
                    }
                    if (isUserdata()) {
                        return "Userdata";
                    }
                    if (isTable()) {
                        return "Lua Table";
                    }
                    if (isJavaFunction()) {
                        return "Java Function";
                    }
                    return null;
                } catch (LuaException unused) {
                    return null;
                }
            } catch (Throwable th) {
                throw th;
            }
        }
    }

    public int type() {
        int iType;
        synchronized (this.b) {
            push();
            iType = this.b.type(-1);
            this.b.pop(1);
        }
        return iType;
    }
}