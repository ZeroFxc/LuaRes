package com.androlua.util;

import android.util.Log;
import android.view.accessibility.AccessibilityNodeInfo;
import com.androlua.LuaAccessibilityService;
import com.luajava.LuaTable;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class ClickRunnable implements Runnable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaAccessibilityService f954a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaTable f955b;
    private ClickCallback f;
    private ClickRunnable h;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private int f956c = 1;
    private int d = -1;
    private int e = -1;
    private boolean g = false;

    public interface ClickCallback {
        void onDone(boolean z, LuaTable luaTable, String str, int i);
    }

    public ClickRunnable(LuaAccessibilityService luaAccessibilityService, LuaTable luaTable) {
        this.f954a = luaAccessibilityService;
        this.f955b = luaTable;
    }

    private boolean a(String str) {
        if (str == null) {
            return false;
        }
        int iLastIndexOf = str.lastIndexOf("$");
        long jLongValue = 1000;
        if (iLastIndexOf > 0) {
            try {
                jLongValue = Long.valueOf(str.substring(iLastIndexOf + 1)).longValue();
            } catch (Exception unused) {
            }
            str = str.substring(0, iLastIndexOf);
        }
        int iLastIndexOf2 = str.lastIndexOf(">");
        if (iLastIndexOf2 > 0) {
            if (this.d < 0) {
                try {
                    this.d = Integer.valueOf(str.substring(iLastIndexOf2 + 1)).intValue();
                } catch (Exception unused2) {
                    this.d = -1;
                }
            }
            str = str.substring(0, iLastIndexOf2);
        }
        int iLastIndexOf3 = str.lastIndexOf("<");
        if (iLastIndexOf3 > 0) {
            if (this.e < 0) {
                try {
                    this.e = Integer.valueOf(str.substring(iLastIndexOf3 + 1)).intValue();
                } catch (Exception unused3) {
                    this.e = -1;
                }
            }
            str = str.substring(0, iLastIndexOf3);
        }
        this.e--;
        this.d--;
        AccessibilityNodeInfo accessibilityNodeInfoFindAccessibilityNodeInfo = this.f954a.findAccessibilityNodeInfo(str);
        Log.i("lua", "findAccessibilityNodeInfo " + str + "," + this.d + "," + this.e + "," + accessibilityNodeInfoFindAccessibilityNodeInfo);
        if (accessibilityNodeInfoFindAccessibilityNodeInfo != null) {
            this.d = -1;
            this.f954a.toClick2(accessibilityNodeInfoFindAccessibilityNodeInfo);
        } else if (this.d <= 0 && this.e <= 0) {
            ClickCallback clickCallback = this.f;
            if (clickCallback != null) {
                clickCallback.onDone(true, this.f955b, str, this.f956c);
            }
            return false;
        }
        this.f954a.getHandler().postDelayed(this, jLongValue);
        return true;
    }

    public boolean canClick() {
        String str;
        AccessibilityNodeInfo accessibilityNodeInfoFindAccessibilityNodeInfo;
        String str2;
        if (this.f955b.length() == 0) {
            return false;
        }
        int length = this.f955b.length();
        int i = 0;
        while (i < length) {
            if (this.g) {
                ClickCallback clickCallback = this.f;
                if (clickCallback != null) {
                    clickCallback.onDone(false, this.f955b, null, -1);
                }
                return false;
            }
            int i2 = i + 1;
            Object obj = this.f955b.get(Integer.valueOf(i2));
            if (obj instanceof LuaTable) {
                LuaTable luaTable = (LuaTable) obj;
                if (luaTable.length() != 0 && (str2 = (String) luaTable.get(1)) != null && a(str2)) {
                    this.f955b = luaTable;
                    return true;
                }
            } else if ((obj instanceof String) && (accessibilityNodeInfoFindAccessibilityNodeInfo = this.f954a.findAccessibilityNodeInfo((str = (String) obj))) != null) {
                this.f954a.toClick2(accessibilityNodeInfoFindAccessibilityNodeInfo);
                ClickCallback clickCallback2 = this.f;
                if (clickCallback2 != null) {
                    clickCallback2.onDone(true, this.f955b, str, i);
                }
                return true;
            }
            i = i2;
        }
        ClickCallback clickCallback3 = this.f;
        if (clickCallback3 != null) {
            clickCallback3.onDone(false, this.f955b, null, -1);
        }
        return false;
    }

    public boolean canClick(ClickCallback clickCallback) {
        this.f = clickCallback;
        return canClick();
    }

    public void cancel() {
        this.g = true;
        ClickRunnable clickRunnable = this.h;
        if (clickRunnable != null) {
            clickRunnable.cancel();
        }
    }

    @Override // java.lang.Runnable
    public void run() {
        if (this.g) {
            ClickCallback clickCallback = this.f;
            if (clickCallback != null) {
                clickCallback.onDone(false, this.f955b, null, -1);
                return;
            }
            return;
        }
        if (this.d < 0 && this.e < 0) {
            this.f956c++;
        }
        Object obj = this.f955b.get(Integer.valueOf(this.f956c));
        if (obj == null) {
            ClickCallback clickCallback2 = this.f;
            if (clickCallback2 != null) {
                clickCallback2.onDone(this.f956c == this.f955b.length(), this.f955b, null, this.f956c);
                return;
            }
            return;
        }
        if (!(obj instanceof LuaTable)) {
            if (obj instanceof String) {
                a((String) obj);
            }
        } else {
            LuaTable luaTable = (LuaTable) obj;
            if (luaTable.length() == 0) {
                return;
            }
            this.h = new ClickRunnable(this.f954a, luaTable);
            this.h.canClick(new ClickCallback() { // from class: com.androlua.util.ClickRunnable.1
                @Override // com.androlua.util.ClickRunnable.ClickCallback
                public void onDone(boolean z, LuaTable luaTable2, String str, int i) {
                    ClickRunnable.this.h = null;
                    ClickRunnable.this.run();
                }
            });
        }
    }
}