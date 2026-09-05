package com.androlua.util;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.annotation.TargetApi;
import android.graphics.Path;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.ViewConfiguration;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class GlobalActionAutomator {
    private AccessibilityService a;
    private ScreenMetrics b;
    private Handler c;

    @TargetApi(24)
    public GlobalActionAutomator(AccessibilityService accessibilityService, Handler handler) {
        this.a = accessibilityService;
        this.c = handler;
    }

    private Path a(int[][] iArr) {
        Path path = new Path();
        path.moveTo(b(iArr[0][0]), c(iArr[0][1]));
        for (int i = 1; i < iArr.length; i++) {
            int[] iArr2 = iArr[i];
            path.lineTo(b(iArr2[0]), c(iArr2[1]));
        }
        return path;
    }

    private void a() {
        if (Looper.myLooper() == null) {
            Looper.prepare();
        }
    }

    @TargetApi(16)
    private boolean a(int i) {
        AccessibilityService accessibilityService = this.a;
        if (accessibilityService == null) {
            return false;
        }
        return accessibilityService.performGlobalAction(i);
    }

    private boolean a(GestureDescription gestureDescription) {
        final VolatileDispose volatileDispose = new VolatileDispose();
        Log.i("GlobalActionAutomator", "dispatchGesture");
        return this.a.dispatchGesture(gestureDescription, new AccessibilityService.GestureResultCallback() { // from class: com.androlua.util.GlobalActionAutomator.1
            @Override // android.accessibilityservice.AccessibilityService.GestureResultCallback
            public void onCancelled(GestureDescription gestureDescription2) {
                Log.i("GlobalActionAutomator", "onCancelled");
                volatileDispose.setAndNotify(false);
            }

            @Override // android.accessibilityservice.AccessibilityService.GestureResultCallback
            public void onCompleted(GestureDescription gestureDescription2) {
                Log.i("GlobalActionAutomator", "onCompleted");
                volatileDispose.setAndNotify(true);
            }
        }, this.c);
    }

    private int b(int i) {
        ScreenMetrics screenMetrics = this.b;
        return screenMetrics == null ? i : screenMetrics.scaleX(i);
    }

    private void b() {
        Looper looperMyLooper = Looper.myLooper();
        if (looperMyLooper != null) {
            looperMyLooper.quit();
        }
    }

    private boolean b(GestureDescription gestureDescription) {
        a();
        final VolatileBox volatileBox = new VolatileBox(false);
        this.a.dispatchGesture(gestureDescription, new AccessibilityService.GestureResultCallback() { // from class: com.androlua.util.GlobalActionAutomator.2
            @Override // android.accessibilityservice.AccessibilityService.GestureResultCallback
            public void onCancelled(GestureDescription gestureDescription2) {
                volatileBox.set(false);
                GlobalActionAutomator.this.b();
            }

            @Override // android.accessibilityservice.AccessibilityService.GestureResultCallback
            public void onCompleted(GestureDescription gestureDescription2) {
                volatileBox.set(true);
                GlobalActionAutomator.this.b();
            }
        }, new Handler(Looper.myLooper()));
        Looper.loop();
        return ((Boolean) volatileBox.get()).booleanValue();
    }

    private int c(int i) {
        ScreenMetrics screenMetrics = this.b;
        return screenMetrics == null ? i : screenMetrics.scaleY(i);
    }

    public boolean back() {
        return a(1);
    }

    public boolean click(int i, int i2) {
        return press(i, i2, ViewConfiguration.getTapTimeout());
    }

    public boolean gesture(long j, long j2, Path path) {
        return gestures(new GestureDescription.StrokeDescription(path, j, j2));
    }

    public boolean gesture(long j, long j2, int[]... iArr) {
        return gestures(new GestureDescription.StrokeDescription(a(iArr), j, j2));
    }

    public void gestureAsync(long j, long j2, int[]... iArr) {
        gesturesAsync(new GestureDescription.StrokeDescription(a(iArr), j, j2));
    }

    public boolean gestures(GestureDescription.StrokeDescription... strokeDescriptionArr) {
        if (this.a == null) {
            return false;
        }
        GestureDescription.Builder builder = new GestureDescription.Builder();
        for (GestureDescription.StrokeDescription strokeDescription : strokeDescriptionArr) {
            builder.addStroke(strokeDescription);
        }
        return this.c == null ? b(builder.build()) : a(builder.build());
    }

    public void gesturesAsync(GestureDescription.StrokeDescription... strokeDescriptionArr) {
        if (this.a == null) {
            return;
        }
        GestureDescription.Builder builder = new GestureDescription.Builder();
        for (GestureDescription.StrokeDescription strokeDescription : strokeDescriptionArr) {
            builder.addStroke(strokeDescription);
        }
        this.a.dispatchGesture(builder.build(), null, null);
    }

    public boolean home() {
        return a(2);
    }

    public boolean longClick(int i, int i2) {
        return gesture(0L, ViewConfiguration.getLongPressTimeout() + 200, new int[]{i, i2});
    }

    public boolean notifications() {
        return a(4);
    }

    public boolean powerDialog() {
        return a(6);
    }

    public boolean press(int i, int i2, int i3) {
        return gesture(0L, i3, new int[]{i, i2});
    }

    public boolean quickSettings() {
        return a(5);
    }

    public boolean recents() {
        return a(3);
    }

    public void setScreenMetrics(ScreenMetrics screenMetrics) {
        this.b = screenMetrics;
    }

    public void setService(AccessibilityService accessibilityService) {
        this.a = accessibilityService;
    }

    public boolean splitScreen() {
        return a(7);
    }

    public boolean swipe(int i, int i2, int i3, int i4, int i5) {
        return gesture(0L, i5, new int[]{i, i2}, new int[]{i3, i4});
    }
}