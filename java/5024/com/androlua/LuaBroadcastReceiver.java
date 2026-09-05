package com.androlua;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaBroadcastReceiver extends BroadcastReceiver {
    private OnReceiveListener a;

    public interface OnReceiveListener {
        void onReceive(Context context, Intent intent);
    }

    public LuaBroadcastReceiver(OnReceiveListener onReceiveListener) {
        this.a = onReceiveListener;
    }

    @Override // android.content.BroadcastReceiver
    public void onReceive(Context context, Intent intent) {
        this.a.onReceive(context, intent);
    }
}