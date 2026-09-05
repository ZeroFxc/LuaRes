package com.luajava;

import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.util.Log;
import com.a.a.a.a.a.a.a;
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

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public final class LuaJavaAPI {
    private static final HashMap<Class<?>, HashMap<String, ArrayList<Method>>> a = new HashMap<>();
    public static final HashMap<Class<?>, Method[]> methodsMap = new HashMap<>();
    public static final HashMap<String, Method[]> methodCache = new HashMap<>();
    private static HashMap<String, Method> b = new HashMap<>();
    private static HashMap<String, Method> c = new HashMap<>();
    private static HashMap<String, Method> d = new HashMap<>();
    private static HashMap<String, Method> e = new HashMap<>();
    private static HashMap<String, Method> f = new HashMap<>();

    /* JADX INFO: renamed from: com.luajava.LuaJavaAPI$1 */
    static class AnonymousClass1 implements MethodFilter {
        AnonymousClass1() {
        }

        @Override // com.android.cglib.proxy.MethodFilter
        public boolean filter(Method method, String str) {
            return luaTable.containsKey(str);
        }
    }

    /* JADX INFO: renamed from: com.luajava.LuaJavaAPI$2 */
    static class AnonymousClass2 implements MethodFilter {
        AnonymousClass2() {
        }

        @Override // com.android.cglib.proxy.MethodFilter
        public boolean filter(Method method, String str) {
            return (method.getModifiers() & 1024) == 0;
        }
    }

    private LuaJavaAPI() {
    }

    private static int a(LuaState luaState, Class<?> cls) {
        try {
            EnhancerInterface enhancerInterface = (EnhancerInterface) new LuaEnhancer(cls).create(new MethodFilter() { // from class: com.luajava.LuaJavaAPI.2
                AnonymousClass2() {
                }

                @Override // com.android.cglib.proxy.MethodFilter
                public boolean filter(Method method, String str) {
                    return (method.getModifiers() & 1024) == 0;
                }
            }).newInstance();
            enhancerInterface.setMethodInterceptor_Enhancer(new LuaAbstractMethodInterceptor(luaState.getLuaObject(-1)));
            luaState.pushJavaObject(enhancerInterface);
            return 1;
        } catch (Exception e2) {
            a.a(e2);
            return 0;
        }
    }

    private static int a(LuaState luaState, Object obj) {
        synchronized (luaState) {
            try {
                try {
                    luaState.newTable();
                    if (obj.getClass().isArray()) {
                        int length = Array.getLength(obj);
                        int i = 0;
                        while (i <= length - 1) {
                            a(luaState, Array.get(obj, i));
                            i++;
                            luaState.rawSetI(-2, i);
                        }
                    } else if (obj instanceof Collection) {
                        Iterator it = ((Collection) obj).iterator();
                        int i2 = 1;
                        while (it.hasNext()) {
                            a(luaState, it.next());
                            luaState.rawSetI(-2, i2);
                            i2++;
                        }
                    } else if (obj instanceof Map) {
                        for (Map.Entry entry : ((Map) obj).entrySet()) {
                            luaState.pushObjectValue(entry.getKey());
                            a(luaState, entry.getValue());
                            luaState.setTable(-3);
                        }
                    } else {
                        luaState.pop(1);
                        luaState.pushObjectValue(obj);
                    }
                } catch (Exception e2) {
                    throw new LuaException("can not astable: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    /* JADX WARN: Removed duplicated region for block: B:126:0x0073 A[EDGE_INSN: B:126:0x0073->B:95:0x0073 BREAK  A[LOOP:0: B:86:0x005c->B:94:0x006e], SYNTHETIC] */
    /* JADX WARN: Removed duplicated region for block: B:94:0x006e A[Catch: all -> 0x0006, LOOP:0: B:86:0x005c->B:94:0x006e, LOOP_END, TRY_ENTER, TryCatch #1 {all -> 0x0006, blocks: (B:69:0x0004, B:73:0x0009, B:75:0x000e, B:77:0x001a, B:79:0x0023, B:81:0x002d, B:83:0x0046, B:87:0x005e, B:94:0x006e, B:96:0x0075, B:99:0x0079, B:101:0x0083, B:103:0x0085, B:104:0x0089, B:106:0x0093, B:107:0x0096, B:113:0x00ad, B:110:0x00a3, B:111:0x00a8, B:112:0x00a9, B:90:0x0066, B:76:0x0014), top: B:118:0x0002, inners: #5 }] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    private static int a(com.luajava.LuaState r9, java.lang.Object r10, java.lang.String r11) {
        /*
            monitor-enter(r9)
            r0 = 0
            if (r10 != 0) goto L9
            monitor-exit(r9)     // Catch: java.lang.Throwable -> L6
            return r0
        L6:
            r10 = move-exception
            goto Laf
        L9:
            boolean r1 = r10 instanceof java.lang.Class     // Catch: java.lang.Throwable -> L6
            r2 = 1
            if (r1 == 0) goto L14
            r1 = r10
            java.lang.Class r1 = (java.lang.Class) r1     // Catch: java.lang.Throwable -> L6
            r3 = r1
            r1 = 1
            goto L1a
        L14:
            java.lang.Class r1 = r10.getClass()     // Catch: java.lang.Throwable -> L6
            r3 = r1
            r1 = 0
        L1a:
            java.lang.String r4 = "m"
            boolean r4 = r11.startsWith(r4)     // Catch: java.lang.Throwable -> L6
            r5 = 0
            if (r4 != 0) goto L5b
            char r4 = r11.charAt(r0)     // Catch: java.lang.Throwable -> L6
            boolean r6 = java.lang.Character.isLowerCase(r4)     // Catch: java.lang.Throwable -> L6
            if (r6 == 0) goto L45
            java.lang.StringBuilder r6 = new java.lang.StringBuilder     // Catch: java.lang.Throwable -> L6
            r6.<init>()     // Catch: java.lang.Throwable -> L6
            char r4 = java.lang.Character.toUpperCase(r4)     // Catch: java.lang.Throwable -> L6
            r6.append(r4)     // Catch: java.lang.Throwable -> L6
            java.lang.String r4 = r11.substring(r2)     // Catch: java.lang.Throwable -> L6
            r6.append(r4)     // Catch: java.lang.Throwable -> L6
            java.lang.String r4 = r6.toString()     // Catch: java.lang.Throwable -> L6
            goto L46
        L45:
            r4 = r5
        L46:
            java.lang.StringBuilder r6 = new java.lang.StringBuilder     // Catch: java.lang.Throwable -> L6
            r6.<init>()     // Catch: java.lang.Throwable -> L6
            java.lang.String r7 = "m"
            r6.append(r7)     // Catch: java.lang.Throwable -> L6
            r6.append(r4)     // Catch: java.lang.Throwable -> L6
            java.lang.String r4 = r6.toString()     // Catch: java.lang.Throwable -> L6
            r8 = r5
            r5 = r4
            r4 = r8
            goto L5c
        L5b:
            r4 = r5
        L5c:
            if (r3 == 0) goto L73
            java.lang.reflect.Field r6 = r3.getDeclaredField(r11)     // Catch: java.lang.Throwable -> L6 java.lang.NoSuchFieldException -> L64
        L62:
            r4 = r6
            goto L6b
        L64:
            if (r5 == 0) goto L6b
            java.lang.reflect.Field r6 = r3.getDeclaredField(r5)     // Catch: java.lang.Throwable -> L6 java.lang.NoSuchFieldException -> L6b
            goto L62
        L6b:
            if (r4 == 0) goto L6e
            goto L73
        L6e:
            java.lang.Class r3 = r3.getSuperclass()     // Catch: java.lang.Throwable -> L6
            goto L5c
        L73:
            if (r4 != 0) goto L77
            monitor-exit(r9)     // Catch: java.lang.Throwable -> L6
            return r0
        L77:
            if (r1 == 0) goto L85
            int r1 = r4.getModifiers()     // Catch: java.lang.Throwable -> L6
            boolean r1 = java.lang.reflect.Modifier.isStatic(r1)     // Catch: java.lang.Throwable -> L6
            if (r1 != 0) goto L85
            monitor-exit(r9)     // Catch: java.lang.Throwable -> L6
            return r0
        L85:
            java.lang.Class r0 = r4.getType()     // Catch: java.lang.Throwable -> L6
            int r1 = r4.getModifiers()     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
            boolean r1 = java.lang.reflect.Modifier.isPublic(r1)     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
            if (r1 != 0) goto L96
            r4.setAccessible(r2)     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
        L96:
            int r1 = r9.getTop()     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
            java.lang.Object r1 = e(r9, r0, r1)     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
            r4.set(r10, r1)     // Catch: java.lang.Throwable -> L6 java.lang.Exception -> La2 com.luajava.LuaException -> La9
            goto Lad
        La2:
            r10 = move-exception
            com.luajava.LuaException r11 = new com.luajava.LuaException     // Catch: java.lang.Throwable -> L6
            r11.<init>(r10)     // Catch: java.lang.Throwable -> L6
            throw r11     // Catch: java.lang.Throwable -> L6
        La9:
            r10 = 3
            a(r9, r11, r10, r0)     // Catch: java.lang.Throwable -> L6
        Lad:
            monitor-exit(r9)     // Catch: java.lang.Throwable -> L6
            return r2
        Laf:
            monitor-exit(r9)     // Catch: java.lang.Throwable -> L6
            throw r10
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.a(com.luajava.LuaState, java.lang.Object, java.lang.String):int");
    }

    private static int a(LuaState luaState, Object obj, String str, boolean z) {
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

    private static int a(LuaState luaState, String str) {
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

    private static Object a(LuaState luaState, Class cls, int i) {
        Object objCreateProxy;
        synchronized (luaState) {
            try {
                try {
                    objCreateProxy = luaState.getLuaObject(i).createProxy(cls);
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return objCreateProxy;
    }

    /* JADX WARN: Removed duplicated region for block: B:176:0x009d  */
    /* JADX WARN: Removed duplicated region for block: B:191:0x00de A[PHI: r0
  0x00de: PHI (r0v3 java.lang.Object) = 
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v0 java.lang.Object)
  (r0v12 java.lang.Object)
 binds: [B:209:0x012a, B:196:0x00f1, B:190:0x00dc, B:187:0x00d3, B:172:0x0092, B:166:0x007d, B:163:0x0072] A[DONT_GENERATE, DONT_INLINE]] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    private static java.lang.Object a(com.luajava.LuaState r3, java.lang.Class<?> r4, int r5, int r6) throws com.luajava.LuaException {
        /*
            Method dump skipped, instruction units count: 338
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.a(com.luajava.LuaState, java.lang.Class, int, int):java.lang.Object");
    }

    private static String a(LuaState luaState, int i) {
        if (luaState.isObject(i)) {
            return luaState.getObjectFromUserdata(i).getClass().getName();
        }
        switch (luaState.type(i)) {
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
            case 8:
                return "thread";
            default:
                return "unkown";
        }
    }

    private static String a(LuaState luaState, String str, int i, Class cls) throws LuaException {
        throw new LuaException("bad argument to '" + str + "' (" + cls.getName() + " expected, got " + a(luaState, i) + " value)");
    }

    private static String a(LuaState luaState, String str, int i, String str2) throws LuaException {
        throw new LuaException("bad argument #" + i + " to '" + str + "' (" + str2 + " expected, got " + a(luaState, i + 1) + " value)");
    }

    public static int asTable(long j, Object obj) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (existingState.isBoolean(-1) && existingState.toBoolean(-1)) {
                existingState.pop(1);
                return a(existingState, obj);
            }
            try {
                existingState.newTable();
                if (obj.getClass().isArray()) {
                    int length = Array.getLength(obj);
                    int i = 0;
                    while (i <= length - 1) {
                        existingState.pushObjectValue(Array.get(obj, i));
                        i++;
                        existingState.rawSetI(-2, i);
                    }
                } else if (obj instanceof Collection) {
                    Iterator it = ((Collection) obj).iterator();
                    int i2 = 1;
                    while (it.hasNext()) {
                        existingState.pushObjectValue(it.next());
                        existingState.rawSetI(-2, i2);
                        i2++;
                    }
                } else if (obj instanceof Map) {
                    for (Map.Entry entry : ((Map) obj).entrySet()) {
                        existingState.pushObjectValue(entry.getKey());
                        existingState.pushObjectValue(entry.getValue());
                        existingState.setTable(-3);
                    }
                }
                existingState.pushValue(-1);
                return 1;
            } catch (Exception e2) {
                throw new LuaException("can not astable: " + e2.getMessage());
            }
        }
    }

    /* JADX WARN: Removed duplicated region for block: B:100:0x0093 A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:66:0x0001, B:69:0x0009, B:70:0x0010, B:75:0x0031, B:77:0x0041, B:97:0x008a, B:81:0x004c, B:83:0x004f, B:88:0x0061, B:89:0x0065, B:90:0x0068, B:93:0x006b, B:95:0x007e, B:96:0x0082, B:98:0x008d, B:100:0x0093, B:101:0x00ad, B:102:0x00ae, B:104:0x00b1, B:105:0x00c2, B:106:0x00dc, B:72:0x0012, B:73:0x002f), top: B:115:0x0001, inners: #1, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:102:0x00ae A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:66:0x0001, B:69:0x0009, B:70:0x0010, B:75:0x0031, B:77:0x0041, B:97:0x008a, B:81:0x004c, B:83:0x004f, B:88:0x0061, B:89:0x0065, B:90:0x0068, B:93:0x006b, B:95:0x007e, B:96:0x0082, B:98:0x008d, B:100:0x0093, B:101:0x00ad, B:102:0x00ae, B:104:0x00b1, B:105:0x00c2, B:106:0x00dc, B:72:0x0012, B:73:0x002f), top: B:115:0x0001, inners: #1, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:77:0x0041 A[Catch: all -> 0x00dd, TryCatch #2 {, blocks: (B:66:0x0001, B:69:0x0009, B:70:0x0010, B:75:0x0031, B:77:0x0041, B:97:0x008a, B:81:0x004c, B:83:0x004f, B:88:0x0061, B:89:0x0065, B:90:0x0068, B:93:0x006b, B:95:0x007e, B:96:0x0082, B:98:0x008d, B:100:0x0093, B:101:0x00ad, B:102:0x00ae, B:104:0x00b1, B:105:0x00c2, B:106:0x00dc, B:72:0x0012, B:73:0x002f), top: B:115:0x0001, inners: #1, #3 }] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    private static int b(com.luajava.LuaState r12, java.lang.Class<?> r13) {
        /*
            Method dump skipped, instruction units count: 224
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.b(com.luajava.LuaState, java.lang.Class):int");
    }

    /* JADX WARN: Failed to find 'out' block for switch in B:158:0x012c. Please report as an issue. */
    private static int b(LuaState luaState, Object obj, String str, boolean z) {
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
            if (iType != 1) {
                switch (iType) {
                    case 3:
                        if (luaState.isInteger(-1)) {
                            method = c.get(str4);
                            if (method != null) {
                                objArr[0] = LuaState.convertLuaNumber(Long.valueOf(luaState.toInteger(-1)), method.getParameterTypes()[0]);
                            }
                            b2 = 9;
                        } else {
                            Method method2 = d.get(str4);
                            if (method2 != null) {
                                objArr[0] = LuaState.convertLuaNumber(Double.valueOf(luaState.toNumber(-1)), method2.getParameterTypes()[0]);
                            }
                            method = method2;
                            b2 = 3;
                        }
                        break;
                    case 4:
                        Method method3 = b.get(str4);
                        if (method3 != null) {
                            objArr[0] = luaState.toString(-1);
                        }
                        method = method3;
                        b2 = 4;
                        break;
                    default:
                        b2 = -1;
                        break;
                }
            } else {
                method = e.get(str4);
                if (method != null) {
                    objArr[0] = Boolean.valueOf(luaState.toBoolean(-1));
                }
                b2 = 1;
            }
            if (method != null) {
                try {
                    method.invoke(obj, objArr);
                    return 1;
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            }
            ArrayList<Method> method4 = getMethod(obj.getClass(), str3, z);
            StringBuilder sb = new StringBuilder();
            for (Method method5 : method4) {
                if (!z || Modifier.isStatic(method5.getModifiers())) {
                    Class<?>[] parameterTypes = method5.getParameterTypes();
                    if (parameterTypes.length == 1) {
                        try {
                            Object objE = e(luaState, parameterTypes[c2], luaState.getTop());
                            try {
                                if (b2 == 1) {
                                    map = e;
                                } else {
                                    if (b2 != 9) {
                                        switch (b2) {
                                            case 3:
                                                map = d;
                                                break;
                                            case 4:
                                                map = b;
                                                break;
                                        }
                                        method5.invoke(obj, objE);
                                        return 1;
                                    }
                                    map = c;
                                }
                                method5.invoke(obj, objE);
                                return 1;
                            } catch (Exception e3) {
                                throw new LuaException(e3);
                            }
                            map.put(str4, method5);
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
                    int i = 0;
                    while (i < iRawLen) {
                        i++;
                        luaState.getI(top, i);
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

    private static Object b(LuaState luaState, Class<?> cls, int i) {
        Object objNewInstance;
        synchronized (luaState) {
            try {
                try {
                    int iObjLen = luaState.objLen(i);
                    objNewInstance = Array.newInstance(cls, iObjLen);
                    if (cls == String.class) {
                        for (int i2 = 1; i2 <= iObjLen; i2++) {
                            luaState.pushNumber(i2);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i2 - 1, luaState.toString(-1));
                            luaState.pop(1);
                        }
                    } else if (cls == Double.TYPE) {
                        for (int i3 = 1; i3 <= iObjLen; i3++) {
                            luaState.pushNumber(i3);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i3 - 1, Double.valueOf(luaState.toNumber(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Float.TYPE) {
                        for (int i4 = 1; i4 <= iObjLen; i4++) {
                            luaState.pushNumber(i4);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i4 - 1, Float.valueOf((float) luaState.toNumber(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Long.TYPE) {
                        for (int i5 = 1; i5 <= iObjLen; i5++) {
                            luaState.pushNumber(i5);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i5 - 1, Long.valueOf(luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Integer.TYPE) {
                        for (int i6 = 1; i6 <= iObjLen; i6++) {
                            luaState.pushNumber(i6);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i6 - 1, Integer.valueOf((int) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Short.TYPE) {
                        for (int i7 = 1; i7 <= iObjLen; i7++) {
                            luaState.pushNumber(i7);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i7 - 1, Short.valueOf((short) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Character.TYPE) {
                        for (int i8 = 1; i8 <= iObjLen; i8++) {
                            luaState.pushNumber(i8);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i8 - 1, Character.valueOf((char) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else if (cls == Byte.TYPE) {
                        for (int i9 = 1; i9 <= iObjLen; i9++) {
                            luaState.pushNumber(i9);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i9 - 1, Byte.valueOf((byte) luaState.toInteger(-1)));
                            luaState.pop(1);
                        }
                    } else {
                        for (int i10 = 1; i10 <= iObjLen; i10++) {
                            luaState.pushNumber(i10);
                            luaState.getTable(i);
                            Array.set(objNewInstance, i10 - 1, e(luaState, cls, luaState.getTop()));
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

    private static int c(LuaState luaState, Class cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(a(luaState, cls, 2));
        }
        return 1;
    }

    private static Object c(LuaState luaState, Class<List<Object>> cls, int i) {
        List<Object> arrayList;
        synchronized (luaState) {
            int iObjLen = luaState.objLen(i);
            try {
                arrayList = cls.equals(List.class) ? new ArrayList<>() : cls.newInstance();
                for (int i2 = 1; i2 <= iObjLen; i2++) {
                    luaState.pushNumber(i2);
                    luaState.getTable(i);
                    arrayList.add(luaState.toJavaObject(-1));
                    luaState.pop(1);
                }
            } catch (Exception e2) {
                throw new LuaException(e2);
            }
        }
        return arrayList;
    }

    /* JADX WARN: Removed duplicated region for block: B:184:0x007e A[Catch: all -> 0x0277, TryCatch #4 {, blocks: (B:162:0x0009, B:164:0x0018, B:166:0x0022, B:168:0x002a, B:170:0x0036, B:172:0x0038, B:173:0x003b, B:176:0x003e, B:178:0x0052, B:179:0x0056, B:180:0x0078, B:182:0x007a, B:184:0x007e, B:186:0x0084, B:204:0x00fe, B:206:0x0108, B:207:0x010b, B:209:0x0111, B:211:0x011d, B:213:0x011f, B:214:0x0122, B:223:0x0161, B:225:0x016e, B:226:0x0178, B:228:0x017c, B:278:0x021c, B:233:0x018e, B:235:0x0191, B:237:0x0195, B:239:0x019b, B:246:0x01b4, B:249:0x01bf, B:274:0x01fd, B:276:0x0210, B:277:0x0214, B:253:0x01c8, B:256:0x01d0, B:257:0x01d2, B:258:0x01d6, B:259:0x01d9, B:260:0x01dc, B:261:0x01df, B:263:0x01e4, B:265:0x01f0, B:268:0x01f3, B:269:0x01f6, B:279:0x0226, B:281:0x022d, B:282:0x0247, B:283:0x0248, B:285:0x024b, B:286:0x025c, B:287:0x0276, B:217:0x0125, B:219:0x0139, B:220:0x013d, B:221:0x015f, B:188:0x008d, B:190:0x0098, B:191:0x009f, B:193:0x00a5, B:195:0x00b1, B:196:0x00c6, B:198:0x00d1, B:199:0x00e6, B:201:0x00f0), top: B:302:0x0009, inners: #0, #6 }] */
    /* JADX WARN: Removed duplicated region for block: B:222:0x0160  */
    /* JADX WARN: Removed duplicated region for block: B:225:0x016e A[Catch: all -> 0x0277, LOOP:0: B:224:0x016c->B:225:0x016e, LOOP_END, TryCatch #4 {, blocks: (B:162:0x0009, B:164:0x0018, B:166:0x0022, B:168:0x002a, B:170:0x0036, B:172:0x0038, B:173:0x003b, B:176:0x003e, B:178:0x0052, B:179:0x0056, B:180:0x0078, B:182:0x007a, B:184:0x007e, B:186:0x0084, B:204:0x00fe, B:206:0x0108, B:207:0x010b, B:209:0x0111, B:211:0x011d, B:213:0x011f, B:214:0x0122, B:223:0x0161, B:225:0x016e, B:226:0x0178, B:228:0x017c, B:278:0x021c, B:233:0x018e, B:235:0x0191, B:237:0x0195, B:239:0x019b, B:246:0x01b4, B:249:0x01bf, B:274:0x01fd, B:276:0x0210, B:277:0x0214, B:253:0x01c8, B:256:0x01d0, B:257:0x01d2, B:258:0x01d6, B:259:0x01d9, B:260:0x01dc, B:261:0x01df, B:263:0x01e4, B:265:0x01f0, B:268:0x01f3, B:269:0x01f6, B:279:0x0226, B:281:0x022d, B:282:0x0247, B:283:0x0248, B:285:0x024b, B:286:0x025c, B:287:0x0276, B:217:0x0125, B:219:0x0139, B:220:0x013d, B:221:0x015f, B:188:0x008d, B:190:0x0098, B:191:0x009f, B:193:0x00a5, B:195:0x00b1, B:196:0x00c6, B:198:0x00d1, B:199:0x00e6, B:201:0x00f0), top: B:302:0x0009, inners: #0, #6 }] */
    /* JADX WARN: Removed duplicated region for block: B:228:0x017c A[Catch: all -> 0x0277, TryCatch #4 {, blocks: (B:162:0x0009, B:164:0x0018, B:166:0x0022, B:168:0x002a, B:170:0x0036, B:172:0x0038, B:173:0x003b, B:176:0x003e, B:178:0x0052, B:179:0x0056, B:180:0x0078, B:182:0x007a, B:184:0x007e, B:186:0x0084, B:204:0x00fe, B:206:0x0108, B:207:0x010b, B:209:0x0111, B:211:0x011d, B:213:0x011f, B:214:0x0122, B:223:0x0161, B:225:0x016e, B:226:0x0178, B:228:0x017c, B:278:0x021c, B:233:0x018e, B:235:0x0191, B:237:0x0195, B:239:0x019b, B:246:0x01b4, B:249:0x01bf, B:274:0x01fd, B:276:0x0210, B:277:0x0214, B:253:0x01c8, B:256:0x01d0, B:257:0x01d2, B:258:0x01d6, B:259:0x01d9, B:260:0x01dc, B:261:0x01df, B:263:0x01e4, B:265:0x01f0, B:268:0x01f3, B:269:0x01f6, B:279:0x0226, B:281:0x022d, B:282:0x0247, B:283:0x0248, B:285:0x024b, B:286:0x025c, B:287:0x0276, B:217:0x0125, B:219:0x0139, B:220:0x013d, B:221:0x015f, B:188:0x008d, B:190:0x0098, B:191:0x009f, B:193:0x00a5, B:195:0x00b1, B:196:0x00c6, B:198:0x00d1, B:199:0x00e6, B:201:0x00f0), top: B:302:0x0009, inners: #0, #6 }] */
    /* JADX WARN: Removed duplicated region for block: B:231:0x0189 A[PHI: r16 r17
  0x0189: PHI (r16v7 int) = (r16v1 int), (r16v8 int) binds: [B:245:0x01b2, B:230:0x0185] A[DONT_GENERATE, DONT_INLINE]
  0x0189: PHI (r17v6 int[]) = (r17v1 int[]), (r17v7 int[]) binds: [B:245:0x01b2, B:230:0x0185] A[DONT_GENERATE, DONT_INLINE]] */
    /* JADX WARN: Removed duplicated region for block: B:281:0x022d A[Catch: all -> 0x0277, TryCatch #4 {, blocks: (B:162:0x0009, B:164:0x0018, B:166:0x0022, B:168:0x002a, B:170:0x0036, B:172:0x0038, B:173:0x003b, B:176:0x003e, B:178:0x0052, B:179:0x0056, B:180:0x0078, B:182:0x007a, B:184:0x007e, B:186:0x0084, B:204:0x00fe, B:206:0x0108, B:207:0x010b, B:209:0x0111, B:211:0x011d, B:213:0x011f, B:214:0x0122, B:223:0x0161, B:225:0x016e, B:226:0x0178, B:228:0x017c, B:278:0x021c, B:233:0x018e, B:235:0x0191, B:237:0x0195, B:239:0x019b, B:246:0x01b4, B:249:0x01bf, B:274:0x01fd, B:276:0x0210, B:277:0x0214, B:253:0x01c8, B:256:0x01d0, B:257:0x01d2, B:258:0x01d6, B:259:0x01d9, B:260:0x01dc, B:261:0x01df, B:263:0x01e4, B:265:0x01f0, B:268:0x01f3, B:269:0x01f6, B:279:0x0226, B:281:0x022d, B:282:0x0247, B:283:0x0248, B:285:0x024b, B:286:0x025c, B:287:0x0276, B:217:0x0125, B:219:0x0139, B:220:0x013d, B:221:0x015f, B:188:0x008d, B:190:0x0098, B:191:0x009f, B:193:0x00a5, B:195:0x00b1, B:196:0x00c6, B:198:0x00d1, B:199:0x00e6, B:201:0x00f0), top: B:302:0x0009, inners: #0, #6 }] */
    /* JADX WARN: Removed duplicated region for block: B:283:0x0248 A[Catch: all -> 0x0277, TryCatch #4 {, blocks: (B:162:0x0009, B:164:0x0018, B:166:0x0022, B:168:0x002a, B:170:0x0036, B:172:0x0038, B:173:0x003b, B:176:0x003e, B:178:0x0052, B:179:0x0056, B:180:0x0078, B:182:0x007a, B:184:0x007e, B:186:0x0084, B:204:0x00fe, B:206:0x0108, B:207:0x010b, B:209:0x0111, B:211:0x011d, B:213:0x011f, B:214:0x0122, B:223:0x0161, B:225:0x016e, B:226:0x0178, B:228:0x017c, B:278:0x021c, B:233:0x018e, B:235:0x0191, B:237:0x0195, B:239:0x019b, B:246:0x01b4, B:249:0x01bf, B:274:0x01fd, B:276:0x0210, B:277:0x0214, B:253:0x01c8, B:256:0x01d0, B:257:0x01d2, B:258:0x01d6, B:259:0x01d9, B:260:0x01dc, B:261:0x01df, B:263:0x01e4, B:265:0x01f0, B:268:0x01f3, B:269:0x01f6, B:279:0x0226, B:281:0x022d, B:282:0x0247, B:283:0x0248, B:285:0x024b, B:286:0x025c, B:287:0x0276, B:217:0x0125, B:219:0x0139, B:220:0x013d, B:221:0x015f, B:188:0x008d, B:190:0x0098, B:191:0x009f, B:193:0x00a5, B:195:0x00b1, B:196:0x00c6, B:198:0x00d1, B:199:0x00e6, B:201:0x00f0), top: B:302:0x0009, inners: #0, #6 }] */
    /* JADX WARN: Removed duplicated region for block: B:298:0x01b4 A[EXC_TOP_SPLITTER, SYNTHETIC] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static int callMethod(long r19, java.lang.Object r21, java.lang.String r22) {
        /*
            Method dump skipped, instruction units count: 666
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.callMethod(long, java.lang.Object, java.lang.String):int");
    }

    public static int checkClass(LuaState luaState, Object obj, String str) {
        synchronized (luaState) {
            if (!(obj instanceof Class)) {
                return 0;
            }
            for (Class<?> cls : ((Class) obj).getClasses()) {
                if (cls.getSimpleName().equals(str)) {
                    luaState.pushJavaObject(cls);
                    return 3;
                }
            }
            return 0;
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
            String string = luaState.toString(-1);
            Method[] methodArr = methodCache.get(string);
            if (methodArr == null) {
                ArrayList<Method> method = getMethod(cls, str, z);
                methodArr = new Method[method.size()];
                method.toArray(methodArr);
                methodCache.put(string, methodArr);
            }
            return methodArr.length == 0 ? 0 : 2;
        }
    }

    public static void clearCaches() {
        methodCache.clear();
        methodsMap.clear();
        b.clear();
        c.clear();
        d.clear();
        e.clear();
        f.clear();
    }

    public static int createArray(long j, String str) {
        int iD;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            iD = d(existingState, javaBindClass(str));
        }
        return iD;
    }

    public static int createProxy(long j, String str) {
        int iA;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            iA = a(existingState, str);
        }
        return iA;
    }

    private static int d(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(b(luaState, cls, 2));
        }
        return 1;
    }

    private static Object d(LuaState luaState, Class<Map<Object, Object>> cls, int i) {
        Map<Object, Object> map;
        synchronized (luaState) {
            try {
                try {
                    map = cls.equals(Map.class) ? new HashMap<>() : cls.newInstance();
                    luaState.pushNil();
                    while (luaState.next(i) != 0) {
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

    private static int e(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(c(luaState, cls, 2));
        }
        return 1;
    }

    private static Object e(LuaState luaState, Class<?> cls, int i) {
        return a(luaState, cls, luaState.type(i), i);
    }

    private static int f(LuaState luaState, Class<?> cls) {
        synchronized (luaState) {
            luaState.pushJavaObject(d(luaState, cls, 2));
        }
        return 1;
    }

    private static int f(LuaState luaState, Class cls, int i) throws LuaException {
        Object objValueOf;
        char integer;
        if (cls == Character.TYPE && luaState.type(i) == 4) {
            String string = luaState.toString(i);
            if (string.length() == 1) {
                integer = string.charAt(0);
                objValueOf = Character.valueOf(integer);
            } else {
                objValueOf = string.toCharArray();
            }
        } else {
            if (!luaState.isNumber(i)) {
                throw new LuaException(luaState.toString(i) + " is not number");
            }
            if (cls == Double.TYPE) {
                objValueOf = Double.valueOf(luaState.toNumber(i));
            } else if (cls == Float.TYPE) {
                objValueOf = Float.valueOf((float) luaState.toNumber(i));
            } else if (cls == Long.TYPE) {
                objValueOf = Long.valueOf(luaState.toInteger(i));
            } else if (cls == Integer.TYPE) {
                objValueOf = Integer.valueOf((int) luaState.toInteger(i));
            } else if (cls == Short.TYPE) {
                objValueOf = Short.valueOf((short) luaState.toInteger(i));
            } else if (cls == Character.TYPE) {
                integer = (char) luaState.toInteger(i);
                objValueOf = Character.valueOf(integer);
            } else {
                objValueOf = cls == Byte.TYPE ? Byte.valueOf((byte) luaState.toInteger(i)) : cls == Boolean.TYPE ? Boolean.valueOf(luaState.toBoolean(i)) : null;
            }
        }
        luaState.pushJavaObject(objValueOf);
        return 1;
    }

    public static int getArrayValue(long j, Object obj, int i) {
        Object obj2;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (obj.getClass().isArray()) {
                obj2 = Array.get(obj, i);
            } else if (obj instanceof List) {
                obj2 = ((List) obj).get(i);
            } else {
                if (!(obj instanceof Map)) {
                    throw new LuaException("can not get " + obj.getClass().getName() + " value in " + i);
                }
                obj2 = ((Map) obj).get(Long.valueOf(i));
            }
            existingState.pushObjectValue(obj2);
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

    public static ArrayList<Method> getMethod(Class<?> cls, String str, boolean z) {
        HashMap<String, ArrayList<Method>> map = a.get(cls);
        if (map == null) {
            map = new HashMap<>();
            a.put(cls, map);
        }
        ArrayList<Method> arrayList = map.get(str);
        if (arrayList == null) {
            Method[] methods = methodsMap.get(cls);
            if (methods == null) {
                methods = cls.getMethods();
                methodsMap.put(cls, methods);
            }
            for (Method method : methods) {
                String name = method.getName();
                ArrayList<Method> arrayList2 = map.get(name);
                if (arrayList2 == null) {
                    arrayList2 = new ArrayList<>();
                    map.put(name, arrayList2);
                }
                arrayList2.add(method);
            }
            arrayList = map.get(str);
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

    public static Class javaBindClass(String str) throws LuaException {
        try {
            return Class.forName(str);
        } catch (Exception unused) {
            switch (str) {
                case "boolean":
                    return Boolean.TYPE;
                case "byte":
                    return Byte.TYPE;
                case "char":
                    return Character.TYPE;
                case "short":
                    return Short.TYPE;
                case "int":
                    return Integer.TYPE;
                case "long":
                    return Long.TYPE;
                case "float":
                    return Float.TYPE;
                case "double":
                    return Double.TYPE;
                default:
                    throw new LuaException("Class not found: " + str);
            }
        }
    }

    public static int javaCreate(long j, Class<?> cls) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (!cls.isPrimitive() && cls != String.class) {
                if (cls.isArray()) {
                    return d(existingState, cls);
                }
                if (List.class.isAssignableFrom(cls)) {
                    return e(existingState, cls);
                }
                if (Map.class.isAssignableFrom(cls)) {
                    return f(existingState, cls);
                }
                if (cls.isInterface()) {
                    return c(existingState, cls);
                }
                if ((cls.getModifiers() & 1024) != 0) {
                    return a(existingState, cls);
                }
                if (existingState.objLen(-1) == 0) {
                    return d(existingState, cls);
                }
                existingState.getI(-1, 1L);
                Object javaObject = existingState.toJavaObject(-1);
                existingState.pop(1);
                if (cls.isAssignableFrom(javaObject.getClass())) {
                    return d(existingState, cls);
                }
                return b(existingState, cls);
            }
            return d(existingState, cls);
        }
    }

    public static int javaEquals(long j, Object obj, Object obj2) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            existingState.pushBoolean(obj.equals(obj2));
        }
        return 1;
    }

    public static void javaGc(Object obj) {
        Bitmap bitmap;
        Log.i("javaGc: ", obj + "");
        if (obj == null) {
            return;
        }
        try {
            if (obj instanceof LuaGcable) {
                ((LuaGcable) obj).gc();
                return;
            }
            if (obj instanceof Bitmap) {
                LuaBitmap.removeBitmap((Bitmap) obj);
                bitmap = (Bitmap) obj;
            } else {
                if (!(obj instanceof BitmapDrawable)) {
                    if (obj instanceof AutoCloseable) {
                        ((AutoCloseable) obj).close();
                        return;
                    }
                    return;
                }
                bitmap = ((BitmapDrawable) obj).getBitmap();
            }
            bitmap.recycle();
        } catch (Exception e2) {
            a.a(e2);
        }
    }

    public static int javaGetType(long j, Object obj) {
        String name;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (obj == null) {
                name = "null";
            } else {
                try {
                    name = obj.getClass().getName();
                } catch (Throwable th) {
                    throw th;
                }
            }
            existingState.pushString(name);
        }
        return 1;
    }

    /* JADX WARN: Removed duplicated region for block: B:86:0x00b6 A[Catch: all -> 0x00ca, TryCatch #2 {, blocks: (B:55:0x0002, B:57:0x0007, B:58:0x0010, B:60:0x0012, B:62:0x0017, B:64:0x0021, B:66:0x002b, B:67:0x0042, B:69:0x005c, B:71:0x0066, B:76:0x0098, B:78:0x00a2, B:80:0x00a4, B:83:0x00ac, B:84:0x00b2, B:86:0x00b6, B:88:0x00c1, B:87:0x00be, B:91:0x00c4, B:92:0x00c9, B:73:0x007e, B:81:0x00aa, B:63:0x001c), top: B:98:0x0002, inners: #0, #3 }] */
    /* JADX WARN: Removed duplicated region for block: B:87:0x00be A[Catch: all -> 0x00ca, TryCatch #2 {, blocks: (B:55:0x0002, B:57:0x0007, B:58:0x0010, B:60:0x0012, B:62:0x0017, B:64:0x0021, B:66:0x002b, B:67:0x0042, B:69:0x005c, B:71:0x0066, B:76:0x0098, B:78:0x00a2, B:80:0x00a4, B:83:0x00ac, B:84:0x00b2, B:86:0x00b6, B:88:0x00c1, B:87:0x00be, B:91:0x00c4, B:92:0x00c9, B:73:0x007e, B:81:0x00aa, B:63:0x001c), top: B:98:0x0002, inners: #0, #3 }] */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static int javaGetter(com.luajava.LuaState r7, java.lang.Object r8, java.lang.String r9) throws java.lang.NoSuchMethodException {
        /*
            Method dump skipped, instruction units count: 205
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.luajava.LuaJavaAPI.javaGetter(com.luajava.LuaState, java.lang.Object, java.lang.String):int");
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

    public static int javaNew(long j, Class<?> cls) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (cls.isPrimitive()) {
                int top = existingState.getTop();
                for (int i = 2; i <= top; i++) {
                    f(existingState, cls, i);
                }
                return top - 1;
            }
            if ((cls.getModifiers() & 1024) == 0) {
                return b(existingState, cls);
            }
            if (!existingState.isTable(2)) {
                a(existingState, "javaOverride", 1, "table");
            }
            return javaOverride(j, cls);
        }
    }

    public static int javaNewInstance(long j, String str) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            Class clsJavaBindClass = javaBindClass(str);
            if (clsJavaBindClass.isPrimitive()) {
                return f(existingState, clsJavaBindClass, -1);
            }
            return b(existingState, clsJavaBindClass);
        }
    }

    public static int javaObjectLength(long j, Object obj) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            try {
                try {
                    existingState.pushInteger(obj instanceof CharSequence ? ((CharSequence) obj).length() : obj instanceof Collection ? ((Collection) obj).size() : obj instanceof Map ? ((Map) obj).size() : Array.getLength(obj));
                } catch (Exception e2) {
                    throw new LuaException(e2);
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int javaOverride(long j, Class<?> cls) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            LuaTable luaTable = new LuaTable(existingState, 2);
            existingState.remove(2);
            if (b(existingState, new LuaEnhancer(cls).create(new MethodFilter() { // from class: com.luajava.LuaJavaAPI.1
                AnonymousClass1() {
                }

                @Override // com.android.cglib.proxy.MethodFilter
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
                return a(luaState, obj, str, z);
            }
            int iB = b(luaState, obj, str, z);
            if (iB != 0) {
                return iB;
            }
            return a(luaState, obj, str);
        }
    }

    public static int javaSetter(LuaState luaState, Object obj, String str, Object obj2) {
        luaState.pushObjectValue(obj2);
        int iJavaSetter = javaSetter(luaState, obj, str);
        luaState.pop(1);
        return iJavaSetter;
    }

    public static int javaToString(long j, Object obj) {
        String string;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (obj == null) {
                string = "null";
            } else {
                try {
                    string = obj.toString();
                } catch (Throwable th) {
                    throw th;
                }
            }
            existingState.pushString(string);
        }
        return 1;
    }

    public static int newArray(long j, Class<?> cls) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            try {
                try {
                    int top = existingState.getTop() - 1;
                    int[] iArr = new int[top];
                    for (int i = 0; i < top; i++) {
                        iArr[i] = (int) existingState.toInteger(i + 2);
                    }
                    existingState.pushJavaObject(Array.newInstance(cls, iArr));
                } catch (Exception e2) {
                    throw new LuaException("can not create a array: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int newArray(long j, Class<?> cls, int i) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            try {
                try {
                    existingState.pushJavaObject(Array.newInstance(cls, i));
                } catch (Exception e2) {
                    throw new LuaException("can not create a array: " + e2.getMessage());
                }
            } catch (Throwable th) {
                throw th;
            }
        }
        return 1;
    }

    public static int objectCall(long j, Object obj) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (obj instanceof LuaMetaTable) {
                int top = existingState.getTop();
                Object[] objArr = new Object[top - 1];
                for (int i = 2; i <= top; i++) {
                    objArr[i - 2] = existingState.toJavaObject(i);
                }
                existingState.pushObjectValue(((LuaMetaTable) obj).__call(objArr));
                return 1;
            }
            if (!existingState.isTable(2)) {
                return 0;
            }
            if (obj.getClass().isArray() && Array.getLength(obj) == 0) {
                return d(existingState, obj.getClass());
            }
            existingState.pushNil();
            if (obj instanceof List) {
                List list = (List) obj;
                while (existingState.next(2) != 0) {
                    list.add(existingState.toJavaObject(-1));
                    existingState.pop(1);
                }
            } else {
                while (existingState.next(2) != 0) {
                    if (existingState.isNumber(-2)) {
                        setArrayValue(existingState, obj, (int) existingState.toInteger(-2));
                    } else {
                        javaSetter(existingState, obj, existingState.toString(-2));
                    }
                    existingState.pop(1);
                }
            }
            existingState.setTop(1);
            return 1;
        }
    }

    public static int objectIndex(long j, Object obj, String str, int i) {
        int iCheckField;
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (i == 0) {
                try {
                    if (checkMethod(existingState, obj, str) != 0) {
                        return 2;
                    }
                } catch (Throwable th) {
                    throw th;
                }
            }
            if ((i == 0 || i == 1 || i == 5) && (iCheckField = checkField(existingState, obj, str)) != 0) {
                return iCheckField;
            }
            if ((i == 0 || i == 4) && javaGetter(existingState, obj, str) != 0) {
                return 4;
            }
            if ((i == 0 || i == 3) && checkClass(existingState, obj, str) != 0) {
                return 3;
            }
            if ((i != 0 && i != 6) || !(obj instanceof LuaMetaTable)) {
                return 0;
            }
            existingState.pushObjectValue(((LuaMetaTable) obj).__index(str));
            return 6;
        }
    }

    public static int objectNewIndex(long j, Object obj, String str, int i) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (i == 0 || i == 1) {
                if (setFieldValue(existingState, obj, str) != 0) {
                    return 1;
                }
            }
            if ((i == 0 || i == 2) && javaSetter(existingState, obj, str) != 0) {
                return 2;
            }
            if ((i != 0 && i != 3) || !(obj instanceof LuaMetaTable)) {
                return 0;
            }
            ((LuaMetaTable) obj).__newIndex(str, existingState.toJavaObject(-1));
            return 3;
        }
    }

    public static int setArrayValue(long j, Object obj, int i) {
        LuaState existingState = LuaStateFactory.getExistingState(j);
        synchronized (existingState) {
            if (obj.getClass().isArray()) {
                Class<?> componentType = obj.getClass().getComponentType();
                try {
                    Array.set(obj, i, e(existingState, componentType, 3));
                } catch (LuaException unused) {
                    a(existingState, obj.getClass().getName() + " [" + i + "]", 3, componentType);
                }
            } else if (obj instanceof List) {
                ((List) obj).set(i, existingState.toJavaObject(3));
            } else {
                if (!(obj instanceof Map)) {
                    throw new LuaException("can not set " + obj.getClass().getName() + " value: " + existingState.toJavaObject(3) + " in " + i);
                }
                ((Map) obj).put(Long.valueOf(i), existingState.toJavaObject(3));
            }
        }
        return 0;
    }

    public static int setArrayValue(LuaState luaState, Object obj, int i) {
        synchronized (luaState) {
            if (obj.getClass().isArray()) {
                Class<?> componentType = obj.getClass().getComponentType();
                try {
                    Array.set(obj, i, e(luaState, componentType, -1));
                } catch (LuaException unused) {
                    a(luaState, obj.getClass().getName() + " [" + i + "]", 3, componentType);
                }
            } else if (obj instanceof List) {
                ((List) obj).set(i, luaState.toJavaObject(-1));
            } else {
                if (!(obj instanceof Map)) {
                    throw new LuaException("can not set " + obj.getClass().getName() + " value: " + luaState.toJavaObject(-1) + " in " + i);
                }
                ((Map) obj).put(Long.valueOf(i), luaState.toJavaObject(-1));
            }
        }
        return 0;
    }

    public static int setFieldValue(LuaState luaState, Object obj, String str) {
        Class<?> cls;
        boolean z;
        synchronized (luaState) {
            try {
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
                    } catch (LuaException unused) {
                        a(luaState, str, -1, type);
                    } catch (Exception e2) {
                        throw new LuaException(e2);
                    }
                    return 1;
                } catch (NoSuchFieldException unused2) {
                    return 0;
                }
            } catch (Throwable th) {
                throw th;
            }
        }
    }
}