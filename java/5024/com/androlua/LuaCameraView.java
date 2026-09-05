package com.androlua;

import android.content.Context;
import android.hardware.Camera;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import java.io.IOException;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
class LuaCameraView extends SurfaceView {
    private SurfaceHolder a;

    public LuaCameraView(Context context) {
        super(context);
        this.a = null;
        this.a = getHolder();
        this.a.addCallback(new SurfaceHolder.Callback() { // from class: com.androlua.LuaCameraView.1
            private Camera a;

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i2, int i3) {
                Camera.Parameters parameters = this.a.getParameters();
                parameters.setPictureFormat(256);
                parameters.setPreviewSize(854, 480);
                parameters.setFocusMode("auto");
                parameters.setPictureSize(2592, 1456);
                this.a.startPreview();
            }

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceCreated(SurfaceHolder surfaceHolder) throws IOException {
                this.a = Camera.open();
                try {
                    this.a.setPreviewDisplay(surfaceHolder);
                } catch (IOException unused) {
                    this.a = null;
                }
            }

            @Override // android.view.SurfaceHolder.Callback
            public void surfaceDestroyed(SurfaceHolder surfaceHolder) {
                this.a.stopPreview();
                this.a.release();
                this.a = null;
            }
        });
        this.a.setType(3);
    }
}