package com.androlua;

import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.widget.AbsListView;
import android.widget.ArrayListAdapter;
import android.widget.ImageView;
import android.widget.TextView;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaArrayAdapter extends ArrayListAdapter {
    private Resources l;
    private LuaContext m;
    private LuaState n;
    private LuaObject o;
    private LuaObject p;
    private Animation q;
    private Handler r;
    private HashMap<String, Boolean> s;

    private class AsyncLoader extends Thread {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private String f745a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private LuaContext f746b;

        private AsyncLoader() {
        }

        public Drawable getBitmap(LuaContext luaContext, String str) {
            this.f746b = luaContext;
            this.f745a = str;
            if ((str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) && !LuaBitmap.checkCache(luaContext, str)) {
                if (!LuaArrayAdapter.this.s.containsKey(this.f745a)) {
                    start();
                    LuaArrayAdapter.this.s.put(this.f745a, true);
                }
                return new LoadingDrawable(this.f746b.getContext());
            }
            return new BitmapDrawable(LuaArrayAdapter.this.l, LuaBitmap.getBitmap(luaContext, str));
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                LuaBitmap.getBitmap(this.f746b, this.f745a);
                LuaArrayAdapter.this.r.sendEmptyMessage(0);
            } catch (Exception e) {
                e.printStackTrace();
                this.f746b.sendError("AsyncLoader Error", e);
            }
        }
    }

    public LuaArrayAdapter(LuaContext luaContext, LuaObject luaObject) {
        this(luaContext, luaObject, new String[0]);
    }

    public LuaArrayAdapter(LuaContext luaContext, LuaObject luaObject, Object[] objArr) {
        super(luaContext.getContext(), 0, objArr);
        this.r = new Handler() { // from class: com.androlua.LuaArrayAdapter.1
            @Override // android.os.Handler
            public void handleMessage(Message message) {
                LuaArrayAdapter.this.notifyDataSetChanged();
            }
        };
        this.s = new HashMap<>();
        this.m = luaContext;
        this.o = luaObject;
        this.l = this.m.getContext().getResources();
        this.n = luaContext.getLuaState();
        this.p = this.n.getLuaObject("loadlayout");
        this.n.newTable();
        this.p.call(this.o, this.n.getLuaObject(-1), AbsListView.class);
        this.n.pop(1);
    }

    private void a(View view, Object obj) {
        ViewGroup.LayoutParams layoutParams;
        TextView textView;
        CharSequence string;
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
                ImageView imageView = (ImageView) view;
                Drawable drawable = null;
                byte b2 = 0;
                if (obj instanceof Bitmap) {
                    drawable = new BitmapDrawable(this.l, (Bitmap) obj);
                } else if (obj instanceof String) {
                    drawable = new AsyncLoader().getBitmap(this.m, (String) obj);
                } else if (obj instanceof Drawable) {
                    drawable = (Drawable) obj;
                } else if (obj instanceof Number) {
                    drawable = this.l.getDrawable(((Number) obj).intValue());
                }
                imageView.setImageDrawable(drawable);
                if (drawable instanceof BitmapDrawable) {
                    Bitmap bitmap = ((BitmapDrawable) drawable).getBitmap();
                    int width = bitmap.getWidth();
                    int height = bitmap.getHeight();
                    if (imageView.getScaleType() != ImageView.ScaleType.FIT_XY) {
                        return;
                    }
                    layoutParams = new ViewGroup.LayoutParams(this.m.getWidth(), (int) ((this.m.getWidth() * height) / width));
                } else if (drawable instanceof LoadingDrawable) {
                    layoutParams = new ViewGroup.LayoutParams(this.m.getWidth(), this.m.getWidth() / 4);
                } else {
                    if (!(drawable instanceof Drawable)) {
                        return;
                    }
                    Rect bounds = drawable.getBounds();
                    int iWidth = bounds.width();
                    int iHeight = bounds.height();
                    if (imageView.getScaleType() != ImageView.ScaleType.FIT_XY) {
                        return;
                    }
                    layoutParams = new ViewGroup.LayoutParams(this.m.getWidth(), (int) ((this.m.getWidth() * iHeight) / iWidth));
                }
                imageView.setLayoutParams(layoutParams);
            } catch (Exception e) {
                Log.i("lua", e.getMessage());
            }
        }
    }

    public Animation getAnimation() {
        return this.q;
    }

    @Override // android.widget.ArrayListAdapter, android.widget.BaseAdapter, android.widget.SpinnerAdapter
    public View getDropDownView(int i, View view, ViewGroup viewGroup) {
        return getView(i, view, viewGroup);
    }

    @Override // android.widget.ArrayListAdapter, android.widget.Adapter
    public View getView(int i, View view, ViewGroup viewGroup) {
        if (view == null) {
            this.n.newTable();
            LuaObject luaObject = this.n.getLuaObject(-1);
            this.n.pop(1);
            try {
                view = (View) this.p.call(this.o, luaObject, AbsListView.class);
            } catch (LuaException unused) {
                return new View(this.m.getContext());
            }
        }
        a(view, getItem(i));
        Animation animation = this.q;
        if (animation != null) {
            view.startAnimation(animation);
        }
        return view;
    }

    public void setAnimation(Animation animation) {
        this.q = animation;
    }
}