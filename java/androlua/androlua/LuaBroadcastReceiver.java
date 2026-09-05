package com.androlua;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaBroadcastReceiver extends BroadcastReceiver {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private OnReceiveListener f761a;

    public interface OnReceiveListener {
        void onReceive(Context context, Intent intent);
    }

    public LuaBroadcastReceiver(OnReceiveListener onReceiveListener) {
        this.f761a = onReceiveListener;
    }

    @Override // android.content.BroadcastReceiver
    public void onReceive(Context context, Intent intent) {
        this.f761a.onReceive(context, intent);
    }
}