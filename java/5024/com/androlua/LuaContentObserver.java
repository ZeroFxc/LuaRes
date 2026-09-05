package com.androlua;

import android.database.ContentObserver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaContentObserver extends ContentObserver implements LuaGcable {
    private OnChangeListener a;
    private boolean b;

    public interface OnChangeListener {
        void onChange(boolean z, Uri uri, Cursor cursor);
    }

    private LuaContentObserver(Handler handler) {
        super(handler);
    }

    public LuaContentObserver(LuaContext luaContext, Uri uri) {
        this(new Handler(LuaApplication.getInstance().getMainLooper()));
        luaContext.regGc(this);
        LuaApplication.getInstance().getContentResolver().registerContentObserver(uri, true, this);
    }

    public LuaContentObserver(LuaContext luaContext, String str) {
        this(new Handler(LuaApplication.getInstance().getMainLooper()));
        Uri uri = Uri.parse(str);
        luaContext.regGc(this);
        LuaApplication.getInstance().getContentResolver().registerContentObserver(uri, true, this);
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        LuaApplication.getInstance().getContentResolver().unregisterContentObserver(this);
        this.b = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.b;
    }

    @Override // android.database.ContentObserver
    public void onChange(boolean z, Uri uri) {
        super.onChange(z, uri);
        if (this.a != null) {
            Cursor cursorQuery = LuaApplication.getInstance().getContentResolver().query(uri, null, null, null, null);
            if (cursorQuery != null) {
                cursorQuery.moveToFirst();
            }
            this.a.onChange(z, uri, cursorQuery);
            if (cursorQuery != null) {
                cursorQuery.close();
            }
        }
    }

    public void setOnChangeListener(OnChangeListener onChangeListener) {
        this.a = onChangeListener;
    }
}