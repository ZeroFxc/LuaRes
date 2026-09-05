package com.androlua;

import android.database.ContentObserver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaContentObserver extends ContentObserver implements LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private OnChangeListener f770a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private boolean f771b;

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
        this.f771b = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.f771b;
    }

    @Override // android.database.ContentObserver
    public void onChange(boolean z, Uri uri) {
        super.onChange(z, uri);
        if (this.f770a != null) {
            Cursor cursorQuery = LuaApplication.getInstance().getContentResolver().query(uri, null, null, null, null);
            if (cursorQuery != null) {
                cursorQuery.moveToFirst();
            }
            this.f770a.onChange(z, uri, cursorQuery);
            if (cursorQuery != null) {
                cursorQuery.close();
            }
        }
    }

    public void setOnChangeListener(OnChangeListener onChangeListener) {
        this.f770a = onChangeListener;
    }
}