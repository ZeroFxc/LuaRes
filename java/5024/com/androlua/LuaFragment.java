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

@SuppressLint({"ValidFragment"})
/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaFragment extends Fragment {
    private LuaTable a;
    private LuaObject b;
    private View c;

    public LuaFragment(View view) {
        this.a = null;
        this.b = null;
        this.c = view;
    }

    public LuaFragment(LuaTable luaTable) {
        this.a = null;
        this.b = null;
        this.a = luaTable;
    }

    @Override // android.app.Fragment
    public View onCreateView(LayoutInflater layoutInflater, ViewGroup viewGroup, Bundle bundle) {
        try {
            return this.c != null ? this.c : this.a != null ? (View) ((LuaObject) this.a.getLuaState().getLuaObject("require").call("loadlayout")).call(this.a) : new TextView(getActivity());
        } catch (Exception e) {
            throw new IllegalArgumentException(e.getMessage());
        }
    }

    public void setLayout(View view) {
        this.c = view;
        this.a = null;
    }

    public void setLayout(LuaTable luaTable) {
        this.a = luaTable;
        this.c = null;
    }
}