package com.androlua;

import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.PorterDuff;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.animation.Animation;
import android.widget.AbsListView;
import android.widget.BaseExpandableListAdapter;
import android.widget.ImageView;
import android.widget.TextView;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import com.luajava.LuaJavaAPI;
import com.luajava.LuaState;
import com.luajava.LuaTable;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaExpandableListAdapter extends BaseExpandableListAdapter {
    private BitmapDrawable a;
    private Resources b;
    private LuaState c;
    private LuaContext d;
    private LuaTable<Integer, LuaTable<String, Object>> e;
    private LuaTable<Integer, LuaTable<Integer, LuaTable<String, Object>>> f;
    private HashMap<View, Animation> g;
    private LuaTable h;
    private LuaTable i;
    private LuaFunction<View> j;
    private LuaFunction<?> k;
    private LuaFunction<?> l;
    private boolean m;
    private LuaFunction<Animation> n;
    private boolean o;
    private Handler p;
    private HashMap<String, Boolean> q;

    private class AsyncLoader extends Thread {
        private String a;
        private LuaContext b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.b = luaContext;
            this.a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaExpandableListAdapter.this.q.containsKey(this.a)) {
                    start();
                    LuaExpandableListAdapter.this.q.put(this.a, true);
                }
                return LuaExpandableListAdapter.this.a;
            }
            return new BitmapDrawable(LuaExpandableListAdapter.this.b, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.b, this.a);
                LuaExpandableListAdapter.this.p.sendEmptyMessage(0);
            } catch (IOException e) {
                this.b.sendError("AsyncLoader Error", e);
            }
        }
    }

    private class GroupItem {
        private LuaTable<Integer, LuaTable<String, Object>> a;

        public GroupItem(LuaTable<Integer, LuaTable<String, Object>> luaTable) {
            this.a = luaTable;
        }

        public void add(LuaTable<String, Object> luaTable) {
            LuaTable<Integer, LuaTable<String, Object>> luaTable2 = this.a;
            luaTable2.put(Integer.valueOf(luaTable2.length() + 1), luaTable);
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public void clear() {
            this.a.clear();
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public LuaTable<Integer, LuaTable<String, Object>> getData() {
            return this.a;
        }

        public void insert(int i, LuaTable<String, Object> luaTable) {
            LuaExpandableListAdapter.this.k.call(this.a, Integer.valueOf(i + 1), luaTable);
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public void remove(int i) {
            LuaExpandableListAdapter.this.l.call(this.a, Integer.valueOf(i + 1));
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }
    }

    public LuaExpandableListAdapter(LuaContext luaContext, LuaTable luaTable, LuaTable luaTable2) {
        this(luaContext, null, null, luaTable, luaTable2);
    }

    public LuaExpandableListAdapter(LuaContext luaContext, LuaTable<Integer, LuaTable<String, Object>> luaTable, LuaTable<Integer, LuaTable<Integer, LuaTable<String, Object>>> luaTable2, LuaTable luaTable3, LuaTable luaTable4) {
        this.g = new HashMap<>();
        this.p = new Handler() { // from class: com.androlua.LuaExpandableListAdapter.1
            @Override // android.os.Handler
            public void handleMessage(Message message) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        };
        this.q = new HashMap<>();
        this.d = luaContext;
        this.c = luaContext.getLuaState();
        this.b = this.d.getContext().getResources();
        this.a = new BitmapDrawable(this.b, getClass().getResourceAsStream("/res/drawable/icon.png"));
        this.a.setColorFilter(-1996488705, PorterDuff.Mode.SRC_ATOP);
        this.h = luaTable3;
        this.i = luaTable4;
        luaTable = luaTable == null ? new LuaTable<>(this.c) : luaTable;
        luaTable2 = luaTable2 == null ? new LuaTable<>(this.c) : luaTable2;
        this.e = luaTable;
        this.f = luaTable2;
        this.j = this.c.getLuaObject("loadlayout").getFunction();
        this.k = this.c.getLuaObject("table").getField("insert").getFunction();
        this.l = this.c.getLuaObject("table").getField("remove").getFunction();
        this.c.newTable();
        this.j.call(this.h, this.c.getLuaObject(-1), AbsListView.class);
        this.j.call(this.i, this.c.getLuaObject(-1), AbsListView.class);
        this.c.pop(1);
    }

    private int a(Object obj, String str, Object obj2) throws IllegalAccessException, LuaException, IllegalArgumentException, InvocationTargetException {
        Iterator<Method> it = LuaJavaAPI.getMethod(obj.getClass(), "setOn" + str.substring(2) + "Listener", false).iterator();
        while (it.hasNext()) {
            Method next = it.next();
            Class<?>[] parameterTypes = next.getParameterTypes();
            if (parameterTypes.length == 1 && parameterTypes[0].isInterface()) {
                this.c.newTable();
                this.c.pushObjectValue(obj2);
                this.c.setField(-2, str);
                try {
                    next.invoke(obj, this.c.getLuaObject(-1).createProxy(parameterTypes[0]));
                    return 1;
                } catch (Exception e) {
                    throw new LuaException(e);
                }
            }
        }
        return 0;
    }

    private void a(View view, LuaTable<String, Object> luaTable) {
        for (Map.Entry<String, Object> entry : luaTable.entrySet()) {
            try {
                String key = entry.getKey();
                Object value = entry.getValue();
                if (key.toLowerCase().equals("src")) {
                    a(view, value);
                } else {
                    c(view, key, value);
                }
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
    }

    private void a(View view, Object obj) {
        ImageView imageView;
        Drawable bitmap;
        TextView textView;
        CharSequence string;
        if (obj instanceof LuaTable) {
            a(view, (LuaTable<String, Object>) obj);
            return;
        }
        if (view instanceof TextView) {
            if (obj instanceof CharSequence) {
                textView = (TextView) view;
                string = (CharSequence) obj;
            } else {
                textView = (TextView) view;
                string = obj.toString();
            }
            textView.setText(string);
            return;
        }
        if (view instanceof ImageView) {
            try {
                if (obj instanceof Bitmap) {
                    ((ImageView) view).setImageBitmap((Bitmap) obj);
                    return;
                }
                if (obj instanceof String) {
                    imageView = (ImageView) view;
                    bitmap = new AsyncLoader().getBitmap(this.d, (String) obj);
                } else {
                    if (!(obj instanceof Drawable)) {
                        if (obj instanceof Number) {
                            ((ImageView) view).setImageResource(((Number) obj).intValue());
                            return;
                        }
                        return;
                    }
                    imageView = (ImageView) view;
                    bitmap = (Drawable) obj;
                }
                imageView.setImageDrawable(bitmap);
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private int b(Object obj, String str, Object obj2) throws IllegalAccessException, LuaException, IllegalArgumentException, InvocationTargetException {
        Object[] objArr;
        if (Character.isLowerCase(str.charAt(0))) {
            str = Character.toUpperCase(str.charAt(0)) + str.substring(1);
        }
        Class<?> cls = obj2.getClass();
        StringBuilder sb = new StringBuilder();
        Iterator<Method> it = LuaJavaAPI.getMethod(obj.getClass(), "set" + str, false).iterator();
        while (it.hasNext()) {
            Method next = it.next();
            Class<?>[] parameterTypes = next.getParameterTypes();
            if (parameterTypes.length == 1) {
                if (parameterTypes[0].isPrimitive()) {
                    try {
                        if ((obj2 instanceof Double) || (obj2 instanceof Float)) {
                            objArr = new Object[]{LuaState.convertLuaNumber(Double.valueOf(((Number) obj2).doubleValue()), parameterTypes[0])};
                        } else {
                            if (!(obj2 instanceof Long) && !(obj2 instanceof Integer)) {
                                if (obj2 instanceof Boolean) {
                                    next.invoke(obj, (Boolean) obj2);
                                    return 1;
                                }
                            }
                            objArr = new Object[]{LuaState.convertLuaNumber(Long.valueOf(((Number) obj2).longValue()), parameterTypes[0])};
                        }
                        next.invoke(obj, objArr);
                        return 1;
                    } catch (Exception e) {
                        sb.append(e.getMessage());
                        sb.append("\n");
                    }
                } else if (parameterTypes[0].isAssignableFrom(cls)) {
                    next.invoke(obj, obj2);
                    return 1;
                }
            }
        }
        if (sb.length() <= 0) {
            throw new LuaException("Invalid setter " + str + " is not a method.\n");
        }
        throw new LuaException("Invalid setter " + str + ". Invalid Parameters.\n" + sb.toString() + cls.toString());
    }

    private int c(Object obj, String str, Object obj2) {
        return (str.length() > 2 && str.substring(0, 2).equals("on") && (obj2 instanceof LuaFunction)) ? a(obj, str, obj2) : b(obj, str, obj2);
    }

    public GroupItem add(LuaTable<String, Object> luaTable) {
        LuaTable<Integer, LuaTable<String, Object>> luaTable2 = this.e;
        luaTable2.put(Integer.valueOf(luaTable2.length() + 1), luaTable);
        LuaTable<Integer, LuaTable<String, Object>> luaTable3 = new LuaTable<>(this.c);
        this.f.put(Integer.valueOf(this.e.length()), luaTable3);
        if (this.o) {
            notifyDataSetChanged();
        }
        return new GroupItem(luaTable3);
    }

    public GroupItem add(LuaTable<String, Object> luaTable, LuaTable<Integer, LuaTable<String, Object>> luaTable2) {
        LuaTable<Integer, LuaTable<String, Object>> luaTable3 = this.e;
        luaTable3.put(Integer.valueOf(luaTable3.length() + 1), luaTable);
        this.f.put(Integer.valueOf(this.e.length()), luaTable2);
        if (this.o) {
            notifyDataSetChanged();
        }
        return new GroupItem(luaTable2);
    }

    public void clear() {
        this.e.clear();
        this.f.clear();
        if (this.o) {
            notifyDataSetChanged();
        }
    }

    @Override // android.widget.ExpandableListAdapter
    public Object getChild(int i, int i2) {
        return this.f.get(Integer.valueOf(i + 1)).get(Integer.valueOf(i2 + 1));
    }

    public LuaTable<Integer, LuaTable<Integer, LuaTable<String, Object>>> getChildData() {
        return this.f;
    }

    @Override // android.widget.ExpandableListAdapter
    public long getChildId(int i, int i2) {
        return i2 + 1;
    }

    /* JADX WARN: Removed duplicated region for block: B:39:0x00d2  */
    @Override // android.widget.ExpandableListAdapter
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public android.view.View getChildView(int r7, int r8, boolean r9, android.view.View r10, android.view.ViewGroup r11) {
        /*
            r6 = this;
            r9 = 0
            r11 = 1
            if (r10 != 0) goto L31
            com.luajava.LuaTable r0 = new com.luajava.LuaTable     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaState r1 = r6.c     // Catch: com.luajava.LuaException -> L25
            r0.<init>(r1)     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaFunction<android.view.View> r1 = r6.j     // Catch: com.luajava.LuaException -> L25
            r2 = 3
            java.lang.Object[] r2 = new java.lang.Object[r2]     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaTable r3 = r6.i     // Catch: com.luajava.LuaException -> L25
            r2[r9] = r3     // Catch: com.luajava.LuaException -> L25
            r2[r11] = r0     // Catch: com.luajava.LuaException -> L25
            r3 = 2
            java.lang.Class<android.widget.AbsListView> r4 = android.widget.AbsListView.class
            r2[r3] = r4     // Catch: com.luajava.LuaException -> L25
            java.lang.Object r1 = r1.call(r2)     // Catch: com.luajava.LuaException -> L25
            android.view.View r1 = (android.view.View) r1     // Catch: com.luajava.LuaException -> L25
            r1.setTag(r0)     // Catch: com.luajava.LuaException -> L25
            goto L38
        L25:
            android.view.View r7 = new android.view.View
            com.androlua.LuaContext r8 = r6.d
            android.content.Context r8 = r8.getContext()
            r7.<init>(r8)
            return r7
        L31:
            java.lang.Object r0 = r10.getTag()
            com.luajava.LuaTable r0 = (com.luajava.LuaTable) r0
            r1 = r10
        L38:
            com.luajava.LuaTable<java.lang.Integer, com.luajava.LuaTable<java.lang.Integer, com.luajava.LuaTable<java.lang.String, java.lang.Object>>> r2 = r6.f
            int r7 = r7 + r11
            java.lang.Integer r7 = java.lang.Integer.valueOf(r7)
            java.lang.Object r7 = r2.get(r7)
            com.luajava.LuaTable r7 = (com.luajava.LuaTable) r7
            int r11 = r8 + 1
            java.lang.Integer r11 = java.lang.Integer.valueOf(r11)
            java.lang.Object r7 = r7.get(r11)
            com.luajava.LuaTable r7 = (com.luajava.LuaTable) r7
            java.lang.String r11 = "lua"
            if (r7 != 0) goto L6a
            java.lang.StringBuilder r7 = new java.lang.StringBuilder
            r7.<init>()
            r7.append(r8)
            java.lang.String r8 = " is null"
            r7.append(r8)
            java.lang.String r7 = r7.toString()
            android.util.Log.i(r11, r7)
            return r1
        L6a:
            java.util.Set r7 = r7.entrySet()
            java.util.Iterator r7 = r7.iterator()
        L72:
            boolean r8 = r7.hasNext()
            if (r8 == 0) goto L9d
            java.lang.Object r8 = r7.next()
            java.util.Map$Entry r8 = (java.util.Map.Entry) r8
            java.lang.Object r2 = r8.getKey()     // Catch: java.lang.Exception -> L94
            java.lang.String r2 = (java.lang.String) r2     // Catch: java.lang.Exception -> L94
            java.lang.Object r8 = r8.getValue()     // Catch: java.lang.Exception -> L94
            java.lang.Object r2 = r0.get(r2)     // Catch: java.lang.Exception -> L94
            android.view.View r2 = (android.view.View) r2     // Catch: java.lang.Exception -> L94
            if (r2 == 0) goto L72
            r6.a(r2, r8)     // Catch: java.lang.Exception -> L94
            goto L72
        L94:
            r8 = move-exception
            java.lang.String r8 = r8.getMessage()
            android.util.Log.i(r11, r8)
            goto L72
        L9d:
            boolean r7 = r6.m
            if (r7 == 0) goto La2
            return r1
        La2:
            com.luajava.LuaFunction<android.view.animation.Animation> r7 = r6.n
            if (r7 == 0) goto Ld8
            if (r10 == 0) goto Ld8
            java.util.HashMap<android.view.View, android.view.animation.Animation> r7 = r6.g
            java.lang.Object r7 = r7.get(r10)
            android.view.animation.Animation r7 = (android.view.animation.Animation) r7
            if (r7 != 0) goto Ld0
            com.luajava.LuaFunction<android.view.animation.Animation> r8 = r6.n     // Catch: java.lang.Exception -> Lc8
            java.lang.Object[] r9 = new java.lang.Object[r9]     // Catch: java.lang.Exception -> Lc8
            java.lang.Object r8 = r8.call(r9)     // Catch: java.lang.Exception -> Lc8
            android.view.animation.Animation r8 = (android.view.animation.Animation) r8     // Catch: java.lang.Exception -> Lc8
            java.util.HashMap<android.view.View, android.view.animation.Animation> r7 = r6.g     // Catch: java.lang.Exception -> Lc3
            r7.put(r10, r8)     // Catch: java.lang.Exception -> Lc3
            r7 = r8
            goto Ld0
        Lc3:
            r7 = move-exception
            r5 = r8
            r8 = r7
            r7 = r5
            goto Lc9
        Lc8:
            r8 = move-exception
        Lc9:
            java.lang.String r8 = r8.getMessage()
            android.util.Log.i(r11, r8)
        Ld0:
            if (r7 == 0) goto Ld8
            r1.clearAnimation()
            r1.startAnimation(r7)
        Ld8:
            return r1
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaExpandableListAdapter.getChildView(int, int, boolean, android.view.View, android.view.ViewGroup):android.view.View");
    }

    @Override // android.widget.ExpandableListAdapter
    public int getChildrenCount(int i) {
        return this.f.get(Integer.valueOf(i + 1)).length();
    }

    @Override // android.widget.ExpandableListAdapter
    public Object getGroup(int i) {
        return this.e.get(Integer.valueOf(i + 1));
    }

    @Override // android.widget.ExpandableListAdapter
    public int getGroupCount() {
        return this.e.length();
    }

    public LuaTable<Integer, LuaTable<String, Object>> getGroupData() {
        return this.e;
    }

    @Override // android.widget.ExpandableListAdapter
    public long getGroupId(int i) {
        return i + 1;
    }

    public GroupItem getGroupItem(int i) {
        return new GroupItem(this.f.get(Integer.valueOf(i + 1)));
    }

    /* JADX WARN: Removed duplicated region for block: B:39:0x00c7  */
    @Override // android.widget.ExpandableListAdapter
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public android.view.View getGroupView(int r6, boolean r7, android.view.View r8, android.view.ViewGroup r9) {
        /*
            r5 = this;
            r7 = 0
            if (r8 != 0) goto L31
            com.luajava.LuaTable r9 = new com.luajava.LuaTable     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaState r0 = r5.c     // Catch: com.luajava.LuaException -> L25
            r9.<init>(r0)     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaFunction<android.view.View> r0 = r5.j     // Catch: com.luajava.LuaException -> L25
            r1 = 3
            java.lang.Object[] r1 = new java.lang.Object[r1]     // Catch: com.luajava.LuaException -> L25
            com.luajava.LuaTable r2 = r5.h     // Catch: com.luajava.LuaException -> L25
            r1[r7] = r2     // Catch: com.luajava.LuaException -> L25
            r2 = 1
            r1[r2] = r9     // Catch: com.luajava.LuaException -> L25
            r2 = 2
            java.lang.Class<android.widget.AbsListView> r3 = android.widget.AbsListView.class
            r1[r2] = r3     // Catch: com.luajava.LuaException -> L25
            java.lang.Object r0 = r0.call(r1)     // Catch: com.luajava.LuaException -> L25
            android.view.View r0 = (android.view.View) r0     // Catch: com.luajava.LuaException -> L25
            r0.setTag(r9)     // Catch: com.luajava.LuaException -> L25
            goto L38
        L25:
            android.view.View r6 = new android.view.View
            com.androlua.LuaContext r7 = r5.d
            android.content.Context r7 = r7.getContext()
            r6.<init>(r7)
            return r6
        L31:
            java.lang.Object r9 = r8.getTag()
            com.luajava.LuaTable r9 = (com.luajava.LuaTable) r9
            r0 = r8
        L38:
            com.luajava.LuaTable<java.lang.Integer, com.luajava.LuaTable<java.lang.String, java.lang.Object>> r1 = r5.e
            int r2 = r6 + 1
            java.lang.Integer r2 = java.lang.Integer.valueOf(r2)
            java.lang.Object r1 = r1.get(r2)
            com.luajava.LuaTable r1 = (com.luajava.LuaTable) r1
            java.lang.String r2 = "lua"
            if (r1 != 0) goto L5f
            java.lang.StringBuilder r7 = new java.lang.StringBuilder
            r7.<init>()
            r7.append(r6)
            java.lang.String r6 = " is null"
            r7.append(r6)
            java.lang.String r6 = r7.toString()
            android.util.Log.i(r2, r6)
            return r0
        L5f:
            java.util.Set r6 = r1.entrySet()
            java.util.Iterator r6 = r6.iterator()
        L67:
            boolean r1 = r6.hasNext()
            if (r1 == 0) goto L92
            java.lang.Object r1 = r6.next()
            java.util.Map$Entry r1 = (java.util.Map.Entry) r1
            java.lang.Object r3 = r1.getKey()     // Catch: java.lang.Exception -> L89
            java.lang.String r3 = (java.lang.String) r3     // Catch: java.lang.Exception -> L89
            java.lang.Object r1 = r1.getValue()     // Catch: java.lang.Exception -> L89
            java.lang.Object r3 = r9.get(r3)     // Catch: java.lang.Exception -> L89
            android.view.View r3 = (android.view.View) r3     // Catch: java.lang.Exception -> L89
            if (r3 == 0) goto L67
            r5.a(r3, r1)     // Catch: java.lang.Exception -> L89
            goto L67
        L89:
            r1 = move-exception
            java.lang.String r1 = r1.getMessage()
            android.util.Log.i(r2, r1)
            goto L67
        L92:
            boolean r6 = r5.m
            if (r6 == 0) goto L97
            return r0
        L97:
            com.luajava.LuaFunction<android.view.animation.Animation> r6 = r5.n
            if (r6 == 0) goto Lcd
            if (r8 == 0) goto Lcd
            java.util.HashMap<android.view.View, android.view.animation.Animation> r6 = r5.g
            java.lang.Object r6 = r6.get(r8)
            android.view.animation.Animation r6 = (android.view.animation.Animation) r6
            if (r6 != 0) goto Lc5
            com.luajava.LuaFunction<android.view.animation.Animation> r9 = r5.n     // Catch: java.lang.Exception -> Lbd
            java.lang.Object[] r7 = new java.lang.Object[r7]     // Catch: java.lang.Exception -> Lbd
            java.lang.Object r7 = r9.call(r7)     // Catch: java.lang.Exception -> Lbd
            android.view.animation.Animation r7 = (android.view.animation.Animation) r7     // Catch: java.lang.Exception -> Lbd
            java.util.HashMap<android.view.View, android.view.animation.Animation> r6 = r5.g     // Catch: java.lang.Exception -> Lb8
            r6.put(r8, r7)     // Catch: java.lang.Exception -> Lb8
            r6 = r7
            goto Lc5
        Lb8:
            r6 = move-exception
            r4 = r7
            r7 = r6
            r6 = r4
            goto Lbe
        Lbd:
            r7 = move-exception
        Lbe:
            java.lang.String r7 = r7.getMessage()
            android.util.Log.i(r2, r7)
        Lc5:
            if (r6 == 0) goto Lcd
            r0.clearAnimation()
            r0.startAnimation(r6)
        Lcd:
            return r0
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaExpandableListAdapter.getGroupView(int, boolean, android.view.View, android.view.ViewGroup):android.view.View");
    }

    @Override // android.widget.ExpandableListAdapter
    public boolean hasStableIds() {
        return false;
    }

    public GroupItem insert(int i, LuaTable<String, Object> luaTable, LuaTable<Integer, LuaTable<String, Object>> luaTable2) {
        int i2 = i + 1;
        this.k.call(this.e, Integer.valueOf(i2), luaTable);
        this.k.call(this.f, Integer.valueOf(i2), luaTable2);
        if (this.o) {
            notifyDataSetChanged();
        }
        return new GroupItem(luaTable2);
    }

    @Override // android.widget.ExpandableListAdapter
    public boolean isChildSelectable(int i, int i2) {
        return false;
    }

    public void remove(int i) {
        this.l.call(this.e, Integer.valueOf(i + 1));
        if (this.o) {
            notifyDataSetChanged();
        }
    }

    public void setAnimationUtil(LuaFunction<Animation> luaFunction) {
        this.g.clear();
        this.n = luaFunction;
    }

    public void setNotifyOnChange(boolean z) {
        this.o = z;
        if (this.o) {
            notifyDataSetChanged();
        }
    }
}