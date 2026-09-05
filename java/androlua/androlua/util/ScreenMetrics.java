package com.androlua.util;

import android.app.Activity;
import android.util.DisplayMetrics;
import android.view.Display;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class ScreenMetrics {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static int f968a = 0;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private static int f969b = 0;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private static boolean f970c = false;
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
        return f968a;
    }

    public static int getDeviceScreenWidth() {
        return f969b;
    }

    public static void initIfNeeded(Activity activity) {
        if (f970c) {
            return;
        }
        DisplayMetrics displayMetrics = new DisplayMetrics();
        activity.getWindowManager().getDefaultDisplay().getRealMetrics(displayMetrics);
        f968a = displayMetrics.heightPixels;
        f969b = displayMetrics.widthPixels;
        d = displayMetrics.densityDpi;
        e = activity.getWindowManager().getDefaultDisplay();
        f970c = true;
    }

    public static int rescaleX(int i, int i2) {
        return (i2 == 0 || !f970c) ? i : (i * i2) / f969b;
    }

    public static int rescaleY(int i, int i2) {
        return (i2 == 0 || !f970c) ? i : (i * i2) / f968a;
    }

    public static int scaleX(int i, int i2) {
        return (i2 == 0 || !f970c) ? i : (i * f969b) / i2;
    }

    public static int scaleY(int i, int i2) {
        return (i2 == 0 || !f970c) ? i : (i * f968a) / i2;
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