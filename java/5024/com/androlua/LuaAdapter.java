package com.androlua;

import android.annotation.SuppressLint;
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
import android.widget.Filter;
import android.widget.Filterable;
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
public class LuaAdapter extends BaseAdapter implements Filterable {
    private final LuaTable<Integer, LuaTable<String, Object>> a;
    private Resources b;
    private LuaState c;
    private LuaContext d;
    private final Object e;
    private LuaTable f;
    private LuaTable<Integer, LuaTable<String, Object>> g;
    private LuaTable<String, Object> h;
    private CharSequence i;
    private LuaFunction<View> j;
    private LuaFunction k;
    private LuaFunction l;
    private LuaFunction<Animation> m;
    private HashMap<View, Animation> n;
    private HashMap<View, Boolean> o;
    private boolean p;
    private boolean q;

    @SuppressLint({"HandlerLeak"})
    private Handler r;
    private HashMap<String, Boolean> s;
    private ArrayFilter t;
    private LuaFunction u;

    private class ArrayFilter extends Filter {
        private ArrayFilter() {
        }

        @Override // android.widget.Filter
        protected Filter.FilterResults performFiltering(CharSequence charSequence) {
            Filter.FilterResults filterResults = new Filter.FilterResults();
            LuaAdapter.this.i = charSequence;
            if (LuaAdapter.this.g == null) {
                return filterResults;
            }
            if (LuaAdapter.this.u != null) {
                LuaAdapter.this.r.sendEmptyMessage(1);
                return null;
            }
            filterResults.values = LuaAdapter.this.g;
            filterResults.count = LuaAdapter.this.g.size();
            return filterResults;
        }

        @Override // android.widget.Filter
        protected void publishResults(CharSequence charSequence, Filter.FilterResults filterResults) {
        }
    }

    private class AsyncLoader extends Thread {
        private String a;
        private LuaContext b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.b = luaContext;
            this.a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaAdapter.this.s.containsKey(this.a)) {
                    start();
                    LuaAdapter.this.s.put(this.a, true);
                }
                return new LoadingDrawable(this.b.getContext());
            }
            return new BitmapDrawable(LuaAdapter.this.b, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.b, this.a);
                LuaAdapter.this.r.sendEmptyMessage(0);
            } catch (IOException e) {
                this.b.sendError("AsyncLoader Error", e);
            }
        }
    }

    public LuaAdapter(LuaContext luaContext, LuaTable luaTable) {
        this(luaContext, null, luaTable);
    }

    public LuaAdapter(LuaContext luaContext, LuaTable<Integer, LuaTable<String, Object>> luaTable, LuaTable luaTable2) {
        this.e = new Object();
        this.n = new HashMap<>();
        this.o = new HashMap<>();
        this.p = true;
        this.r = new Handler() { // from class: com.androlua.LuaAdapter.1
            @Override // android.os.Handler
            public void handleMessage(Message message) {
                if (message.what == 0) {
                    LuaAdapter.this.notifyDataSetChanged();
                    return;
                }
                try {
                    LuaTable luaTable3 = new LuaTable(LuaAdapter.this.g.getLuaState());
                    LuaAdapter.this.u.call(LuaAdapter.this.a, luaTable3, LuaAdapter.this.i);
                    LuaAdapter.this.g = luaTable3;
                    LuaAdapter.this.notifyDataSetChanged();
                } catch (LuaException e) {
                    e.printStackTrace();
                    LuaAdapter.this.d.sendError("performFiltering", e);
                }
            }
        };
        this.s = new HashMap<>();
        this.d = luaContext;
        this.f = luaTable2;
        this.b = this.d.getContext().getResources();
        this.c = luaContext.getLuaState();
        this.g = luaTable == null ? new LuaTable<>(this.c) : luaTable;
        this.a = this.g;
        this.j = this.c.getLuaObject("loadlayout").getFunction();
        this.k = this.c.getLuaObject("table").getField("insert").getFunction();
        this.l = this.c.getLuaObject("table").getField("remove").getFunction();
        this.c.newTable();
        this.j.call(this.f, this.c.getLuaObject(-1), AbsListView.class);
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
            }
        } catch (Exception e) {
            this.d.sendError("setHelper", e);
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
        this.k.call(this.a, luaTable);
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    public void addAll(LuaTable<Integer, LuaTable<String, Object>> luaTable) {
        int length = luaTable.length();
        for (int i = 1; i <= length; i++) {
            this.k.call(this.a, luaTable.get(Integer.valueOf(i)));
        }
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    public void clear() {
        this.a.clear();
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    public void filter(CharSequence charSequence) {
        getFilter().filter(charSequence);
    }

    @Override // android.widget.Adapter
    public int getCount() {
        return this.g.length();
    }

    public LuaTable<Integer, LuaTable<String, Object>> getData() {
        return this.g;
    }

    @Override // android.widget.BaseAdapter, android.widget.SpinnerAdapter
    public View getDropDownView(int i, View view, ViewGroup viewGroup) {
        return getView(i, view, viewGroup);
    }

    @Override // android.widget.Filterable
    public Filter getFilter() {
        if (this.t == null) {
            this.t = new ArrayFilter();
        }
        return this.t;
    }

    @Override // android.widget.Adapter
    public Object getItem(int i) {
        return this.g.get(Integer.valueOf(i + 1));
    }

    @Override // android.widget.Adapter
    public long getItemId(int i) {
        return i + 1;
    }

    /* JADX WARN: Removed duplicated region for block: B:49:0x0103  */
    @Override // android.widget.Adapter
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public android.view.View getView(int r10, android.view.View r11, android.view.ViewGroup r12) {
        /*
            Method dump skipped, instructions count: 266
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaAdapter.getView(int, android.view.View, android.view.ViewGroup):android.view.View");
    }

    public void insert(int i, LuaTable<String, Object> luaTable) {
        this.k.call(this.a, Integer.valueOf(i + 1), luaTable);
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    @Override // android.widget.BaseAdapter
    public void notifyDataSetChanged() {
        super.notifyDataSetChanged();
        if (this.q) {
            return;
        }
        this.q = true;
        new Handler().postDelayed(new Runnable() { // from class: com.androlua.LuaAdapter.2
            @Override // java.lang.Runnable
            public void run() {
                LuaAdapter.this.q = false;
            }
        }, 500L);
    }

    public void remove(int i) {
        this.l.call(this.a, Integer.valueOf(i + 1));
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    public void setAnimation(LuaFunction<Animation> luaFunction) {
        setAnimationUtil(luaFunction);
    }

    public void setAnimationUtil(LuaFunction<Animation> luaFunction) {
        this.n.clear();
        this.m = luaFunction;
    }

    public void setFilter(LuaFunction luaFunction) {
        this.u = luaFunction;
    }

    public void setNotifyOnChange(boolean z) {
        this.p = z;
        if (this.p) {
            notifyDataSetChanged();
        }
    }

    public void setStyle(LuaTable<String, Object> luaTable) {
        this.o.clear();
        this.h = luaTable;
    }
}