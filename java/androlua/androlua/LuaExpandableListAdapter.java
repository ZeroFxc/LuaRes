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
import android.view.ViewGroup;
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
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaExpandableListAdapter extends BaseExpandableListAdapter {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private BitmapDrawable f794a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private Resources f795b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private LuaState f796c;
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

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private String f798a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private LuaContext f799b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.f799b = luaContext;
            this.f798a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaExpandableListAdapter.this.q.containsKey(this.f798a)) {
                    start();
                    LuaExpandableListAdapter.this.q.put(this.f798a, true);
                }
                return LuaExpandableListAdapter.this.f794a;
            }
            return new BitmapDrawable(LuaExpandableListAdapter.this.f795b, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.f799b, this.f798a);
                LuaExpandableListAdapter.this.p.sendEmptyMessage(0);
            } catch (IOException e) {
                this.f799b.sendError("AsyncLoader Error", e);
            }
        }
    }

    private class GroupItem {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private LuaTable<Integer, LuaTable<String, Object>> f801a;

        public GroupItem(LuaTable<Integer, LuaTable<String, Object>> luaTable) {
            this.f801a = luaTable;
        }

        public void add(LuaTable<String, Object> luaTable) {
            LuaTable<Integer, LuaTable<String, Object>> luaTable2 = this.f801a;
            luaTable2.put(Integer.valueOf(luaTable2.length() + 1), luaTable);
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public void clear() {
            this.f801a.clear();
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public LuaTable<Integer, LuaTable<String, Object>> getData() {
            return this.f801a;
        }

        public void insert(int i, LuaTable<String, Object> luaTable) {
            LuaExpandableListAdapter.this.k.call(this.f801a, Integer.valueOf(i + 1), luaTable);
            if (LuaExpandableListAdapter.this.o) {
                LuaExpandableListAdapter.this.notifyDataSetChanged();
            }
        }

        public void remove(int i) {
            LuaExpandableListAdapter.this.l.call(this.f801a, Integer.valueOf(i + 1));
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
        this.f796c = luaContext.getLuaState();
        this.f795b = this.d.getContext().getResources();
        this.f794a = new BitmapDrawable(this.f795b, getClass().getResourceAsStream("/res/drawable/icon.png"));
        this.f794a.setColorFilter(-1996488705, PorterDuff.Mode.SRC_ATOP);
        this.h = luaTable3;
        this.i = luaTable4;
        luaTable = luaTable == null ? new LuaTable<>(this.f796c) : luaTable;
        luaTable2 = luaTable2 == null ? new LuaTable<>(this.f796c) : luaTable2;
        this.e = luaTable;
        this.f = luaTable2;
        this.j = this.f796c.getLuaObject("loadlayout").getFunction();
        this.k = this.f796c.getLuaObject("table").getField("insert").getFunction();
        this.l = this.f796c.getLuaObject("table").getField("remove").getFunction();
        this.f796c.newTable();
        this.j.call(this.h, this.f796c.getLuaObject(-1), AbsListView.class);
        this.j.call(this.i, this.f796c.getLuaObject(-1), AbsListView.class);
        this.f796c.pop(1);
    }

    private int a(Object obj, String str, Object obj2) throws LuaException {
        for (Method method : LuaJavaAPI.getMethod(obj.getClass(), "setOn" + str.substring(2) + "Listener", false)) {
            Class<?>[] parameterTypes = method.getParameterTypes();
            if (parameterTypes.length == 1 && parameterTypes[0].isInterface()) {
                this.f796c.newTable();
                this.f796c.pushObjectValue(obj2);
                this.f796c.setField(-2, str);
                try {
                    method.invoke(obj, this.f796c.getLuaObject(-1).createProxy(parameterTypes[0]));
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

    public GroupItem add(LuaTable<String, Object> luaTable) {
        LuaTable<Integer, LuaTable<String, Object>> luaTable2 = this.e;
        luaTable2.put(Integer.valueOf(luaTable2.length() + 1), luaTable);
        LuaTable<Integer, LuaTable<String, Object>> luaTable3 = new LuaTable<>(this.f796c);
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

    @Override // android.widget.ExpandableListAdapter
    public View getChildView(int i, int i2, boolean z, View view, ViewGroup viewGroup) {
        LuaTable luaTable;
        View viewCall;
        if (view == null) {
            try {
                luaTable = new LuaTable(this.f796c);
                viewCall = this.j.call(this.i, luaTable, AbsListView.class);
                viewCall.setTag(luaTable);
            } catch (LuaException unused) {
                return new View(this.d.getContext());
            }
        } else {
            luaTable = (LuaTable) view.getTag();
            viewCall = view;
        }
        LuaTable<String, Object> luaTable2 = this.f.get(Integer.valueOf(i + 1)).get(Integer.valueOf(i2 + 1));
        if (luaTable2 == null) {
            Log.i("lua", i2 + " is null");
            return viewCall;
        }
        for (Map.Entry<String, Object> entry : luaTable2.entrySet()) {
            try {
                String key = entry.getKey();
                Object value = entry.getValue();
                View view2 = (View) luaTable.get(key);
                if (view2 != null) {
                    a(view2, value);
                }
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
        if (!this.m && this.n != null && view != null) {
            Animation animation = this.g.get(view);
            if (animation == null) {
                try {
                    Animation animationCall = this.n.call(new Object[0]);
                    try {
                        this.g.put(view, animationCall);
                        animation = animationCall;
                    } catch (Exception e2) {
                        e = e2;
                        animation = animationCall;
                        Log.i("lua", e.getMessage());
                    }
                } catch (Exception e3) {
                    e = e3;
                }
            }
            if (animation != null) {
                viewCall.clearAnimation();
                viewCall.startAnimation(animation);
            }
        }
        return viewCall;
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

    @Override // android.widget.ExpandableListAdapter
    public View getGroupView(int i, boolean z, View view, ViewGroup viewGroup) {
        LuaTable luaTable;
        View viewCall;
        if (view == null) {
            try {
                luaTable = new LuaTable(this.f796c);
                viewCall = this.j.call(this.h, luaTable, AbsListView.class);
                viewCall.setTag(luaTable);
            } catch (LuaException unused) {
                return new View(this.d.getContext());
            }
        } else {
            luaTable = (LuaTable) view.getTag();
            viewCall = view;
        }
        LuaTable<String, Object> luaTable2 = this.e.get(Integer.valueOf(i + 1));
        if (luaTable2 == null) {
            Log.i("lua", i + " is null");
            return viewCall;
        }
        for (Map.Entry<String, Object> entry : luaTable2.entrySet()) {
            try {
                String key = entry.getKey();
                Object value = entry.getValue();
                View view2 = (View) luaTable.get(key);
                if (view2 != null) {
                    a(view2, value);
                }
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
        if (!this.m && this.n != null && view != null) {
            Animation animation = this.g.get(view);
            if (animation == null) {
                try {
                    Animation animationCall = this.n.call(new Object[0]);
                    try {
                        this.g.put(view, animationCall);
                        animation = animationCall;
                    } catch (Exception e2) {
                        e = e2;
                        animation = animationCall;
                        Log.i("lua", e.getMessage());
                    }
                } catch (Exception e3) {
                    e = e3;
                }
            }
            if (animation != null) {
                viewCall.clearAnimation();
                viewCall.startAnimation(animation);
            }
        }
        return viewCall;
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