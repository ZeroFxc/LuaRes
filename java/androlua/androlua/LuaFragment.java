package com.androlua;

import android.annotation.SuppressLint;
import android.app.Fragment;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import com.luajava.LuaObject;
import com.luajava.LuaTable;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
@SuppressLint({"ValidFragment"})
public class LuaFragment extends Fragment {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private LuaTable f804a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaObject f805b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private View f806c;

    public LuaFragment(View view) {
        this.f804a = null;
        this.f805b = null;
        this.f806c = view;
    }

    public LuaFragment(LuaTable luaTable) {
        this.f804a = null;
        this.f805b = null;
        this.f804a = luaTable;
    }

    @Override // android.app.Fragment
    public View onCreateView(LayoutInflater layoutInflater, ViewGroup viewGroup, Bundle bundle) {
        try {
            return this.f806c != null ? this.f806c : this.f804a != null ? (View) ((LuaObject) this.f804a.getLuaState().getLuaObject("require").call("loadlayout")).call(this.f804a) : new TextView(getActivity());
        } catch (Exception e) {
            throw new IllegalArgumentException(e.getMessage());
        }
    }

    public void setLayout(View view) {
        this.f806c = view;
        this.f804a = null;
    }

    public void setLayout(LuaTable luaTable) {
        this.f804a = luaTable;
        this.f806c = null;
    }
}