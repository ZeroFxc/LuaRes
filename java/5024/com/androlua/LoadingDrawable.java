package com.androlua;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.util.DisplayMetrics;
import android.util.TypedValue;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LoadingDrawable extends Drawable {
    private final DisplayMetrics a;
    private int b = 0;
    private int c = 0;
    private int d = 0;
    private int e = 0;
    private int f = 3;
    private int g = 1;
    private Paint h = new Paint();
    private int i;

    public LoadingDrawable(Context context) {
        this.a = context.getResources().getDisplayMetrics();
        this.h.setStyle(Paint.Style.STROKE);
        this.h.setAntiAlias(true);
        this.h.setStrokeWidth(a(8.0f));
        this.h.setColor(-2004318072);
    }

    private int a(float f) {
        return (int) TypedValue.applyDimension(1, f, this.a);
    }

    @Override // android.graphics.drawable.Drawable
    public void draw(Canvas canvas) {
        int i;
        int i2;
        Rect rect = new Rect(getBounds());
        int i3 = rect.right - iMin;
        int i4 = rect.bottom - iMin;
        rect.right = iMin;
        rect.bottom = iMin;
        canvas.save();
        canvas.translate(i3 / 2, i4 / 2);
        float f = iMin;
        float f2 = 0.15f * f;
        float f3 = f * 0.85f;
        RectF rectF = new RectF(f2, f2, f3, f3);
        if (this.b >= 360 && this.i == 0) {
            this.g = 8;
            this.f = -6;
        } else if (this.b <= 6) {
            this.f = 6;
            this.g = 2;
        }
        if (this.b < 360 || this.i == 0) {
            if (this.i == 0) {
                this.b += this.f;
                i = this.c;
                i2 = this.g;
            } else {
                this.b += this.f * 2;
                i = this.c;
                i2 = this.g * 2;
            }
            this.c = i + i2;
            this.c %= 360;
        }
        canvas.drawArc(rectF, this.c, this.b, false, this.h);
        if (this.b >= 360) {
            this.f = -6;
            this.g = 8;
            int i5 = this.i;
            if (i5 == 1) {
                Path path = new Path();
                path.moveTo(rect.right * 0.3f, rect.bottom * 0.5f);
                path.lineTo(rect.right * 0.45f, rect.bottom * 0.7f);
                path.lineTo(rect.right * 0.75f, rect.bottom * 0.4f);
                canvas.drawPath(path, this.h);
            } else if (i5 == -1) {
                int i6 = rect.right;
                int i7 = rect.bottom;
                canvas.drawLine(i6 / 2, 0.25f * i7, i6 / 2, i7 * 0.65f, this.h);
                int i8 = rect.right;
                int i9 = rect.bottom;
                canvas.drawLine(i8 / 2, i9 * 0.7f, i8 / 2, i9 * 0.75f, this.h);
            }
        }
        canvas.restore();
        invalidateSelf();
    }

    @Override // android.graphics.drawable.Drawable
    public int getOpacity() {
        return 0;
    }

    @Override // android.graphics.drawable.Drawable
    public void setAlpha(int i) {
        this.h.setAlpha(i);
    }

    public void setColor(int i) {
        this.h.setColor(i);
    }

    @Override // android.graphics.drawable.Drawable
    public void setColorFilter(ColorFilter colorFilter) {
        this.h.setColorFilter(colorFilter);
    }

    public void setState(int i) {
        this.i = i;
    }

    public void setStrokeWidth(float f) {
        this.h.setStrokeWidth(f);
    }
}