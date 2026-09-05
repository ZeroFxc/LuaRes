package com.luajava;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.os.Build;
import com.android.cglib.proxy.EnhancerInterface;
import com.android.cglib.proxy.MethodFilter;
import com.androlua.LuaBitmap;
import com.androlua.LuaEnhancer;
import com.androlua.LuaGcable;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\andlua.dex */
@SuppressLint({"UseSparseArrays"})
public final class LuaJavaAPI {
    private static final HashMap<Class<?>, Method[]> a = new HashMap<>();
    private static final Map<String, Method[]> b = new HashMap();
    private static final HashMap<Class<?>, HashMap<String, ArrayList<Method>>> c = new HashMap<>();
    private static final HashMap<String, Method> d = new HashMap<>();
    private static final HashMap<String, Method> e = new HashMap<>();
    private static final HashMap<String, Method> f = new HashMap<>();
    private static final HashMap<String, Method> g = new HashMap<>();
    private static final HashMap<String, Method> h = new HashMap<>();
    private static final HashMap<Integer, Object> i = new HashMap<>();

    private static class JavaObject {
        private final Object a;

        public JavaObject(Object obj) {
            this.a = obj;
        }

        public Object getObject() {
            return this.a;
        }
    }

    private LuaJavaAPI() {
    }

    private static String a(LuaState luaState, String str, int i2, Class cls) throws LuaException {
        throw new LuaException("bad argument to '" + str + "' (" + cls.getName() + " expected, got " + w(luaState, i2) + " value)");
    }

    public static int asTable(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (existingState.isBoolean(-1) && existingState.toBoolean(-1)) {
                existingState.pop(1);
                return c(existingState, javaObject);
            }
            try {
                existingState.newTable();
                int top = existingState.getTop();
                if (javaObject == null) {
                    return 1;
                }
                if (javaObject.getClass().isArray()) {
                    int length = Array.getLength(javaObject);
                    int i3 = 0;
                    while (i3 <= length - 1) {
                        existingState.pushObjectValue(Array.get(javaObject, i3));
                        i3++;
                        existingState.rawSetI(-2, i3);
                    }
                } else if (javaObject instanceof Collection) {
                    Iterator it = ((Collection) javaObject).iterator();
                    int i4 = 1;
                    while (it.hasNext()) {
                        existingState.pushObjectValue(it.next());
                        existingState.rawSetI(-2, i4);
                        i4++;
                    }
                } else if (javaObject instanceof Map) {
                    for (Map.Entry entry : ((Map) javaObject).entrySet()) {
                        existingState.pushObjectValue(entry.getKey());
                        existingState.pushObjectValue(entry.getValue());
                        existingState.setTable(-3);
                    }
                }
                existingState.pushValue(top);
                return 1;
            } catch (Exception e2) {
                throw new LuaException("can not astable: " + e2.getMessage());
            }
        }
    }

    private static String b(LuaState luaState, String str, int i2, String str2) throws LuaException {
        throw new LuaException("bad argument #" + i2 + " to '" + str + "' (" + str2 + " expected, got " + w(luaState, i2 + 1) + " value)");
    }

    private static int c(LuaState luaState, Object obj) {
        synchronized (luaState) {
            try {
                try {
                    luaState.newTable();
                    if (obj == null) {
                        return 1;
                    }
                    if (obj.getClass().isArray()) {
                        int length = Array.getLength(obj);
                        int i2 = 0;
                        while (i2 <= length - 1) {
                            c(luaState, Array.get(obj, i2));
                            i2++;
                            luaState.rawSetI(-2, i2);
                        }
                    } else if (obj instanceof Collection) {
                        Iterator it = ((Collection) obj).iterator();
                        int i3 = 1;
                        while (it.hasNext()) {
                            c(luaState, it.next());
                            luaState.rawSetI(-2, i3);
                            i3++;
                        }
                    } else if (obj instanceof Map) {
                        for (Map.Entry entry : ((Map) obj).entrySet()) {
                            luaState.pushObjectValue(entry.getKey());
                            c(luaState, entry.getValue());
                            luaState.setTable(-3);
                        }
                    } else {
                        luaState.pop(1);
                        luaState.pushObjectValue(obj);
                    }
                    return 1;
                } catch (Exception e2) {
                    throw new LuaException("can not astable: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
    }

    /* JADX WARN: Removed duplicated region for block: B:128:0x023b A[Catch: all -> 0x0286, TryCatch #2 {, blocks: (B:4:0x000d, B:6:0x001c, B:8:0x0027, B:10:0x002f, B:12:0x003b, B:14:0x003d, B:15:0x0040, B:18:0x0043, B:20:0x0056, B:21:0x005a, B:22:0x007c, B:24:0x007f, B:26:0x0085, B:50:0x010a, B:52:0x0114, B:53:0x0117, B:55:0x011d, B:57:0x0129, B:59:0x012b, B:60:0x012e, B:63:0x0131, B:65:0x0144, B:66:0x0148, B:67:0x016a, B:31:0x0096, B:33:0x00a0, B:35:0x00a9, B:37:0x00af, B:39:0x00b9, B:41:0x00d1, B:43:0x00db, B:45:0x00f2, B:47:0x00fc, B:69:0x016c, B:71:0x017a, B:72:0x0184, B:74:0x0187, B:125:0x022d, B:78:0x019a, B:80:0x019d, B:85:0x01b5, B:88:0x01c0, B:121:0x0207, B:123:0x0221, B:124:0x0225, B:92:0x01c6, B:103:0x01da, B:104:0x01dc, B:110:0x01ee, B:112:0x01fa, B:115:0x01fe, B:116:0x0201, B:105:0x01e0, B:106:0x01e3, B:107:0x01e6, B:108:0x01e9, B:126:0x0233, B:128:0x023b, B:130:0x023f, B:131:0x0250, B:132:0x026a, B:133:0x026b, B:134:0x0285), top: B:144:0x000d, inners: #1, #5 }] */
    /* JADX WARN: Removed duplicated region for block: B:133:0x026b A[Catch: all -> 0x0286, TryCatch #2 {, blocks: (B:4:0x000d, B:6:0x001c, B:8:0x0027, B:10:0x002f, B:12:0x003b, B:14:0x003d, B:15:0x0040, B:18:0x0043, B:20:0x0056, B:21:0x005a, B:22:0x007c, B:24:0x007f, B:26:0x0085, B:50:0x010a, B:52:0x0114, B:53:0x0117, B:55:0x011d, B:57:0x0129, B:59:0x012b, B:60:0x012e, B:63:0x0131, B:65:0x0144, B:66:0x0148, B:67:0x016a, B:31:0x0096, B:33:0x00a0, B:35:0x00a9, B:37:0x00af, B:39:0x00b9, B:41:0x00d1, B:43:0x00db, B:45:0x00f2, B:47:0x00fc, B:69:0x016c, B:71:0x017a, B:72:0x0184, B:74:0x0187, B:125:0x022d, B:78:0x019a, B:80:0x019d, B:85:0x01b5, B:88:0x01c0, B:121:0x0207, B:123:0x0221, B:124:0x0225, B:92:0x01c6, B:103:0x01da, B:104:0x01dc, B:110:0x01ee, B:112:0x01fa, B:115:0x01fe, B:116:0x0201, B:105:0x01e0, B:106:0x01e3, B:107:0x01e6, B:108:0x01e9, B:126:0x0233, B:128:0x023b, B:130:0x023f, B:131:0x0250, B:132:0x026a, B:133:0x026b, B:134:0x0285), top: B:144:0x000d, inners: #1, #5 }] */
    /* JADX WARN: Removed duplicated region for block: B:26:0x0085 A[Catch: all -> 0x0286, TryCatch #2 {, blocks: (B:4:0x000d, B:6:0x001c, B:8:0x0027, B:10:0x002f, B:12:0x003b, B:14:0x003d, B:15:0x0040, B:18:0x0043, B:20:0x0056, B:21:0x005a, B:22:0x007c, B:24:0x007f, B:26:0x0085, B:50:0x010a, B:52:0x0114, B:53:0x0117, B:55:0x011d, B:57:0x0129, B:59:0x012b, B:60:0x012e, B:63:0x0131, B:65:0x0144, B:66:0x0148, B:67:0x016a, B:31:0x0096, B:33:0x00a0, B:35:0x00a9, B:37:0x00af, B:39:0x00b9, B:41:0x00d1, B:43:0x00db, B:45:0x00f2, B:47:0x00fc, B:69:0x016c, B:71:0x017a, B:72:0x0184, B:74:0x0187, B:125:0x022d, B:78:0x019a, B:80:0x019d, B:85:0x01b5, B:88:0x01c0, B:121:0x0207, B:123:0x0221, B:124:0x0225, B:92:0x01c6, B:103:0x01da, B:104:0x01dc, B:110:0x01ee, B:112:0x01fa, B:115:0x01fe, B:116:0x0201, B:105:0x01e0, B:106:0x01e3, B:107:0x01e6, B:108:0x01e9, B:126:0x0233, B:128:0x023b, B:130:0x023f, B:131:0x0250, B:132:0x026a, B:133:0x026b, B:134:0x0285), top: B:144:0x000d, inners: #1, #5 }] */
    /* JADX WARN: Removed duplicated region for block: B:71:0x017a A[Catch: all -> 0x0286, LOOP:0: B:70:0x0178->B:71:0x017a, LOOP_END, TryCatch #2 {, blocks: (B:4:0x000d, B:6:0x001c, B:8:0x0027, B:10:0x002f, B:12:0x003b, B:14:0x003d, B:15:0x0040, B:18:0x0043, B:20:0x0056, B:21:0x005a, B:22:0x007c, B:24:0x007f, B:26:0x0085, B:50:0x010a, B:52:0x0114, B:53:0x0117, B:55:0x011d, B:57:0x0129, B:59:0x012b, B:60:0x012e, B:63:0x0131, B:65:0x0144, B:66:0x0148, B:67:0x016a, B:31:0x0096, B:33:0x00a0, B:35:0x00a9, B:37:0x00af, B:39:0x00b9, B:41:0x00d1, B:43:0x00db, B:45:0x00f2, B:47:0x00fc, B:69:0x016c, B:71:0x017a, B:72:0x0184, B:74:0x0187, B:125:0x022d, B:78:0x019a, B:80:0x019d, B:85:0x01b5, B:88:0x01c0, B:121:0x0207, B:123:0x0221, B:124:0x0225, B:92:0x01c6, B:103:0x01da, B:104:0x01dc, B:110:0x01ee, B:112:0x01fa, B:115:0x01fe, B:116:0x0201, B:105:0x01e0, B:106:0x01e3, B:107:0x01e6, B:108:0x01e9, B:126:0x0233, B:128:0x023b, B:130:0x023f, B:131:0x0250, B:132:0x026a, B:133:0x026b, B:134:0x0285), top: B:144:0x000d, inners: #1, #5 }] */
    /* JADX WARN: Removed duplicated region for block: B:74:0x0187 A[Catch: all -> 0x0286, TryCatch #2 {, blocks: (B:4:0x000d, B:6:0x001c, B:8:0x0027, B:10:0x002f, B:12:0x003b, B:14:0x003d, B:15:0x0040, B:18:0x0043, B:20:0x0056, B:21:0x005a, B:22:0x007c, B:24:0x007f, B:26:0x0085, B:50:0x010a, B:52:0x0114, B:53:0x0117, B:55:0x011d, B:57:0x0129, B:59:0x012b, B:60:0x012e, B:63:0x0131, B:65:0x0144, B:66:0x0148, B:67:0x016a, B:31:0x0096, B:33:0x00a0, B:35:0x00a9, B:37:0x00af, B:39:0x00b9, B:41:0x00d1, B:43:0x00db, B:45:0x00f2, B:47:0x00fc, B:69:0x016c, B:71:0x017a, B:72:0x0184, B:74:0x0187, B:125:0x022d, B:78:0x019a, B:80:0x019d, B:85:0x01b5, B:88:0x01c0, B:121:0x0207, B:123:0x0221, B:124:0x0225, B:92:0x01c6, B:103:0x01da, B:104:0x01dc, B:110:0x01ee, B:112:0x01fa, B:115:0x01fe, B:116:0x0201, B:105:0x01e0, B:106:0x01e3, B:107:0x01e6, B:108:0x01e9, B:126:0x0233, B:128:0x023b, B:130:0x023f, B:131:0x0250, B:132:0x026a, B:133:0x026b, B:134:0x0285), top: B:144:0x000d, inners: #1, #5 }] */
    /* JADX WARN: Removed duplicated region for block: B:76:0x0190  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static int callMethod(long r20, int r22, java.lang.String r23) {
        /*
            Method dump skipped, instruction units count: 651
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.callMethod(long, int, java.lang.String):int");
    }

    public static int checkClass(LuaState luaState, Object obj, String str) {
        synchronized (luaState) {
            if (!(obj instanceof Class)) {
                return 0;
            }
            Class cls = (Class) obj;
            try {
                luaState.pushJavaObject(Class.forName(cls.getName() + "$" + str));
                return 3;
            } catch (Exception unused) {
                for (Class<?> cls2 : cls.getClasses()) {
                    if (cls2.getSimpleName().equals(str)) {
                        luaState.pushJavaObject(cls2);
                        return 3;
                    }
                }
                return 0;
            }
        }
    }

    public static int checkField(LuaState luaState, Object obj, String str) {
        Class<?> cls;
        boolean z;
        synchronized (luaState) {
            if (obj instanceof Class) {
                cls = (Class) obj;
                z = true;
            } else {
                cls = obj.getClass();
                z = false;
            }
            try {
                Field field = cls.getField(str);
                if (field == null) {
                    return 0;
                }
                if (z && !Modifier.isStatic(field.getModifiers())) {
                    return 0;
                }
                try {
                    if (!Modifier.isPublic(field.getModifiers())) {
                        field.setAccessible(true);
                    }
                    luaState.pushObjectValue(field.get(obj));
                    return Modifier.isFinal(field.getModifiers()) ? 5 : 1;
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (NoSuchFieldException unused) {
                return 0;
            }
        }
    }

    public static int checkMethod(LuaState luaState, Object obj, String str) {
        synchronized (luaState) {
            return q(obj, str, luaState.toString(-1)).length == 0 ? 0 : 2;
        }
    }

    public static void clearCaches() {
        b.clear();
        a.clear();
        d.clear();
        e.clear();
        f.clear();
        g.clear();
        h.clear();
    }

    public static int createArray(long j, String str) {
        int iH;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            iH = h(existingState, d(str));
        }
        return iH;
    }

    public static int createProxy(long j, String str) {
        int iO;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            iO = o(existingState, str);
        }
        return iO;
    }

    private static Class d(String str) throws LuaException {
        try {
            return Class.forName(str);
        } catch (Exception unused) {
            str.hashCode();
            switch (str) {
                case "double":
                    return Double.TYPE;
                case "int":
                    return Integer.TYPE;
                case "byte":
                    return Byte.TYPE;
                case "char":
                    return Character.TYPE;
                case "long":
                    return Long.TYPE;
                case "boolean":
                    return Boolean.TYPE;
                case "float":
                    return Float.TYPE;
                case "short":
                    return Short.TYPE;
                default:
                    throw new LuaException("Class not found: " + str);
            }
        }
    }

    private static Object e(LuaState luaState, Class<?> cls, int i2) {
        return f(luaState, cls, luaState.type(i2), i2);
    }

    /* JADX WARN: Removed duplicated region for block: B:76:0x00a9  */
    /* JADX WARN: Removed duplicated region for block: B:91:0x00ea A[PHI: r0
  0x00ea: PHI (r0v3 java.lang.Object) = 
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v12 java.lang.Object)
 binds: [B:109:0x0136, B:96:0x00fd, B:90:0x00e8, B:87:0x00df, B:72:0x009e, B:64:0x0081, B:61:0x0076] A[DONT_GENERATE, DONT_INLINE]] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    private static java.lang.Object f(com.luajava.LuaState r4, java.lang.Class<?> r5, int r6, int r7) throws com.luajava.LuaException {
        /*
            Method dump skipped, instruction units count: 336
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.f(com.luajava.LuaState, java.lang.Class, int, int):java.lang.Object");
    }

    private static int g(LuaState luaState, Class<?> cls) {
        try {
            EnhancerInterface enhancerInterface = (EnhancerInterface) new LuaEnhancer(cls).create(new MethodFilter() { // from class: com.luajava.LuaJavaAPI.2
                public boolean filter(Method method, String str) {
                    return (method.getModifiers() & 1024) == 0;
                }
            }).newInstance();
            enhancerInterface.setMethodInterceptor_Enhancer(new LuaAbstractMethodInterceptor(luaState.getLuaObject(-1)));
            luaState.pushJavaObject(enhancerInterface);
            return 1;
        } catch (Exception unused) {
            return 0;
        }
    }

    public static int getArrayValue(long j, int i2, int i3) {
        Object obj;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (javaObject.getClass().isArray()) {
                obj = Array.get(javaObject, i3);
            } else if (javaObject instanceof List) {
                obj = ((List) javaObject).get(i3);
            } else {
                if (!(javaObject instanceof Map)) {
                    throw new LuaException("can not get " + javaObject.getClass().getName() + " value in " + i3);
                }
                obj = ((Map) javaObject).get(Long.valueOf(i3));
            }
            existingState.pushObjectValue(obj);
        }
        return 1;
    }

    public static int getContext(long j) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            existingState.pushJavaObject(existingState.getContext());
        }
        return 1;
    }

    public static Object getJavaObject2(int i2) {
        return i.get(Integer.valueOf(i2));
    }

    public static ArrayList<Method> getMethod(Class<?> cls, String str, boolean z) {
        HashMap<Class<?>, HashMap<String, ArrayList<Method>>> map = c;
        HashMap<String, ArrayList<Method>> map2 = map.get(cls);
        if (map2 == null) {
            map2 = new HashMap<>();
            map.put(cls, map2);
        }
        ArrayList<Method> arrayList = map2.get(str);
        if (arrayList == null) {
            HashMap<Class<?>, Method[]> map3 = a;
            Method[] methods = map3.get(cls);
            if (methods == null) {
                methods = cls.getMethods();
                map3.put(cls, methods);
            }
            for (Method method : methods) {
                String name = method.getName();
                ArrayList<Method> arrayList2 = map2.get(name);
                if (arrayList2 == null) {
                    arrayList2 = new ArrayList<>();
                    map2.put(name, arrayList2);
                }
                arrayList2.add(method);
            }
            arrayList = map2.get(str);
        }
        if (arrayList == null) {
            arrayList = new ArrayList<>();
        }
        if (!z) {
            return arrayList;
        }
        ArrayList<Method> arrayList3 = new ArrayList<>();
        for (Method method2 : arrayList) {
            if (Modifier.isStatic(method2.getModifiers())) {
                arrayList3.add(method2);
            }
        }
        return arrayList3.isEmpty() ? getMethod(Class.class, str, false) : arrayList3;
    }

    private static int h(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(i(luaState, cls, 2));
        }
        return 1;
    }

    private static Object i(LuaState luaState, Class<?> cls, int i2) {
        Object objNewInstance;
        synchronized (luaState) {
            try {
                try {
                    int iObjLen = luaState.objLen(i2);
                    objNewInstance = Array.newInstance(cls, iObjLen);
                    if (cls == String.class) {
                        for (int i3 = 1; i3 <= iObjLen; i3++) {
                            luaState.pushNumber(i3);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i3 - 1, luaState.toString(-1));
                            luaState.pop(1);
                        }
                    } else if (cls == Double.TYPE) {
                        for (int i4 = 1; i4 <= iObjLen; i4++) {
                            luaState.pushNumber(i4);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i4 - 1, Double.valueOf(luaState.toNumber(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Float.TYPE) {
                        for (int i5 = 1; i5 <= iObjLen; i5++) {
                            luaState.pushNumber(i5);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i5 - 1, Float.valueOf((float) luaState.toNumber(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Long.TYPE) {
                        for (int i6 = 1; i6 <= iObjLen; i6++) {
                            luaState.pushNumber(i6);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i6 - 1, Long.valueOf(luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Integer.TYPE) {
                        for (int i7 = 1; i7 <= iObjLen; i7++) {
                            luaState.pushNumber(i7);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i7 - 1, Integer.valueOf((int) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Short.TYPE) {
                        for (int i8 = 1; i8 <= iObjLen; i8++) {
                            luaState.pushNumber(i8);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i8 - 1, Short.valueOf((short) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Character.TYPE) {
                        for (int i9 = 1; i9 <= iObjLen; i9++) {
                            luaState.pushNumber(i9);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i9 - 1, Character.valueOf((char) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Byte.TYPE) {
                        for (int i10 = 1; i10 <= iObjLen; i10++) {
                            luaState.pushNumber(i10);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i10 - 1, Byte.valueOf((byte) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else {
                        for (int i11 = 1; i11 <= iObjLen; i11++) {
                            luaState.pushNumber(i11);
                            luaState.getTable(i2);
                            Array.set(objNewInstance, i11 - 1, e(luaState, cls, luaState.getTop()));
                            luaState.pop(1);
                        }
                    }
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return objNewInstance;
    }

    private static int j(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(k(luaState, cls, 2));
        }
        return 1;
    }

    public static int javaBindClass(long j, String str) {
        LuaStateFactory.getExistingState(j).pushJavaObject(d(str));
        return 1;
    }

    public static void javaClose(long j, int i2) {
        Bitmap bitmap;
        Object javaObject = LuaStateFactory.getExistingState(j).getJavaObject(i2);
        if (javaObject == null) {
            return;
        }
        try {
            if (javaObject instanceof LuaGcable) {
                ((LuaGcable) javaObject).gc();
                return;
            }
            if (javaObject instanceof Bitmap) {
                LuaBitmap.removeBitmap((Bitmap) javaObject);
                bitmap = (Bitmap) javaObject;
            } else {
                if (!(javaObject instanceof BitmapDrawable)) {
                    if (Build.VERSION.SDK_INT < 19 || !(javaObject instanceof AutoCloseable)) {
                        return;
                    }
                    ((AutoCloseable) javaObject).close();
                    return;
                }
                bitmap = ((BitmapDrawable) javaObject).getBitmap();
            }
            bitmap.recycle();
        } catch (Exception e2) {
            e2.printStackTrace();
        }
    }

    public static int javaCreate(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Class cls = (Class) existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (!cls.isPrimitive() && cls != String.class) {
                if (cls.isArray()) {
                    return h(existingState, cls);
                }
                if (List.class.isAssignableFrom(cls)) {
                    return j(existingState, cls);
                }
                if (Map.class.isAssignableFrom(cls)) {
                    return l(existingState, cls);
                }
                if (cls.isInterface()) {
                    return n(existingState, cls);
                }
                if ((cls.getModifiers() & 1024) != 0) {
                    return g(existingState, cls);
                }
                if (existingState.objLen(-1) == 0) {
                    return h(existingState, cls);
                }
                existingState.getI(-1, 1L);
                Object javaObject = existingState.toJavaObject(-1);
                existingState.pop(1);
                if (cls.isAssignableFrom(javaObject.getClass())) {
                    return h(existingState, cls);
                }
                return r(existingState, cls);
            }
            return h(existingState, cls);
        }
    }

    public static int javaEquals(long j, int i2, int i3) {
        int i4;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        Object javaObject2 = existingState.getJavaObject(i3);
        synchronized (existingState) {
            i4 = javaObject.equals(javaObject2) ? 1 : 0;
        }
        return i4;
    }

    public static void javaGc(long j, int i2) {
        LuaStateFactory.getExistingState(j).removeJavaObject(i2);
    }

    public static Object javaGetObject(long j, int i2) {
        return LuaStateFactory.getExistingState(j).getJavaObject(i2);
    }

    public static int javaGetType(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            existingState.pushString(javaObject == null ? "null" : javaObject.getClass().getName());
        }
        return 1;
    }

    /* JADX WARN: Removed duplicated region for block: B:35:0x00b7 A[Catch: all -> 0x00cb, TryCatch #2 {, blocks: (B:4:0x0002, B:6:0x0007, B:7:0x0010, B:9:0x0012, B:11:0x0017, B:13:0x0021, B:15:0x002b, B:16:0x0042, B:18:0x005c, B:20:0x0066, B:25:0x0099, B:27:0x00a3, B:29:0x00a5, B:32:0x00ad, B:33:0x00b3, B:35:0x00b7, B:37:0x00c2, B:36:0x00bf, B:40:0x00c5, B:41:0x00ca, B:22:0x007f, B:30:0x00ab, B:12:0x001c), top: B:49:0x0002, inners: #0, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:36:0x00bf A[Catch: all -> 0x00cb, TryCatch #2 {, blocks: (B:4:0x0002, B:6:0x0007, B:7:0x0010, B:9:0x0012, B:11:0x0017, B:13:0x0021, B:15:0x002b, B:16:0x0042, B:18:0x005c, B:20:0x0066, B:25:0x0099, B:27:0x00a3, B:29:0x00a5, B:32:0x00ad, B:33:0x00b3, B:35:0x00b7, B:37:0x00c2, B:36:0x00bf, B:40:0x00c5, B:41:0x00ca, B:22:0x007f, B:30:0x00ab, B:12:0x001c), top: B:49:0x0002, inners: #0, #3 }] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static int javaGetter(com.luajava.LuaState r7, java.lang.Object r8, java.lang.String r9) {
        /*
            Method dump skipped, instruction units count: 208
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.javaGetter(com.luajava.LuaState, java.lang.Object, java.lang.String):int");
    }

    public static int javaInstanceof(long j, int i2, int i3) {
        int i4;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        Class cls = (Class) existingState.getJavaObject(i3);
        synchronized (existingState) {
            i4 = cls.isInstance(javaObject) ? 1 : 0;
        }
        return i4;
    }

    public static int javaLoadLib(long j, String str, String str2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            try {
                try {
                    try {
                        Object objInvoke = Class.forName(str).getMethod(str2, LuaState.class).invoke(null, existingState);
                        if (objInvoke == null || !(objInvoke instanceof Integer)) {
                            return 0;
                        }
                        return ((Integer) objInvoke).intValue();
                    } catch (Exception e2) {
                        throw new LuaException("Error on calling method. Library could not be loaded. " + e2.getMessage());
                    }
                } catch (ClassNotFoundException e3) {
                    throw new LuaException(e3);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
    }

    public static int javaNew(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Class cls = (Class) existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (cls.isPrimitive()) {
                int top = existingState.getTop();
                for (int i3 = 2; i3 <= top; i3++) {
                    v(existingState, cls, i3);
                }
                return top - 1;
            }
            if ((cls.getModifiers() & 1024) == 0) {
                return r(existingState, cls);
            }
            if (existingState.isTable(2)) {
                return javaOverride(j, i2);
            }
            b(existingState, "javaOverride", 1, "table");
            throw null;
        }
    }

    public static int javaNewInstance(long j, String str) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            Class clsD = d(str);
            if (clsD.isPrimitive()) {
                return v(existingState, clsD, -1);
            }
            return r(existingState, clsD);
        }
    }

    public static int javaObjectLength(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            try {
                try {
                    existingState.pushInteger(javaObject instanceof CharSequence ? ((CharSequence) javaObject).length() : javaObject instanceof Collection ? ((Collection) javaObject).size() : javaObject instanceof Map ? ((Map) javaObject).size() : Array.getLength(javaObject));
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int javaOverride(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Class cls = (Class) existingState.getJavaObject(i2);
        synchronized (existingState) {
            final LuaTable luaTable = new LuaTable(existingState, 2);
            existingState.remove(2);
            if (r(existingState, new LuaEnhancer(cls).create(new MethodFilter() { // from class: com.luajava.LuaJavaAPI.1
                public boolean filter(Method method, String str) {
                    return luaTable.containsKey(str);
                }
            })) == 0) {
                return 0;
            }
            EnhancerInterface enhancerInterface = (EnhancerInterface) existingState.toJavaObject(-1);
            enhancerInterface.setMethodInterceptor_Enhancer(new LuaMethodInterceptor(luaTable));
            existingState.pushJavaObject(enhancerInterface);
            return 1;
        }
    }

    public static int javaSetter(LuaState luaState, Object obj, String str) {
        synchronized (luaState) {
            boolean z = true;
            if (obj instanceof Map) {
                ((Map) obj).put(str, luaState.toJavaObject(-1));
                return 1;
            }
            if (obj instanceof Class) {
            } else {
                obj.getClass();
                z = false;
            }
            if (str.length() > 2 && str.substring(0, 2).equals("on") && luaState.type(-1) == 6) {
                return s(luaState, obj, str, z);
            }
            int iT = t(luaState, obj, str, z);
            if (iT != 0) {
                return iT;
            }
            return u(luaState, obj, str);
        }
    }

    public static int javaSetter(LuaState luaState, Object obj, String str, Object obj2) {
        luaState.pushObjectValue(obj2);
        int iJavaSetter = javaSetter(luaState, obj, str);
        luaState.pop(1);
        return iJavaSetter;
    }

    public static int javaToString(long j, int i2) {
        String name;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (javaObject == null) {
                name = "null";
            } else {
                String string = javaObject.toString();
                if (string != null) {
                    existingState.pushString(string);
                } else {
                    name = javaObject.getClass().getName();
                }
            }
            existingState.pushString(name);
        }
        return 1;
    }

    private static Object k(LuaState luaState, Class<List<Object>> cls, int i2) {
        List<Object> arrayList;
        synchronized (luaState) {
            int iObjLen = luaState.objLen(i2);
            try {
                arrayList = cls.equals(List.class) ? new ArrayList<>() : cls.newInstance();
                for (int i3 = 1; i3 <= iObjLen; i3++) {
                    luaState.pushNumber(i3);
                    luaState.getTable(i2);
                    arrayList.add(luaState.toJavaObject(-1));
                    luaState.pop(1);
                }
            } catch (Exception e2) {
                throw new LuaException(e2);
            }
        }
        return arrayList;
    }

    private static int l(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(m(luaState, cls, 2));
        }
        return 1;
    }

    private static Object m(LuaState luaState, Class<Map<Object, Object>> cls, int i2) {
        Map<Object, Object> map;
        synchronized (luaState) {
            try {
                try {
                    map = cls.equals(Map.class) ? new HashMap<>() : cls.newInstance();
                    luaState.pushNil();
                    while (luaState.next(i2) != 0) {
                        map.put(luaState.toJavaObject(-2), luaState.toJavaObject(-1));
                        luaState.pop(1);
                    }
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return map;
    }

    private static int n(LuaState luaState, Class cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(p(luaState, cls, 2));
        }
        return 1;
    }

    public static int newArray(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Class cls = (Class) existingState.getJavaObject(i2);
        synchronized (existingState) {
            try {
                try {
                    int top = existingState.getTop() - 1;
                    int[] iArr = new int[top];
                    for (int i3 = 0; i3 < top; i3++) {
                        iArr[i3] = (int) existingState.toInteger(i3 + 2);
                    }
                    existingState.pushJavaObject(Array.newInstance((Class<?>) cls, iArr));
                } catch (Exception e2) {
                    throw new LuaException("can not create a array: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int newArray(long j, int i2, int i3) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Class cls = (Class) existingState.getJavaObject(i2);
        synchronized (existingState) {
            try {
                try {
                    existingState.pushJavaObject(Array.newInstance((Class<?>) cls, i3));
                } catch (Exception e2) {
                    throw new LuaException("can not create a array: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    private static int o(LuaState luaState, String str) {
        synchronized (luaState) {
            try {
                try {
                    luaState.pushJavaObject(luaState.getLuaObject(2).createProxy(str));
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int objectCall(long j, int i2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (javaObject instanceof LuaMetaTable) {
                int top = existingState.getTop();
                Object[] objArr = new Object[top - 1];
                for (int i3 = 2; i3 <= top; i3++) {
                    objArr[i3 - 2] = existingState.toJavaObject(i3);
                }
                existingState.pushObjectValue(((LuaMetaTable) javaObject).__call(objArr));
                return 1;
            }
            if (!existingState.isTable(2)) {
                return 0;
            }
            if (javaObject.getClass().isArray() && Array.getLength(javaObject) == 0) {
                return h(existingState, javaObject.getClass());
            }
            existingState.pushNil();
            if (javaObject instanceof List) {
                List list = (List) javaObject;
                while (existingState.next(2) != 0) {
                    list.add(existingState.toJavaObject(-1));
                    existingState.pop(1);
                }
            } else {
                while (existingState.next(2) != 0) {
                    if (existingState.isNumber(-2)) {
                        setArrayValue(existingState, javaObject, (int) existingState.toInteger(-2));
                    } else {
                        javaSetter(existingState, javaObject, existingState.toString(-2));
                    }
                    existingState.pop(1);
                }
            }
            existingState.setTop(1);
            return 1;
        }
    }

    public static int objectIndex(long j, int i2, String str, int i3) {
        int iCheckField;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (i3 == 0) {
                try {
                    if (checkMethod(existingState, javaObject, str) != 0) {
                        return 2;
                    }
                } catch (Throwable th) {
                    throw th;
                }
            }
            if ((i3 == 0 || i3 == 1 || i3 == 5) && (iCheckField = checkField(existingState, javaObject, str)) != 0) {
                return iCheckField;
            }
            if ((i3 == 0 || i3 == 4) && javaGetter(existingState, javaObject, str) != 0) {
                return 4;
            }
            if ((i3 == 0 || i3 == 3) && checkClass(existingState, javaObject, str) != 0) {
                return 3;
            }
            if ((i3 != 0 && i3 != 6) || !(javaObject instanceof LuaMetaTable)) {
                return 0;
            }
            existingState.pushObjectValue(((LuaMetaTable) javaObject).__index(str));
            return 6;
        }
    }

    public static int objectNewIndex(long j, int i2, String str, int i3) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (i3 == 0 || i3 == 1) {
                if (setFieldValue(existingState, javaObject, str) != 0) {
                    return 1;
                }
            }
            if ((i3 == 0 || i3 == 2) && javaSetter(existingState, javaObject, str) != 0) {
                return 2;
            }
            if ((i3 != 0 && i3 != 3) || !(javaObject instanceof LuaMetaTable)) {
                return 0;
            }
            ((LuaMetaTable) javaObject).__newIndex(str, existingState.toJavaObject(-1));
            return 3;
        }
    }

    private static Object p(LuaState luaState, Class cls, int i2) {
        Object objCreateProxy;
        synchronized (luaState) {
            try {
                try {
                    objCreateProxy = luaState.getLuaObject(i2).createProxy(cls);
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return objCreateProxy;
    }

    public static void pushJavaObject(int i2, Object obj) {
        i.put(Integer.valueOf(i2), obj);
    }

    private static Method[] q(Object obj, String str, String str2) {
        Class<?> cls;
        boolean z;
        if (obj instanceof Class) {
            cls = (Class) obj;
            z = true;
        } else {
            cls = obj.getClass();
            z = false;
        }
        Map<String, Method[]> map = b;
        Method[] methodArr = map.get(str2);
        if (methodArr != null) {
            return methodArr;
        }
        ArrayList<Method> method = getMethod(cls, str, z);
        Method[] methodArr2 = new Method[method.size()];
        method.toArray(methodArr2);
        map.put(str2, methodArr2);
        return methodArr2;
    }

    /* JADX WARN: Removed duplicated region for block: B:14:0x0041 A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:3:0x0001, B:6:0x0009, B:7:0x0010, B:12:0x0031, B:14:0x0041, B:34:0x008a, B:18:0x004c, B:20:0x004f, B:25:0x0061, B:26:0x0065, B:27:0x0068, B:30:0x006b, B:32:0x007e, B:33:0x0082, B:35:0x008d, B:37:0x0093, B:39:0x0096, B:40:0x00a7, B:41:0x00c1, B:42:0x00c2, B:43:0x00dc, B:9:0x0012, B:10:0x002f), top: B:54:0x0001, inners: #1, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:37:0x0093 A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:3:0x0001, B:6:0x0009, B:7:0x0010, B:12:0x0031, B:14:0x0041, B:34:0x008a, B:18:0x004c, B:20:0x004f, B:25:0x0061, B:26:0x0065, B:27:0x0068, B:30:0x006b, B:32:0x007e, B:33:0x0082, B:35:0x008d, B:37:0x0093, B:39:0x0096, B:40:0x00a7, B:41:0x00c1, B:42:0x00c2, B:43:0x00dc, B:9:0x0012, B:10:0x002f), top: B:54:0x0001, inners: #1, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:42:0x00c2 A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:3:0x0001, B:6:0x0009, B:7:0x0010, B:12:0x0031, B:14:0x0041, B:34:0x008a, B:18:0x004c, B:20:0x004f, B:25:0x0061, B:26:0x0065, B:27:0x0068, B:30:0x006b, B:32:0x007e, B:33:0x0082, B:35:0x008d, B:37:0x0093, B:39:0x0096, B:40:0x00a7, B:41:0x00c1, B:42:0x00c2, B:43:0x00dc, B:9:0x0012, B:10:0x002f), top: B:54:0x0001, inners: #1, #3 }] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    private static int r(com.luajava.LuaState r12, java.lang.Class<?> r13) {
        /*
            Method dump skipped, instruction units count: 226
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.r(com.luajava.LuaState, java.lang.Class):int");
    }

    private static int s(LuaState luaState, Object obj, String str, boolean z) {
        synchronized (luaState) {
            for (Method method : getMethod(obj.getClass(), "setOn" + str.substring(2) + "Listener", z)) {
                if (!z || Modifier.isStatic(method.getModifiers())) {
                    Class<?>[] parameterTypes = method.getParameterTypes();
                    if (parameterTypes.length == 1 && parameterTypes[0].isInterface()) {
                        luaState.newTable();
                        luaState.pushValue(-2);
                        luaState.setField(-2, str);
                        try {
                            Object objCreateProxy = luaState.getLuaObject(-1).createProxy(parameterTypes[0]);
                            luaState.pop(1);
                            method.invoke(obj, objCreateProxy);
                            return 1;
                        } catch (Exception e2) {
                            throw new LuaException(e2);
                        }
                    }
                }
            }
            return 0;
        }
    }

    public static int setArrayValue(long j, int i2, int i3) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        Object javaObject = existingState.getJavaObject(i2);
        synchronized (existingState) {
            if (javaObject.getClass().isArray()) {
                Class<?> componentType = javaObject.getClass().getComponentType();
                try {
                    Array.set(javaObject, i3, e(existingState, componentType, 3));
                } catch (LuaException unused) {
                    a(existingState, javaObject.getClass().getName() + " [" + i3 + "]", 3, componentType);
                    throw null;
                }
            } else if (javaObject instanceof List) {
                ((List) javaObject).set(i3, existingState.toJavaObject(3));
            } else {
                if (!(javaObject instanceof Map)) {
                    throw new LuaException("can not set " + javaObject.getClass().getName() + " value: " + existingState.toJavaObject(3) + " in " + i3);
                }
                ((Map) javaObject).put(Long.valueOf(i3), existingState.toJavaObject(3));
            }
        }
        return 0;
    }

    public static int setArrayValue(LuaState luaState, Object obj, int i2) {
        synchronized (luaState) {
            if (obj.getClass().isArray()) {
                Class<?> componentType = obj.getClass().getComponentType();
                try {
                    Array.set(obj, i2, e(luaState, componentType, -1));
                } catch (LuaException unused) {
                    a(luaState, obj.getClass().getName() + " [" + i2 + "]", 3, componentType);
                    throw null;
                }
            } else if (obj instanceof List) {
                ((List) obj).set(i2, luaState.toJavaObject(-1));
            } else {
                if (!(obj instanceof Map)) {
                    throw new LuaException("can not set " + obj.getClass().getName() + " value: " + luaState.toJavaObject(-1) + " in " + i2);
                }
                ((Map) obj).put(Long.valueOf(i2), luaState.toJavaObject(-1));
            }
        }
        return 0;
    }

    public static int setFieldValue(LuaState luaState, Object obj, String str) {
        Class<?> cls;
        boolean z;
        synchronized (luaState) {
            if (obj == null) {
                return 0;
            }
            if (obj instanceof Class) {
                cls = (Class) obj;
                z = true;
            } else {
                cls = obj.getClass();
                z = false;
            }
            try {
                Field field = cls.getField(str);
                if (field == null) {
                    return 0;
                }
                if (z && !Modifier.isStatic(field.getModifiers())) {
                    return 0;
                }
                Class<?> type = field.getType();
                try {
                    if (!Modifier.isPublic(field.getModifiers())) {
                        field.setAccessible(true);
                    }
                    field.set(obj, e(luaState, type, luaState.getTop()));
                    return 1;
                } catch (LuaException unused) {
                    a(luaState, str, -1, type);
                    throw null;
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (NoSuchFieldException unused2) {
                return 0;
            }
        }
    }

    private static int t(LuaState luaState, Object obj, String str, boolean z) {
        byte b2;
        HashMap<String, Method> map;
        String str2 = str;
        synchronized (luaState) {
            char c2 = 0;
            char cCharAt = str2.charAt(0);
            if (Character.isLowerCase(cCharAt)) {
                str2 = Character.toUpperCase(cCharAt) + str2.substring(1);
            }
            String str3 = "set" + str2;
            Method method = null;
            String str4 = obj.getClass().getName() + "@->" + str3;
            Object[] objArr = new Object[1];
            int iType = luaState.type(-1);
            if (iType == 1) {
                method = g.get(str4);
                if (method != null) {
                    objArr[0] = Boolean.valueOf(luaState.toBoolean(-1));
                }
                b2 = 1;
            } else if (iType != 3) {
                if (iType != 4) {
                    b2 = -1;
                } else {
                    method = d.get(str4);
                    if (method != null) {
                        objArr[0] = luaState.toString(-1);
                    }
                    b2 = 4;
                }
            } else if (luaState.isInteger(-1)) {
                method = e.get(str4);
                if (method != null) {
                    objArr[0] = LuaState.convertLuaNumber(Long.valueOf(luaState.toInteger(-1)), method.getParameterTypes()[0]);
                }
                b2 = 9;
            } else {
                method = f.get(str4);
                if (method != null) {
                    objArr[0] = LuaState.convertLuaNumber(Double.valueOf(luaState.toNumber(-1)), method.getParameterTypes()[0]);
                }
                b2 = 3;
            }
            if (method != null) {
                try {
                    method.invoke(obj, objArr);
                    return 1;
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            }
            ArrayList<Method> method2 = getMethod(obj.getClass(), str3, z);
            StringBuilder sb = new StringBuilder();
            for (Method method3 : method2) {
                if (!z || Modifier.isStatic(method3.getModifiers())) {
                    Class<?>[] parameterTypes = method3.getParameterTypes();
                    if (parameterTypes.length == 1) {
                        try {
                            Object objE = e(luaState, parameterTypes[c2], luaState.getTop());
                            try {
                                if (b2 == 1) {
                                    map = g;
                                } else if (b2 == 9) {
                                    map = e;
                                } else {
                                    if (b2 != 3) {
                                        if (b2 == 4) {
                                            map = d;
                                        }
                                        method3.invoke(obj, objE);
                                        return 1;
                                    }
                                    map = f;
                                }
                                method3.invoke(obj, objE);
                                return 1;
                            } catch (Exception e3) {
                                throw new LuaException(e3);
                            }
                            map.put(str4, method3);
                        } catch (LuaException unused) {
                            sb.append("-> ");
                            sb.append(parameterTypes[0]);
                            sb.append("\n");
                            c2 = 0;
                        }
                    }
                }
            }
            int top = luaState.getTop();
            if (luaState.type(top) == 5) {
                luaState.getField(1, str3);
                LuaFunction function = luaState.getFunction(-1);
                if (luaState.type(-1) == 6 && function != null) {
                    int iRawLen = luaState.rawLen(top);
                    int i2 = 0;
                    while (i2 < iRawLen) {
                        i2++;
                        luaState.getI(top, i2);
                    }
                    if (luaState.pcall(iRawLen, 0, 0) == 0) {
                        return 1;
                    }
                    throw new LuaException(luaState.toString(-1));
                }
            }
            if (sb.length() <= 0) {
                return 0;
            }
            throw new LuaException("Invalid setter " + str2 + ". Invalid Parameters.\n" + sb.toString() + luaState.toJavaObject(-1).getClass());
        }
    }

    private static int u(LuaState luaState, Object obj, String str) {
        Class<?> superclass;
        boolean z;
        String str2;
        Field declaredField;
        String str3;
        synchronized (luaState) {
            if (obj == null) {
                return 0;
            }
            if (obj instanceof Class) {
                superclass = (Class) obj;
                z = true;
            } else {
                superclass = obj.getClass();
                z = false;
            }
            if (str.startsWith("m")) {
                str2 = null;
                declaredField = null;
            } else {
                char cCharAt = str.charAt(0);
                if (Character.isLowerCase(cCharAt)) {
                    str3 = Character.toUpperCase(cCharAt) + str.substring(1);
                } else {
                    str3 = null;
                }
                str2 = "m" + str3;
                declaredField = null;
            }
            while (superclass != null) {
                try {
                    declaredField = superclass.getDeclaredField(str);
                } catch (NoSuchFieldException unused) {
                    if (str2 != null) {
                        try {
                            declaredField = superclass.getDeclaredField(str2);
                        } catch (NoSuchFieldException unused2) {
                        }
                    }
                }
                if (declaredField != null) {
                    break;
                }
                superclass = superclass.getSuperclass();
            }
            if (declaredField == null) {
                return 0;
            }
            if (z && !Modifier.isStatic(declaredField.getModifiers())) {
                return 0;
            }
            Class<?> type = declaredField.getType();
            try {
                if (!Modifier.isPublic(declaredField.getModifiers())) {
                    declaredField.setAccessible(true);
                }
                declaredField.set(obj, e(luaState, type, luaState.getTop()));
                return 1;
            } catch (LuaException unused3) {
                a(luaState, str, 3, type);
                throw null;
            } catch (Exception e2) {
                throw new LuaException(e2);
            }
        }
    }

    private static int v(LuaState luaState, Class cls, int i2) throws LuaException {
        Object objValueOf;
        char integer;
        if (cls == Character.TYPE && luaState.type(i2) == 4) {
            String string = luaState.toString(i2);
            if (string.length() == 1) {
                integer = string.charAt(0);
                objValueOf = Character.valueOf(integer);
            } else {
                objValueOf = string.toCharArray();
            }
        } else {
            if (!luaState.isNumber(i2)) {
                throw new LuaException(luaState.toString(i2) + " is not number");
            }
            if (cls == Double.TYPE) {
                objValueOf = Double.valueOf(luaState.toNumber(i2));
            } else if (cls == Float.TYPE) {
                objValueOf = Float.valueOf((float) luaState.toNumber(i2));
            } else if (cls == Long.TYPE) {
                objValueOf = Long.valueOf(luaState.toInteger(i2));
            } else if (cls == Integer.TYPE) {
                objValueOf = Integer.valueOf((int) luaState.toInteger(i2));
            } else if (cls == Short.TYPE) {
                objValueOf = Short.valueOf((short) luaState.toInteger(i2));
            } else if (cls == Character.TYPE) {
                integer = (char) luaState.toInteger(i2);
                objValueOf = Character.valueOf(integer);
            } else {
                objValueOf = cls == Byte.TYPE ? Byte.valueOf((byte) luaState.toInteger(i2)) : cls == Boolean.TYPE ? Boolean.valueOf(luaState.toBoolean(i2)) : null;
            }
        }
        luaState.pushJavaObject(objValueOf);
        return 1;
    }

    private static String w(LuaState luaState, int i2) {
        if (luaState.isObject(i2)) {
            return luaState.getObjectFromUserdata(i2).getClass().getName();
        }
        switch (luaState.type(i2)) {
            case 1:
                return "boolean";
            case 2:
            case 7:
                return "userdata";
            case 3:
                return "number";
            case 4:
                return "string";
            case 5:
                return "table";
            case 6:
                return "function";
            case LuaState.LUA_TTHREAD /* 8 */:
                return "thread";
            default:
                return "unkown";
        }
    }
}