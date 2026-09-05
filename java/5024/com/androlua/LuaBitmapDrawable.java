package com.androlua;

import android.graphics.ColorFilter;
import android.graphics.Movie;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import com.androlua.GifDecoder;
import com.androlua.util.AsyncTaskX;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaBitmapDrawable extends Drawable implements Runnable, LuaGcable {
    public static final int CENTER = 5;
    public static final int CENTER_CROP = 6;
    public static final int CENTER_INSIDE = 7;
    public static final int FIT_CENTER = 3;
    public static final int FIT_END = 4;
    public static final int FIT_START = 2;
    public static final int FIT_XY = 1;
    public static final int MATRIX = 0;
    private static long a = 604800000;
    private LuaContext b;
    private int c;
    private long d;
    private int e;
    private Movie f;
    private LoadingDrawable g;
    private Drawable h;
    private NineBitmapDrawable i;
    private ColorFilter j;
    private int k;
    private int l;
    private GifDecoder m;
    private GifDecoder n;
    private GifDecoder.GifFrame o;
    private int p;
    private boolean q;

    public LuaBitmapDrawable(LuaContext luaContext, String str) {
        this.l = 1;
        this.b = luaContext;
        this.g = new LoadingDrawable(luaContext.getContext());
        if (str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) {
            a(luaContext, str);
        } else {
            a(str.startsWith("/") ? str : luaContext.getLuaPath(str));
        }
    }

    public LuaBitmapDrawable(LuaContext luaContext, String str, Drawable drawable) {
        this(luaContext, str);
        this.h = drawable;
    }

    private void a(final LuaContext luaContext, final String str) {
        new AsyncTaskX<String, String, String>() { // from class: com.androlua.LuaBitmapDrawable.1
            @Override // com.androlua.util.AsyncTaskX
            protected String a(String... strArr) {
                try {
                    return LuaBitmapDrawable.getHttpBitmap(luaContext, str);
                } catch (Exception e) {
                    e.printStackTrace();
                    return BuildConfig.FLAVOR;
                }
            }

            @Override // com.androlua.util.AsyncTaskX
            /* renamed from: a, reason: merged with bridge method [inline-methods] */
            protected void b(String str2) {
                LuaBitmapDrawable.this.a(str2);
            }
        }.execute(new String[0]);
    }

    private void a(final String str) {
        try {
            this.m = new GifDecoder(new FileInputStream(str), new GifDecoder.GifAction() { // from class: com.androlua.LuaBitmapDrawable.2
                @Override // com.androlua.GifDecoder.GifAction
                public void parseOk(boolean z, int i) {
                    if (!z && i < 0) {
                        LuaBitmapDrawable.this.b(str);
                    } else if (z && LuaBitmapDrawable.this.n == null && LuaBitmapDrawable.this.m.getFrameCount() > 1) {
                        LuaBitmapDrawable luaBitmapDrawable = LuaBitmapDrawable.this;
                        luaBitmapDrawable.n = luaBitmapDrawable.m;
                    }
                }
            });
            this.m.start();
        } catch (Exception e) {
            e.printStackTrace();
            b(str);
        }
    }

    private void b(String str) {
        if (str.isEmpty()) {
            new Handler().postDelayed(new Runnable() { // from class: com.androlua.LuaBitmapDrawable.3
                @Override // java.lang.Runnable
                public void run() {
                    LuaBitmapDrawable.this.g.setState(-1);
                }
            }, 1000L);
            invalidateSelf();
            return;
        }
        Movie movie = this.f;
        if (movie != null) {
            this.c = movie.duration();
            if (this.c == 0) {
                this.c = 1000;
            }
        } else {
            try {
                try {
                    this.i = new NineBitmapDrawable(str);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            } catch (Exception unused) {
                this.h = new BitmapDrawable(LuaBitmap.getLocalBitmap(this.b, str));
            }
        }
        if (this.f == null && this.h == null && this.i == null) {
            new Handler().postDelayed(new Runnable() { // from class: com.androlua.LuaBitmapDrawable.4
                @Override // java.lang.Runnable
                public void run() {
                    LuaBitmapDrawable.this.g.setState(-1);
                }
            }, 1000L);
        }
        invalidateSelf();
    }

    public static long getCacheTime() {
        return a;
    }

    public static String getHttpBitmap(LuaContext luaContext, String str) throws IOException {
        String str2 = luaContext.getLuaExtDir("cache") + "/" + str.hashCode();
        File file = new File(str2);
        if (file.exists() && System.currentTimeMillis() - file.lastModified() < a) {
            return str2;
        }
        new File(str2).delete();
        HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(str).openConnection();
        httpURLConnection.setConnectTimeout(120000);
        httpURLConnection.setDoInput(true);
        httpURLConnection.connect();
        InputStream inputStream = httpURLConnection.getInputStream();
        FileOutputStream fileOutputStream = new FileOutputStream(str2);
        if (LuaUtil.copyFile(inputStream, fileOutputStream)) {
            fileOutputStream.close();
            inputStream.close();
            return str2;
        }
        fileOutputStream.close();
        inputStream.close();
        new File(str2).delete();
        throw new RuntimeException("LoadHttpBitmap Error.");
    }

    public static void setCacheTime(long j) {
        a = j;
    }

    /* JADX WARN: Removed duplicated region for block: B:23:0x00a7  */
    /* JADX WARN: Removed duplicated region for block: B:26:0x00b0  */
    /* JADX WARN: Removed duplicated region for block: B:42:0x0149  */
    /* JADX WARN: Removed duplicated region for block: B:45:0x0154  */
    /* JADX WARN: Removed duplicated region for block: B:58:0x01ca  */
    /* JADX WARN: Removed duplicated region for block: B:61:0x01d3  */
    @Override // android.graphics.drawable.Drawable
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public void draw(android.graphics.Canvas r11) {
        /*
            Method dump skipped, instructions count: 533
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaBitmapDrawable.draw(android.graphics.Canvas):void");
    }

    protected void finalize() throws IOException {
        GifDecoder gifDecoder = this.n;
        if (gifDecoder != null) {
            gifDecoder.free();
        }
    }

    @Override // com.androlua.LuaGcable
    public void gc() throws IOException {
        GifDecoder gifDecoder = this.n;
        if (gifDecoder != null) {
            gifDecoder.free();
        }
        Drawable drawable = this.h;
        if (drawable != null && (drawable instanceof BitmapDrawable)) {
            ((BitmapDrawable) drawable).getBitmap().recycle();
        }
        NineBitmapDrawable nineBitmapDrawable = this.i;
        if (nineBitmapDrawable != null) {
            nineBitmapDrawable.gc();
        }
        this.n = null;
        this.h = null;
        this.i = null;
        this.g.setState(-1);
        this.q = true;
    }

    @Override // android.graphics.drawable.Drawable
    public int getIntrinsicHeight() {
        Movie movie = this.f;
        if (movie != null) {
            return movie.height();
        }
        GifDecoder gifDecoder = this.m;
        if (gifDecoder != null) {
            return gifDecoder.height;
        }
        Drawable drawable = this.h;
        if (drawable != null) {
            return drawable.getIntrinsicHeight();
        }
        NineBitmapDrawable nineBitmapDrawable = this.i;
        return nineBitmapDrawable != null ? nineBitmapDrawable.getIntrinsicHeight() : super.getIntrinsicHeight();
    }

    @Override // android.graphics.drawable.Drawable
    public int getIntrinsicWidth() {
        Movie movie = this.f;
        if (movie != null) {
            return movie.width();
        }
        GifDecoder gifDecoder = this.m;
        if (gifDecoder != null) {
            return gifDecoder.width;
        }
        Drawable drawable = this.h;
        if (drawable != null) {
            return drawable.getIntrinsicWidth();
        }
        NineBitmapDrawable nineBitmapDrawable = this.i;
        return nineBitmapDrawable != null ? nineBitmapDrawable.getIntrinsicWidth() : super.getIntrinsicWidth();
    }

    @Override // android.graphics.drawable.Drawable
    public int getOpacity() {
        return 0;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.q;
    }

    @Override // java.lang.Runnable
    public void run() {
        invalidateSelf();
    }

    @Override // android.graphics.drawable.Drawable
    public void setAlpha(int i) {
    }

    @Override // android.graphics.drawable.Drawable
    public void setColorFilter(ColorFilter colorFilter) {
        this.j = colorFilter;
    }

    public void setFillColor(int i) {
        if (i == this.k) {
            return;
        }
        this.k = i;
    }

    public void setScaleType(int i) {
        if (this.l != i) {
            this.l = i;
            invalidateSelf();
        }
    }
}