package com.androlua;

import android.os.FileObserver;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaFileObserver extends FileObserver {
    private OnEventListener a;

    public interface OnEventListener {
        void onEvent(int i, String str);
    }

    public LuaFileObserver(String str) {
        super(str);
    }

    public LuaFileObserver(String str, int i) {
        super(str, i);
    }

    @Override // android.os.FileObserver
    public void onEvent(int i, String str) {
        OnEventListener onEventListener = this.a;
        if (onEventListener != null) {
            onEventListener.onEvent(i, str);
        }
    }

    public void setOnEventListener(OnEventListener onEventListener) {
        this.a = onEventListener;
    }
}