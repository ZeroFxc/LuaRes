package com.androlua;

import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Message;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.widget.AbsListView;
import android.widget.BaseAdapter;
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
public class LuaMultiAdapter extends BaseAdapter {
    private Resources a;
    private LuaState b;
    private LuaContext c;
    private LuaTable<Integer, LuaTable> d;
    private LuaTable<Integer, LuaTable<String, Object>> e;
    private LuaTable<String, Object> f;
    private LuaFunction<View> g;
    private LuaFunction h;
    private LuaFunction i;
    private LuaTable<Integer, LuaFunction<Animation>> j;
    private HashMap<View, Animation> k;
    private HashMap<View, Boolean> l;
    private boolean m;
    private boolean n;
    private Handler o;
    private HashMap<String, Boolean> p;

    private class AsyncLoader extends Thread {
        private String a;
        private LuaContext b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.b = luaContext;
            this.a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaMultiAdapter.this.p.containsKey(this.a)) {
                    start();
                    LuaMultiAdapter.this.p.put(this.a, true);
                }
                return new LoadingDrawable(this.b.getContext());
            }
            return new BitmapDrawable(LuaMultiAdapter.this.a, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.b, this.a);
                LuaMultiAdapter.this.o.sendEmptyMessage(0);
            } catch (IOException e) {
                this.b.sendError("AsyncLoader Error", e);
            }
        }
    }

    public LuaMultiAdapter(LuaContext luaContext, LuaTable luaTable) {
        this(luaContext, null, luaTable);
    }

    public LuaMultiAdapter(LuaContext luaContext, LuaTable<Integer, LuaTable<String, Object>> luaTable, LuaTable<Integer, LuaTable> luaTable2) {
        this.k = new HashMap<>();
        this.l = new HashMap<>();
        this.m = true;
        this.o = new Handler() { // from class: com.androlua.LuaMultiAdapter.1
            @Override // android.os.Handler
            public void handleMessage(Message message) {
                LuaMultiAdapter.this.notifyDataSetChanged();
            }
        };
        this.p = new HashMap<>();
        this.c = luaContext;
        this.d = luaTable2;
        this.a = this.c.getContext().getResources();
        this.b = luaContext.getLuaState();
        this.e = luaTable == null ? new LuaTable<>(this.b) : luaTable;
        this.g = this.b.getLuaObject("loadlayout").getFunction();
        this.h = this.b.getLuaObject("table").getField("insert").getFunction();
        this.i = this.b.getLuaObject("table").getField("remove").getFunction();
        int length = this.d.length();
        for (int i = 1; i <= length; i++) {
            this.b.newTable();
            this.g.call(this.d.get(Integer.valueOf(i)), this.b.getLuaObject(-1), AbsListView.class);
            this.b.pop(1);
        }
    }

    private int a(Object obj, String str, Object obj2) throws IllegalAccessException, LuaException, IllegalArgumentException, InvocationTargetException {
        Iterator<Method> it = LuaJavaAPI.getMethod(obj.getClass(), "setOn" + str.substring(2) + "Listener", false).iterator();
        while (it.hasNext()) {
            Method next = it.next();
            Class<?>[] parameterTypes = next.getParameterTypes();
            if (parameterTypes.length == 1 && parameterTypes[0].isInterface()) {
                this.b.newTable();
                this.b.pushObjectValue(obj2);
                this.b.setField(-2, str);
                try {
                    next.invoke(obj, this.b.getLuaObject(-1).createProxy(parameterTypes[0]));
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
            String key = entry.getKey();
            Object value = entry.getValue();
            if (key.toLowerCase().equals("src")) {
                a(view, value);
            } else {
                c(view, key, value);
            }
        }
    }

    private void a(View view, Object obj) {
        ImageView imageView;
        Drawable bitmap;
        TextView textView;
        CharSequence string;
        try {
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
                if (obj instanceof Bitmap) {
                    ((ImageView) view).setImageBitmap((Bitmap) obj);
                    return;
                }
                if (obj instanceof String) {
                    imageView = (ImageView) view;
                    bitmap = new AsyncLoader().getBitmap(this.c, (String) obj);
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
            }
        } catch (Exception e) {
            this.c.sendError("setHelper", e);
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

    public void add(LuaTable<String, Object> luaTable) {
        this.h.call(this.e, luaTable);
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    public void addAll(LuaTable<Integer, LuaTable<String, Object>> luaTable) {
        int length = luaTable.length();
        for (int i = 1; i <= length; i++) {
            this.h.call(this.e, luaTable.get(Integer.valueOf(i)));
        }
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    public void clear() {
        this.e.clear();
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    @Override // android.widget.Adapter
    public int getCount() {
        return this.e.length();
    }

    public LuaTable<Integer, LuaTable<String, Object>> getData() {
        return this.e;
    }

    @Override // android.widget.BaseAdapter, android.widget.SpinnerAdapter
    public View getDropDownView(int i, View view, ViewGroup viewGroup) {
        return getView(i, view, viewGroup);
    }

    @Override // android.widget.Adapter
    public Object getItem(int i) {
        return this.e.get(Integer.valueOf(i + 1));
    }

    @Override // android.widget.Adapter
    public long getItemId(int i) {
        return i + 1;
    }

    @Override // android.widget.BaseAdapter, android.widget.Adapter
    public int getItemViewType(int i) {
        int iIntValue = ((Long) this.e.get(Integer.valueOf(i + 1)).get("__type")).intValue() - 1;
        if (iIntValue < 0) {
            return 0;
        }
        return iIntValue;
    }

    /* JADX WARN: Removed duplicated region for block: B:55:0x013c  */
    @Override // android.widget.Adapter
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public android.view.View getView(int r11, android.view.View r12, android.view.ViewGroup r13) {
        /*
            Method dump skipped, instructions count: 323
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaMultiAdapter.getView(int, android.view.View, android.view.ViewGroup):android.view.View");
    }

    @Override // android.widget.BaseAdapter, android.widget.Adapter
    public int getViewTypeCount() {
        return this.d.length();
    }

    public void insert(int i, LuaTable<String, Object> luaTable) {
        this.h.call(this.e, Integer.valueOf(i + 1), luaTable);
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    @Override // android.widget.BaseAdapter
    public void notifyDataSetChanged() {
        super.notifyDataSetChanged();
        if (this.n) {
            return;
        }
        this.n = true;
        new Handler().postDelayed(new Runnable() { // from class: com.androlua.LuaMultiAdapter.2
            @Override // java.lang.Runnable
            public void run() {
                LuaMultiAdapter.this.n = false;
            }
        }, 500L);
    }

    public void remove(int i) {
        this.i.call(this.e, Integer.valueOf(i + 1));
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    public void setAnimation(LuaTable<Integer, LuaFunction<Animation>> luaTable) {
        setAnimationUtil(luaTable);
    }

    public void setAnimationUtil(LuaTable<Integer, LuaFunction<Animation>> luaTable) {
        this.k.clear();
        this.j = luaTable;
    }

    public void setNotifyOnChange(boolean z) {
        this.m = z;
        if (this.m) {
            notifyDataSetChanged();
        }
    }

    public void setStyle(LuaTable<String, Object> luaTable) {
        this.l.clear();
        this.f = luaTable;
    }
}