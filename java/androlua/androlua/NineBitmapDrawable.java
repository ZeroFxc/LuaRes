package com.androlua;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class NineBitmapDrawable extends Drawable implements LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private Paint f921a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private Bitmap f922b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private int f923c;
    private int d;
    private int e;
    private int f;
    private Rect g;
    private Rect h;
    private Rect i;
    private Rect j;
    private Rect k;
    private Rect l;
    private Rect m;
    private Rect n;
    private Rect o;
    private boolean p;
    private int q;
    private int r;

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public NineBitmapDrawable(Bitmap bitmap) {
        int i;
        int i2;
        int i3;
        int i4;
        this.f921a = new Paint();
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        for (int i5 = 0; i5 < width; i5++) {
            int pixel = bitmap.getPixel(i5, 0);
            if (pixel == -16777216) {
                i = i5;
                break;
            } else {
                if (pixel != -1 && pixel != 0) {
                    break;
                }
            }
        }
        i = 0;
        if (i == 0 || i == width - 1) {
            throw new IllegalArgumentException("not found x1");
        }
        int i6 = i;
        while (true) {
            if (i6 >= width) {
                i2 = 0;
                break;
            } else {
                if (bitmap.getPixel(i6, 0) != -16777216) {
                    i2 = width - i6;
                    break;
                }
                i6++;
            }
        }
        if (i2 == 0 || i2 == 1) {
            throw new IllegalArgumentException("not found x2");
        }
        for (int i7 = 0; i7 < height; i7++) {
            int pixel2 = bitmap.getPixel(0, i7);
            if (pixel2 == -16777216) {
                i3 = i7;
                break;
            } else {
                if (pixel2 != -1 && pixel2 != 0) {
                    break;
                }
            }
        }
        i3 = 0;
        if (i3 == 0 || i3 == height - 1) {
            throw new IllegalArgumentException("not found y1");
        }
        int i8 = i3;
        while (true) {
            if (i8 >= height) {
                i4 = 0;
                break;
            } else {
                if (bitmap.getPixel(0, i8) != -16777216) {
                    i4 = height - i8;
                    break;
                }
                i8++;
            }
        }
        if (i4 == 0 || i4 == 1) {
            throw new IllegalArgumentException("not found y2");
        }
        a(bitmap, i, i3, i2, i4);
    }

    public NineBitmapDrawable(Bitmap bitmap, int i, int i2, int i3, int i4) {
        this.f921a = new Paint();
        a(bitmap, i, i2, i3, i4);
    }

    public NineBitmapDrawable(String str) {
        this(LuaBitmap.getLocalBitmap(str));
    }

    private void a(Bitmap bitmap, int i, int i2, int i3, int i4) {
        this.f922b = bitmap;
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        this.g = new Rect(1, 1, i, i2);
        this.h = new Rect(i, 1, i3, i2);
        int i5 = width - 1;
        this.i = new Rect(i3, 1, i5, i2);
        this.j = new Rect(1, i2, i, i4);
        this.k = new Rect(i, i2, i3, i4);
        this.l = new Rect(i3, i2, i5, i4);
        int i6 = height - 1;
        this.m = new Rect(1, i4, i, i6);
        this.n = new Rect(i, i4, i3, i6);
        this.o = new Rect(i3, i4, i5, i6);
        this.f923c = i;
        this.d = i2;
        this.e = width - i3;
        this.f = height - i4;
        this.r = width;
        this.q = height;
    }

    @Override // android.graphics.drawable.Drawable
    public void draw(Canvas canvas) {
        Rect bounds = getBounds();
        int i = bounds.right;
        int i2 = bounds.bottom;
        float fMin = Math.min((i * 1.0f) / this.r, (i2 * 1.0f) / this.q);
        int i3 = (int) (this.f923c * fMin);
        int i4 = (int) (this.e * fMin);
        int i5 = (int) (this.d * fMin);
        Rect rect = new Rect(0, 0, i3, i5);
        int i6 = i - i4;
        Rect rect2 = new Rect(i3, 0, i6, i5);
        Rect rect3 = new Rect(i6, 0, i, i5);
        int i7 = i2 - ((int) (this.f * fMin));
        Rect rect4 = new Rect(0, i5, i3, i7);
        Rect rect5 = new Rect(i3, i5, i6, i7);
        Rect rect6 = new Rect(i6, i5, i, i7);
        Rect rect7 = new Rect(0, i7, i3, i2);
        Rect rect8 = new Rect(i3, i7, i6, i2);
        Rect rect9 = new Rect(i6, i7, i, i2);
        canvas.drawBitmap(this.f922b, this.g, rect, this.f921a);
        canvas.drawBitmap(this.f922b, this.h, rect2, this.f921a);
        canvas.drawBitmap(this.f922b, this.i, rect3, this.f921a);
        canvas.drawBitmap(this.f922b, this.j, rect4, this.f921a);
        canvas.drawBitmap(this.f922b, this.k, rect5, this.f921a);
        canvas.drawBitmap(this.f922b, this.l, rect6, this.f921a);
        canvas.drawBitmap(this.f922b, this.m, rect7, this.f921a);
        canvas.drawBitmap(this.f922b, this.n, rect8, this.f921a);
        canvas.drawBitmap(this.f922b, this.o, rect9, this.f921a);
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        try {
            this.f922b.recycle();
            this.p = true;
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override // android.graphics.drawable.Drawable
    public int getOpacity() {
        return 0;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.p;
    }

    @Override // android.graphics.drawable.Drawable
    public void setAlpha(int i) {
        this.f921a.setAlpha(i);
    }

    @Override // android.graphics.drawable.Drawable
    public void setColorFilter(ColorFilter colorFilter) {
        this.f921a.setColorFilter(colorFilter);
    }
}