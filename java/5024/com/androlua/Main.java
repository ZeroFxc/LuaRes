package com.androlua;

import android.content.Intent;
import android.os.Bundle;
import com.baidu.mobstat.StatService;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class Main extends LuaActivity {
    private void a(String str, String str2) {
        runFunc("onVersionChanged", str, str2);
    }

    @Override // com.androlua.LuaActivity, com.androlua.LuaContext
    public String getLuaDir() {
        return getLocalDir();
    }

    @Override // com.androlua.LuaActivity, com.androlua.LuaContext
    public String getLuaPath() {
        initMain();
        return getLocalDir() + "/main.lua";
    }

    @Override // com.androlua.LuaActivity, android.app.Activity
    public void onCreate(Bundle bundle) throws IllegalAccessException, NoSuchFieldException, InstantiationException, IllegalArgumentException {
        super.onCreate(bundle);
        if (bundle == null && getIntent().getData() != null) {
            runFunc("onNewIntent", getIntent());
        }
        if (getIntent().getBooleanExtra("isVersionChanged", false) && bundle == null) {
            a(getIntent().getStringExtra("newVersionName"), getIntent().getStringExtra("oldVersionName"));
        }
        StatService.start(this);
    }

    @Override // android.app.Activity
    protected void onNewIntent(Intent intent) {
        runFunc("onNewIntent", intent);
        super.onNewIntent(intent);
    }
}