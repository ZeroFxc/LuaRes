package com.androlua;

import android.content.Context;
import android.hardware.Camera;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import java.io.IOException;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
class LuaCameraView extends SurfaceView {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private SurfaceHolder f762a;

    public LuaCameraView(Context context) {
        super(context);
        this.f762a = null;
        this.f762a = getHolder();
        this.f762a.addCallback(new SurfaceHolder.Callback() { // from class: com.androlua.LuaCameraView.1

            /* JADX INFO: renamed from: a, reason: collision with root package name */
            private Camera f763a;

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i2, int i3) {
                Camera.Parameters parameters = this.f763a.getParameters();
                parameters.setPictureFormat(256);
                parameters.setPreviewSize(854, 480);
                parameters.setFocusMode("auto");
                parameters.setPictureSize(2592, 1456);
                this.f763a.startPreview();
            }

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceCreated(SurfaceHolder surfaceHolder) {
                this.f763a = Camera.open();
                try {
                    this.f763a.setPreviewDisplay(surfaceHolder);
                } catch (IOException unused) {
                    this.f763a = null;
                }
            }

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceDestroyed(SurfaceHolder surfaceHolder) {
                this.f763a.stopPreview();
                this.f763a.release();
                this.f763a = null;
            }
        });
        this.f762a.setType(3);
    }
}