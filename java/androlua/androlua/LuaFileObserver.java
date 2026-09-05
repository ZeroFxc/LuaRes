package com.androlua;

import android.os.FileObserver;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaFileObserver extends FileObserver {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private OnEventListener f803a;

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
        OnEventListener onEventListener = this.f803a;
        if (onEventListener != null) {
            onEventListener.onEvent(i, str);
        }
    }

    public void setOnEventListener(OnEventListener onEventListener) {
        this.f803a = onEventListener;
    }
}