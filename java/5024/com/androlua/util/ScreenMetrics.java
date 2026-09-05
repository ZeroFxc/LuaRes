package com.androlua.util;

import android.app.Activity;
import android.util.DisplayMetrics;
import android.view.Display;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class ScreenMetrics {
    private static int a;
    private static int b;
    private static boolean c;
    private static int d;
    private static Display e;
    private int f;
    private int g;

    public ScreenMetrics() {
    }

    public ScreenMetrics(int i, int i2) {
        this.f = i;
        this.g = i2;
    }

    public static int getDeviceScreenDensity() {
        return d;
    }

    public static int getDeviceScreenHeight() {
        return a;
    }

    public static int getDeviceScreenWidth() {
        return b;
    }

    public static void initIfNeeded(Activity activity) {
        if (c) {
            return;
        }
        DisplayMetrics displayMetrics = new DisplayMetrics();
        activity.getWindowManager().getDefaultDisplay().getRealMetrics(displayMetrics);
        a = displayMetrics.heightPixels;
        b = displayMetrics.widthPixels;
        d = displayMetrics.densityDpi;
        e = activity.getWindowManager().getDefaultDisplay();
        c = true;
    }

    public static int rescaleX(int i, int i2) {
        return (i2 == 0 || !c) ? i : (i * i2) / b;
    }

    public static int rescaleY(int i, int i2) {
        return (i2 == 0 || !c) ? i : (i * i2) / a;
    }

    public static int scaleX(int i, int i2) {
        return (i2 == 0 || !c) ? i : (i * b) / i2;
    }

    public static int scaleY(int i, int i2) {
        return (i2 == 0 || !c) ? i : (i * a) / i2;
    }

    public int rescaleX(int i) {
        return rescaleX(i, this.f);
    }

    public int rescaleY(int i) {
        return rescaleY(i, this.g);
    }

    public int scaleX(int i) {
        return scaleX(i, this.f);
    }

    public int scaleY(int i) {
        return scaleY(i, this.g);
    }

    public void setDesignHeight(int i) {
        this.g = i;
    }

    public void setDesignWidth(int i) {
        this.f = i;
    }

    public void setScreenMetrics(int i, int i2) {
        this.f = i;
        this.g = i2;
    }
}