package com.androlua;

import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.widget.AbsListView;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.TextView;
import com.baidu.mobstat.Config;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import com.luajava.LuaJavaAPI;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import com.luajava.LuaTable;
import java.io.IOException;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaMultiAdapter extends BaseAdapter {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private Resources f812a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaState f813b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private LuaContext f814c;
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

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private String f817a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private LuaContext f818b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.f818b = luaContext;
            this.f817a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaMultiAdapter.this.p.containsKey(this.f817a)) {
                    start();
                    LuaMultiAdapter.this.p.put(this.f817a, true);
                }
                return new LoadingDrawable(this.f818b.getContext());
            }
            return new BitmapDrawable(LuaMultiAdapter.this.f812a, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.f818b, this.f817a);
                LuaMultiAdapter.this.o.sendEmptyMessage(0);
            } catch (IOException e) {
                this.f818b.sendError("AsyncLoader Error", e);
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
        this.f814c = luaContext;
        this.d = luaTable2;
        this.f812a = this.f814c.getContext().getResources();
        this.f813b = luaContext.getLuaState();
        this.e = luaTable == null ? new LuaTable<>(this.f813b) : luaTable;
        this.g = this.f813b.getLuaObject("loadlayout").getFunction();
        this.h = this.f813b.getLuaObject("table").getField("insert").getFunction();
        this.i = this.f813b.getLuaObject("table").getField("remove").getFunction();
        int length = this.d.length();
        for (int i = 1; i <= length; i++) {
            this.f813b.newTable();
            this.g.call(this.d.get(Integer.valueOf(i)), this.f813b.getLuaObject(-1), AbsListView.class);
            this.f813b.pop(1);
        }
    }

    private int a(Object obj, String str, Object obj2) throws LuaException {
        for (Method method : LuaJavaAPI.getMethod(obj.getClass(), "setOn" + str.substring(2) + "Listener", false)) {
            Class<?>[] parameterTypes = method.getParameterTypes();
            if (parameterTypes.length == 1 && parameterTypes[0].isInterface()) {
                this.f813b.newTable();
                this.f813b.pushObjectValue(obj2);
                this.f813b.setField(-2, str);
                try {
                    method.invoke(obj, this.f813b.getLuaObject(-1).createProxy(parameterTypes[0]));
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
                    bitmap = new AsyncLoader().getBitmap(this.f814c, (String) obj);
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
            this.f814c.sendError("setHelper", e);
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    private int b(Object obj, String str, Object obj2) throws LuaException {
        Object[] objArr;
        if (Character.isLowerCase(str.charAt(0))) {
            str = Character.toUpperCase(str.charAt(0)) + str.substring(1);
        }
        Class<?> cls = obj2.getClass();
        StringBuilder sb = new StringBuilder();
        for (Method method : LuaJavaAPI.getMethod(obj.getClass(), "set" + str, false)) {
            Class<?>[] parameterTypes = method.getParameterTypes();
            if (parameterTypes.length == 1) {
                if (parameterTypes[0].isPrimitive()) {
                    try {
                        if ((obj2 instanceof Double) || (obj2 instanceof Float)) {
                            objArr = new Object[]{LuaState.convertLuaNumber(Double.valueOf(((Number) obj2).doubleValue()), parameterTypes[0])};
                        } else {
                            if (!(obj2 instanceof Long) && !(obj2 instanceof Integer)) {
                                if (obj2 instanceof Boolean) {
                                    method.invoke(obj, (Boolean) obj2);
                                    return 1;
                                }
                            }
                            objArr = new Object[]{LuaState.convertLuaNumber(Long.valueOf(((Number) obj2).longValue()), parameterTypes[0])};
                        }
                        method.invoke(obj, objArr);
                        return 1;
                    } catch (Exception e) {
                        sb.append(e.getMessage());
                        sb.append("\n");
                    }
                } else if (parameterTypes[0].isAssignableFrom(cls)) {
                    method.invoke(obj, obj2);
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

    @Override // android.widget.Adapter
    public View getView(int i, View view, ViewGroup viewGroup) {
        LuaObject luaObject;
        View viewCall;
        Animation animationCall;
        int i2 = i + 1;
        int iIntValue = ((Long) this.e.get(Integer.valueOf(i2)).get("__type")).intValue();
        if (iIntValue < 1) {
            iIntValue = 1;
        }
        if (view == null) {
            try {
                LuaTable luaTable = this.d.get(Integer.valueOf(iIntValue));
                this.f813b.newTable();
                luaObject = this.f813b.getLuaObject(-1);
                this.f813b.pop(1);
                viewCall = this.g.call(luaTable, luaObject, AbsListView.class);
                viewCall.setTag(luaObject);
            } catch (LuaException unused) {
                return new View(this.f814c.getContext());
            }
        } else {
            luaObject = (LuaObject) view.getTag();
            viewCall = view;
        }
        LuaTable<String, Object> luaTable2 = this.e.get(Integer.valueOf(i2));
        if (luaTable2 == null) {
            Log.i("lua", i + " is null");
            return viewCall;
        }
        boolean z = this.l.get(viewCall) == null;
        if (z) {
            this.l.put(viewCall, true);
        }
        for (Map.Entry<String, Object> entry : luaTable2.entrySet()) {
            try {
                String key = entry.getKey();
                if (!key.equals(Config.LAUNCH_TYPE)) {
                    Object value = entry.getValue();
                    LuaObject field = luaObject.getField(key);
                    if (field.isJavaObject()) {
                        if (this.f != null && z) {
                            a((View) field.getObject(), this.f.get(key));
                        }
                        a((View) field.getObject(), value);
                    }
                }
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
        if (!this.n && this.j != null && view != null) {
            Animation animation = this.k.get(view);
            if (animation == null) {
                try {
                    animationCall = this.j.get(Integer.valueOf(iIntValue)).call(new Object[0]);
                } catch (Exception e2) {
                    e = e2;
                }
                try {
                    this.k.put(view, animationCall);
                    animation = animationCall;
                } catch (Exception e3) {
                    e = e3;
                    animation = animationCall;
                    this.f814c.sendError("setAnimation", e);
                }
            }
            if (animation != null) {
                viewCall.clearAnimation();
                viewCall.startAnimation(animation);
            }
        }
        return viewCall;
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