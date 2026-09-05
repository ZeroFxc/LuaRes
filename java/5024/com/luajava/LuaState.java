package com.luajava;

import android.annotation.SuppressLint;
import android.util.Log;
import com.androlua.LuaContext;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Pattern;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaState {
    public static final int LUAI_MAXSTACK = 1000000;
    public static final int LUA_ERRERR = 6;
    public static final int LUA_ERRGCMM = 5;
    public static final int LUA_ERRMEM = 4;
    public static final int LUA_ERRRUN = 2;
    public static final int LUA_ERRSYNTAX = 3;
    public static final int LUA_GCCOLLECT = 2;
    public static final int LUA_GCCOUNT = 3;
    public static final int LUA_GCCOUNTB = 4;
    public static final int LUA_GCRESTART = 1;
    public static final int LUA_GCSETPAUSE = 6;
    public static final int LUA_GCSETSTEPMUL = 7;
    public static final int LUA_GCSTEP = 5;
    public static final int LUA_GCSTOP = 0;
    public static final int LUA_MULTRET = -1;
    public static final int LUA_OPEQ = 0;
    public static final int LUA_OPLE = 2;
    public static final int LUA_OPLT = 1;
    public static final int LUA_REGISTRYINDEX = -1001000;
    public static final int LUA_RIDX_GLOBALS = 2;
    public static final int LUA_RIDX_LAST = 2;
    public static final int LUA_RIDX_MAINTHREAD = 1;
    public static final int LUA_TBOOLEAN = 1;
    public static final int LUA_TFUNCTION = 6;
    public static final int LUA_TINTEGER = 9;
    public static final int LUA_TLIGHTUSERDATA = 2;
    public static final int LUA_TNIL = 0;
    public static final int LUA_TNONE = -1;
    public static final int LUA_TNUMBER = 3;
    public static final int LUA_TSTRING = 4;
    public static final int LUA_TTABLE = 5;
    public static final int LUA_TTHREAD = 8;
    public static final int LUA_TUSERDATA = 7;
    public static final int LUA_YIELD = 1;
    private static AtomicInteger a;
    private static final AtomicInteger b;
    private static final ArrayList<Integer> c;

    @SuppressLint({"UseSparseArrays"})
    public static final HashMap<Integer, Object> javaObjectMap;
    private long d;
    private LuaContext e;

    static {
        System.loadLibrary("luajava");
        a = new AtomicInteger();
        b = new AtomicInteger();
        javaObjectMap = new HashMap<>();
        c = new ArrayList<>();
    }

    protected LuaState() {
        this.d = _newstate();
    }

    protected LuaState(long j) {
        this.d = j;
        LuaStateFactory.insertLuaState(this);
    }

    private native synchronized int _LargError(long j, int i, String str);

    private native synchronized int _LcallMeta(long j, int i, String str);

    private native synchronized void _LcheckAny(long j, int i);

    private native synchronized int _LcheckInteger(long j, int i);

    private native synchronized double _LcheckNumber(long j, int i);

    private native synchronized void _LcheckStack(long j, int i, String str);

    private native synchronized String _LcheckString(long j, int i);

    private native synchronized void _LcheckType(long j, int i, int i2);

    private native synchronized int _LdoFile(long j, String str);

    private native synchronized int _LdoString(long j, String str);

    private native synchronized int _LgetMetaField(long j, int i, String str);

    private native synchronized void _LgetMetatable(long j, String str);

    private native synchronized String _Lgsub(long j, String str, String str2, String str3);

    private native synchronized int _LloadBuffer(long j, byte[] bArr, long j2, String str);

    private native synchronized int _LloadFile(long j, String str);

    private native synchronized int _LloadString(long j, String str);

    private native synchronized int _LnewMetatable(long j, String str);

    private native synchronized int _LoptInteger(long j, int i, int i2);

    private native synchronized double _LoptNumber(long j, int i, double d);

    private native synchronized String _LoptString(long j, int i, String str);

    private native synchronized int _Lref(long j, int i);

    private native synchronized byte[] _LtoString(long j, int i);

    private native synchronized void _LunRef(long j, int i, int i2);

    private native synchronized void _Lwhere(long j, int i);

    private native synchronized void _call(long j, int i, int i2);

    private native synchronized int _checkStack(long j, int i);

    private native synchronized void _close(long j);

    private native synchronized int _compare(long j, int i, int i2, int i3);

    private native synchronized void _concat(long j, int i);

    private native synchronized void _copy(long j, int i, int i2);

    private native synchronized void _createTable(long j, int i, int i2);

    private native synchronized byte[] _dump(long j, int i);

    private native synchronized int _equal(long j, int i, int i2);

    private native synchronized int _error(long j);

    private native synchronized int _gc(long j, int i, int i2);

    private native synchronized int _getField(long j, int i, String str);

    private native synchronized int _getGlobal(long j, String str);

    private native synchronized int _getI(long j, int i, long j2);

    private native synchronized int _getMetaTable(long j, int i);

    private native synchronized int _getObjectFromUserdata(long j, int i);

    private native synchronized int _getTable(long j, int i);

    private native synchronized int _getTop(long j);

    private native synchronized String _getUpValue(long j, int i, int i2);

    private native synchronized int _getUserValue(long j, int i);

    private native synchronized void _insert(long j, int i);

    private native synchronized int _isBoolean(long j, int i);

    private native synchronized int _isCFunction(long j, int i);

    private native synchronized int _isFunction(long j, int i);

    private native synchronized int _isInteger(long j, int i);

    private native synchronized boolean _isJavaFunction(long j, int i);

    private native synchronized int _isNil(long j, int i);

    private native synchronized int _isNone(long j, int i);

    private native synchronized int _isNoneOrNil(long j, int i);

    private native synchronized int _isNumber(long j, int i);

    private native synchronized boolean _isObject(long j, int i);

    private native synchronized int _isString(long j, int i);

    private native synchronized int _isTable(long j, int i);

    private native synchronized int _isThread(long j, int i);

    private native synchronized int _isUserdata(long j, int i);

    private native synchronized int _isYieldable(long j);

    private native synchronized int _lessThan(long j, int i, int i2);

    private native synchronized void _newTable(long j);

    private native synchronized long _newstate();

    private native synchronized long _newthread(long j);

    private native synchronized int _next(long j, int i);

    private native synchronized int _objlen(long j, int i);

    private native synchronized void _openBase(long j);

    private native synchronized void _openDebug(long j);

    private native synchronized void _openIo(long j);

    private native synchronized void _openLibs(long j);

    private native synchronized void _openLuajava(long j);

    private native synchronized void _openMath(long j);

    private native synchronized void _openOs(long j);

    private native synchronized void _openPackage(long j);

    private native synchronized void _openString(long j);

    private native synchronized void _openTable(long j);

    private native synchronized int _pcall(long j, int i, int i2, int i3);

    private native synchronized void _pop(long j, int i);

    private native synchronized void _pushBoolean(long j, int i);

    private native synchronized void _pushGlobalTable(long j);

    private native synchronized void _pushInteger(long j, long j2);

    private native synchronized void _pushJavaFunction(long j, JavaFunction javaFunction);

    private native synchronized void _pushJavaObject(long j, String str, int i, boolean z);

    private native synchronized void _pushLString(long j, byte[] bArr, int i);

    private native synchronized void _pushNil(long j);

    private native synchronized void _pushNumber(long j, double d);

    private native synchronized void _pushString(long j, String str);

    private native synchronized void _pushValue(long j, int i);

    private native synchronized int _rawGet(long j, int i);

    private native synchronized int _rawGetI(long j, int i, long j2);

    private native synchronized void _rawSet(long j, int i);

    private native synchronized void _rawSetI(long j, int i, long j2);

    private native synchronized int _rawequal(long j, int i, int i2);

    private native synchronized int _rawlen(long j, int i);

    private native synchronized void _remove(long j, int i);

    private native synchronized void _replace(long j, int i);

    private native synchronized int _resume(long j, long j2, int i);

    private native synchronized void _rotate(long j, int i, int i2);

    private native synchronized void _setField(long j, int i, String str);

    private native synchronized void _setGlobal(long j, String str);

    private native synchronized void _setI(long j, int i, long j2);

    private native synchronized int _setMetaTable(long j, int i);

    private native synchronized void _setTable(long j, int i);

    private native synchronized void _setTop(long j, int i);

    private native synchronized String _setUpValue(long j, int i, int i2);

    private native synchronized void _setUserValue(long j, int i);

    private native synchronized int _status(long j);

    private native synchronized int _strlen(long j, int i);

    private native synchronized int _toBoolean(long j, int i);

    private native synchronized byte[] _toBuffer(long j, int i);

    private native synchronized long _toInteger(long j, int i);

    private native synchronized double _toNumber(long j, int i);

    private native synchronized byte[] _toString(long j, int i);

    private native synchronized long _toThread(long j, int i);

    private native synchronized int _type(long j, int i);

    private native synchronized String _typeName(long j, int i);

    private native synchronized void _xmove(long j, long j2, int i);

    private native synchronized int _yield(long j, int i);

    public static Number convertLuaNumber(Double d, Class<?> cls) {
        if (cls.isPrimitive()) {
            if (cls == Integer.TYPE) {
                return Integer.valueOf(d.intValue());
            }
            if (cls == Long.TYPE) {
                return Long.valueOf(d.longValue());
            }
            if (cls == Float.TYPE) {
                return Float.valueOf(d.floatValue());
            }
            if (cls == Double.TYPE) {
                return Double.valueOf(d.doubleValue());
            }
            if (cls == Byte.TYPE) {
                return Byte.valueOf(d.byteValue());
            }
            if (cls == Short.TYPE) {
                return Short.valueOf(d.shortValue());
            }
            return null;
        }
        if (!Number.class.isAssignableFrom(cls)) {
            if (cls == Object.class) {
                return d;
            }
            return null;
        }
        if (Integer.class.isAssignableFrom(cls)) {
            return new Integer(d.intValue());
        }
        if (Long.class.isAssignableFrom(cls)) {
            return new Long(d.longValue());
        }
        if (Float.class.isAssignableFrom(cls)) {
            return new Float(d.floatValue());
        }
        if (Double.class.isAssignableFrom(cls)) {
            return d;
        }
        if (Byte.class.isAssignableFrom(cls)) {
            return new Byte(d.byteValue());
        }
        if (Short.class.isAssignableFrom(cls)) {
            return new Short(d.shortValue());
        }
        return null;
    }

    public static Number convertLuaNumber(Long l, Class<?> cls) {
        if (cls.isPrimitive()) {
            if (cls == Integer.TYPE) {
                return Integer.valueOf(l.intValue());
            }
            if (cls == Long.TYPE) {
                return Long.valueOf(l.longValue());
            }
            if (cls == Float.TYPE) {
                return Float.valueOf(l.floatValue());
            }
            if (cls == Double.TYPE) {
                return Double.valueOf(l.doubleValue());
            }
            if (cls == Byte.TYPE) {
                return Byte.valueOf(l.byteValue());
            }
            if (cls == Short.TYPE) {
                return Short.valueOf(l.shortValue());
            }
            return null;
        }
        if (!Number.class.isAssignableFrom(cls)) {
            if (cls == Object.class) {
                return l;
            }
            return null;
        }
        if (Integer.class.isAssignableFrom(cls)) {
            return new Integer(l.intValue());
        }
        if (Long.class.isAssignableFrom(cls)) {
            return new Long(l.longValue());
        }
        if (Float.class.isAssignableFrom(cls)) {
            return new Float(l.floatValue());
        }
        if (Double.class.isAssignableFrom(cls)) {
            return l;
        }
        if (Byte.class.isAssignableFrom(cls)) {
            return new Byte(l.byteValue());
        }
        if (Short.class.isAssignableFrom(cls)) {
            return new Short(l.shortValue());
        }
        return null;
    }

    public int LargError(int i, String str) {
        return _LargError(this.d, i, str);
    }

    public int LcallMeta(int i, String str) {
        return _LcallMeta(this.d, i, str);
    }

    public void LcheckAny(int i) {
        _LcheckAny(this.d, i);
    }

    public int LcheckInteger(int i) {
        return _LcheckInteger(this.d, i);
    }

    public double LcheckNumber(int i) {
        return _LcheckNumber(this.d, i);
    }

    public void LcheckStack(int i, String str) {
        _LcheckStack(this.d, i, str);
    }

    public String LcheckString(int i) {
        return _LcheckString(this.d, i);
    }

    public void LcheckType(int i, int i2) {
        _LcheckType(this.d, i, i2);
    }

    public int LdoFile(String str) {
        return _LdoFile(this.d, str);
    }

    public int LdoString(String str) {
        return _LdoString(this.d, str);
    }

    public int LgetMetaField(int i, String str) {
        return _LgetMetaField(this.d, i, str);
    }

    public void LgetMetatable(String str) {
        _LgetMetatable(this.d, str);
    }

    public String Lgsub(String str, String str2, String str3) {
        return _Lgsub(this.d, str, str2, str3);
    }

    public int LloadBuffer(byte[] bArr, String str) {
        return _LloadBuffer(this.d, bArr, bArr.length, str);
    }

    public int LloadFile(String str) {
        return _LloadFile(this.d, str);
    }

    public int LloadString(String str) {
        return _LloadString(this.d, str);
    }

    public int LnewMetatable(String str) {
        return _LnewMetatable(this.d, str);
    }

    public int LoptInteger(int i, int i2) {
        return _LoptInteger(this.d, i, i2);
    }

    public double LoptNumber(int i, double d) {
        return _LoptNumber(this.d, i, d);
    }

    public String LoptString(int i, String str) {
        return _LoptString(this.d, i, str);
    }

    public int Lref(int i) {
        return _Lref(this.d, i);
    }

    public String LtoString(int i) {
        return new String(_LtoString(this.d, i));
    }

    public void LunRef(int i, int i2) {
        _LunRef(this.d, i, i2);
    }

    public void Lwhere(int i) {
        _Lwhere(this.d, i);
    }

    public void call(int i, int i2) {
        _call(this.d, i, i2);
    }

    public int checkStack(int i) {
        return _checkStack(this.d, i);
    }

    public synchronized void close() {
        LuaStateFactory.removeLuaState(this.d);
        _close(this.d);
        this.d = 0L;
        c.clear();
        javaObjectMap.clear();
    }

    public int compare(int i, int i2, int i3) {
        return _compare(this.d, i, i2, i3);
    }

    public void concat(int i) {
        _concat(this.d, i);
    }

    public void copy(int i, int i2) {
        _copy(this.d, i, i2);
    }

    public void createTable(int i, int i2) {
        _createTable(this.d, i, i2);
    }

    public byte[] dump(int i) {
        return _dump(this.d, i);
    }

    public int equal(int i, int i2) {
        return _equal(this.d, i, i2);
    }

    public int error() {
        return _error(this.d);
    }

    protected void finalize() {
        Log.i("luaState", "finalize: " + this.d);
        try {
            close();
        } catch (Exception unused) {
            System.err.println("Unable to release luaState " + this.d);
        }
    }

    public int gc(int i, int i2) {
        Iterator<Integer> it = c.iterator();
        while (it.hasNext()) {
            javaObjectMap.remove(it.next());
        }
        c.clear();
        return _gc(this.d, i, i2);
    }

    public LuaContext getContext() {
        return this.e;
    }

    public int getField(int i, String str) {
        return _getField(this.d, i, str);
    }

    public LuaFunction getFunction(int i) {
        LuaObject luaObject = getLuaObject(i);
        if (luaObject.isFunction()) {
            return luaObject.getFunction();
        }
        return null;
    }

    public LuaFunction getFunction(String str) {
        LuaObject luaObject = getLuaObject(str);
        if (luaObject.isFunction()) {
            return luaObject.getFunction();
        }
        return null;
    }

    public synchronized int getGlobal(String str) {
        return _getGlobal(this.d, str);
    }

    public int getI(int i, long j) {
        return _getI(this.d, i, j);
    }

    public Object getJavaObject(int i) {
        return javaObjectMap.get(Integer.valueOf(i));
    }

    public LuaObject getLuaObject(int i) {
        return isFunction(i) ? new LuaFunction(this, i) : isTable(i) ? new LuaTable(this, i) : new LuaObject(this, i);
    }

    public LuaObject getLuaObject(LuaObject luaObject, LuaObject luaObject2) throws LuaException {
        if (luaObject.getLuaState().getPointer() == this.d && luaObject.getLuaState().getPointer() == luaObject2.getLuaState().getPointer()) {
            return new LuaObject(luaObject, luaObject2);
        }
        throw new LuaException("Object must have the same LuaState as the parent!");
    }

    public LuaObject getLuaObject(LuaObject luaObject, Number number) {
        return new LuaObject(luaObject, number);
    }

    public LuaObject getLuaObject(LuaObject luaObject, String str) {
        return new LuaObject(luaObject, str);
    }

    public LuaObject getLuaObject(String str) {
        pushGlobalTable();
        pushString(str);
        rawGet(-2);
        LuaObject luaObject = getLuaObject(-1);
        pop(2);
        return luaObject;
    }

    public int getMetaTable(int i) {
        return _getMetaTable(this.d, i);
    }

    public Object getObjectFromUserdata(int i) {
        return getJavaObject(_getObjectFromUserdata(this.d, i));
    }

    public long getPointer() {
        return this.d;
    }

    public int getTable(int i) {
        return _getTable(this.d, i);
    }

    public int getTop() {
        return _getTop(this.d);
    }

    public String getUpValue(int i, int i2) {
        return _getUpValue(this.d, i, i2);
    }

    public int getUserValue(int i) {
        return _getUserValue(this.d, i);
    }

    public void insert(int i) {
        _insert(this.d, i);
    }

    public boolean isBoolean(int i) {
        return _isBoolean(this.d, i) != 0;
    }

    public boolean isCFunction(int i) {
        return _isCFunction(this.d, i) != 0;
    }

    public synchronized boolean isClosed() {
        return this.d == 0;
    }

    public boolean isFunction(int i) {
        return _isFunction(this.d, i) != 0;
    }

    public boolean isInteger(int i) {
        return _isInteger(this.d, i) != 0;
    }

    public boolean isJavaFunction(int i) {
        return _isJavaFunction(this.d, i);
    }

    public boolean isNil(int i) {
        return _isNil(this.d, i) != 0;
    }

    public boolean isNone(int i) {
        return _isNone(this.d, i) != 0;
    }

    public boolean isNoneOrNil(int i) {
        return _isNoneOrNil(this.d, i) != 0;
    }

    public boolean isNumber(int i) {
        return _isNumber(this.d, i) != 0;
    }

    public boolean isObject(int i) {
        return _isObject(this.d, i);
    }

    public boolean isString(int i) {
        return _isString(this.d, i) != 0;
    }

    public boolean isTable(int i) {
        return _isTable(this.d, i) != 0;
    }

    public boolean isThread(int i) {
        return _isThread(this.d, i) != 0;
    }

    public boolean isUserdata(int i) {
        return _isUserdata(this.d, i) != 0;
    }

    public int isYieldable() {
        return _isYieldable(this.d);
    }

    public int lessThan(int i, int i2) {
        return _lessThan(this.d, i, i2);
    }

    public void newTable() {
        _newTable(this.d);
    }

    public LuaState newThread() {
        LuaState luaState = new LuaState(_newthread(this.d));
        LuaStateFactory.insertLuaState(luaState);
        return luaState;
    }

    public int next(int i) {
        return _next(this.d, i);
    }

    public int objLen(int i) {
        return _objlen(this.d, i);
    }

    public void openBase() {
        _openBase(this.d);
    }

    public void openDebug() {
        _openDebug(this.d);
    }

    public void openIo() {
        _openIo(this.d);
    }

    public void openLibs() {
        _openLibs(this.d);
        _openLuajava(this.d);
        pushPrimitive();
    }

    public void openLuajava() {
        _openLuajava(this.d);
        pushPrimitive();
        Pattern.compile("/(?:^|\\s)[\\u0780-\\u07BF]+?(?:\\s|$)/g");
    }

    public void openMath() {
        _openMath(this.d);
    }

    public void openOs() {
        _openOs(this.d);
    }

    public void openPackage() {
        _openPackage(this.d);
    }

    public void openString() {
        _openString(this.d);
    }

    public void openTable() {
        _openTable(this.d);
    }

    public int pcall(int i, int i2, int i3) {
        return _pcall(this.d, i, i2, i3);
    }

    public void pop(int i) {
        _pop(this.d, i);
    }

    public void pushBoolean(boolean z) {
        _pushBoolean(this.d, z ? 1 : 0);
    }

    public void pushContext(LuaContext luaContext) {
        this.e = luaContext;
        pushString("_LuaContext");
        pushJavaObject(luaContext);
        setTable(LUA_REGISTRYINDEX);
    }

    public synchronized void pushGlobalTable() {
        _pushGlobalTable(this.d);
    }

    public void pushInteger(long j) {
        _pushInteger(this.d, j);
    }

    public void pushJavaFunction(JavaFunction javaFunction) {
        _pushJavaFunction(this.d, javaFunction);
    }

    public void pushJavaObject(int i, Object obj) {
        javaObjectMap.put(Integer.valueOf(i), obj);
    }

    public void pushJavaObject(Object obj) {
        if (obj == null) {
            pushNil();
            return;
        }
        int andAdd = a.getAndAdd(1);
        pushJavaObject(andAdd, obj);
        Class<?> cls = obj instanceof Class ? (Class) obj : obj.getClass();
        try {
            if (obj instanceof Class) {
                _pushJavaObject(this.d, cls.getName(), andAdd, true);
            } else {
                _pushJavaObject(this.d, cls.getName(), andAdd, false);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void pushNil() {
        _pushNil(this.d);
    }

    public void pushNumber(double d) {
        _pushNumber(this.d, d);
    }

    public void pushObjectValue(Object obj) {
        double dDoubleValue;
        int iByteValue;
        long jLongValue;
        if (obj == null) {
            pushNil();
            return;
        }
        if (obj instanceof Boolean) {
            pushBoolean(((Boolean) obj).booleanValue());
            return;
        }
        if (obj instanceof Long) {
            jLongValue = ((Long) obj).longValue();
        } else {
            if (obj instanceof Integer) {
                iByteValue = ((Integer) obj).intValue();
            } else if (obj instanceof Short) {
                iByteValue = ((Short) obj).shortValue();
            } else if (obj instanceof Character) {
                iByteValue = ((Character) obj).charValue();
            } else {
                if (!(obj instanceof Byte)) {
                    if (obj instanceof Float) {
                        dDoubleValue = ((Float) obj).floatValue();
                    } else {
                        if (!(obj instanceof Double)) {
                            if (obj instanceof String) {
                                pushString((String) obj);
                                return;
                            }
                            if (obj instanceof LuaString) {
                                pushString(((LuaString) obj).toByteArray());
                                return;
                            }
                            if (obj instanceof JavaFunction) {
                                pushJavaFunction((JavaFunction) obj);
                                return;
                            }
                            boolean z = obj instanceof LuaObject;
                            Object obj2 = obj;
                            if (z) {
                                LuaObject luaObject = (LuaObject) obj;
                                LuaState luaState = luaObject.getLuaState();
                                obj2 = luaObject;
                                if (luaState == this) {
                                    luaObject.push();
                                    return;
                                }
                            }
                            pushJavaObject(obj2);
                            return;
                        }
                        dDoubleValue = ((Double) obj).doubleValue();
                    }
                    pushNumber(dDoubleValue);
                    return;
                }
                iByteValue = ((Byte) obj).byteValue();
            }
            jLongValue = iByteValue;
        }
        pushInteger(jLongValue);
    }

    public void pushPrimitive() {
        pushJavaObject(Boolean.TYPE);
        setGlobal("boolean");
        pushJavaObject(Byte.TYPE);
        setGlobal("byte");
        pushJavaObject(Character.TYPE);
        setGlobal("char");
        pushJavaObject(Short.TYPE);
        setGlobal("short");
        pushJavaObject(Integer.TYPE);
        setGlobal("int");
        pushJavaObject(Long.TYPE);
        setGlobal("long");
        pushJavaObject(Float.TYPE);
        setGlobal("float");
        pushJavaObject(Double.TYPE);
        setGlobal("double");
    }

    public void pushString(String str) {
        if (str == null) {
            _pushNil(this.d);
        } else {
            _pushString(this.d, str);
        }
    }

    public void pushString(byte[] bArr) {
        if (bArr == null) {
            _pushNil(this.d);
        } else {
            _pushLString(this.d, bArr, bArr.length);
        }
    }

    public void pushValue(int i) {
        _pushValue(this.d, i);
    }

    public int rawGet(int i) {
        return _rawGet(this.d, i);
    }

    public int rawGetI(int i, long j) {
        return _rawGetI(this.d, i, j);
    }

    public int rawLen(int i) {
        return _rawlen(this.d, i);
    }

    public void rawSet(int i) {
        _rawSet(this.d, i);
    }

    public void rawSetI(int i, long j) {
        _rawSetI(this.d, i, j);
    }

    public int rawequal(int i, int i2) {
        return _rawequal(this.d, i, i2);
    }

    public void remove(int i) {
        _remove(this.d, i);
    }

    public void removeJavaObject(int i) {
        c.add(Integer.valueOf(i));
    }

    public void replace(int i) {
        _replace(this.d, i);
    }

    public int resume(LuaState luaState, int i) {
        return _resume(this.d, luaState.getPointer(), i);
    }

    public void rotate(int i, int i2) {
        _rotate(this.d, i, i2);
    }

    public void setField(int i, String str) {
        _setField(this.d, i, str);
    }

    public synchronized void setGlobal(String str) {
        _setGlobal(this.d, str);
    }

    public void setI(int i, long j) {
        _setI(this.d, i, j);
    }

    public int setMetaTable(int i) {
        return _setMetaTable(this.d, i);
    }

    public void setTable(int i) {
        _setTable(this.d, i);
    }

    public void setTop(int i) {
        _setTop(this.d, i);
    }

    public String setUpValue(int i, int i2) {
        return _setUpValue(this.d, i, i2);
    }

    public void setUserValue(int i) {
        _setUserValue(this.d, i);
    }

    public int status() {
        return _status(this.d);
    }

    public int strLen(int i) {
        return _strlen(this.d, i);
    }

    public boolean toBoolean(int i) {
        return _toBoolean(this.d, i) != 0;
    }

    public byte[] toBuffer(int i) {
        return _toBuffer(this.d, i);
    }

    public long toInteger(int i) {
        return _toInteger(this.d, i);
    }

    public synchronized Object toJavaObject(int i) {
        Object objectFromUserdata;
        objectFromUserdata = null;
        if (isBoolean(i)) {
            objectFromUserdata = Boolean.valueOf(toBoolean(i));
        } else if (type(i) == 4) {
            objectFromUserdata = toString(i);
        } else if (isFunction(i)) {
            objectFromUserdata = getLuaObject(i).getFunction();
        } else if (isTable(i)) {
            objectFromUserdata = getLuaObject(i).getTable();
        } else if (type(i) == 3) {
            objectFromUserdata = isInteger(i) ? Long.valueOf(toInteger(i)) : Double.valueOf(toNumber(i));
        } else if (isUserdata(i)) {
            objectFromUserdata = isObject(i) ? getObjectFromUserdata(i) : getLuaObject(i);
        } else {
            isNil(i);
        }
        return objectFromUserdata;
    }

    public double toNumber(int i) {
        return _toNumber(this.d, i);
    }

    public String toString(int i) {
        return new String(_toString(this.d, i));
    }

    public LuaState toThread(int i) {
        return new LuaState(_toThread(this.d, i));
    }

    public int type(int i) {
        return _type(this.d, i);
    }

    public String typeName(int i) {
        return _typeName(this.d, i);
    }

    public void xmove(LuaState luaState, int i) {
        _xmove(this.d, luaState.d, i);
    }

    public int yield(int i) {
        return _yield(this.d, i);
    }
}