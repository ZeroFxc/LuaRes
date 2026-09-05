package com.androlua.util;

import android.content.pm.PackageManager;
import android.util.Log;
import android.view.accessibility.AccessibilityNodeInfo;
import com.androlua.LuaAccessibilityService;
import com.luajava.LuaTable;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class ClickRunnable implements Runnable {
    private final LuaAccessibilityService a;
    private LuaTable b;
    private ClickCallback f;
    private ClickRunnable h;
    private int c = 1;
    private int d = -1;
    private int e = -1;
    private boolean g = false;

    /* renamed from: com.androlua.util.ClickRunnable$1 */
    class AnonymousClass1 implements ClickCallback {
        AnonymousClass1() {
        }

        @Override // com.androlua.util.ClickRunnable.ClickCallback
        public void onDone(boolean z, LuaTable luaTable, String str, int i) throws PackageManager.NameNotFoundException, NumberFormatException {
            ClickRunnable.this.h = null;
            ClickRunnable.this.run();
        }
    }

    public interface ClickCallback {
        void onDone(boolean z, LuaTable luaTable, String str, int i);
    }

    public ClickRunnable(LuaAccessibilityService luaAccessibilityService, LuaTable luaTable) {
        this.a = luaAccessibilityService;
        this.b = luaTable;
    }

    private boolean a(String str) throws PackageManager.NameNotFoundException, NumberFormatException {
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
        AccessibilityNodeInfo accessibilityNodeInfoFindAccessibilityNodeInfo = this.a.findAccessibilityNodeInfo(str);
        Log.i("lua", "findAccessibilityNodeInfo " + str + "," + this.d + "," + this.e + "," + accessibilityNodeInfoFindAccessibilityNodeInfo);
        if (accessibilityNodeInfoFindAccessibilityNodeInfo != null) {
            this.d = -1;
            this.a.toClick2(accessibilityNodeInfoFindAccessibilityNodeInfo);
        } else if (this.d <= 0 && this.e <= 0) {
            ClickCallback clickCallback = this.f;
            if (clickCallback != null) {
                clickCallback.onDone(true, this.b, str, this.c);
            }
            return false;
        }
        this.a.getHandler().postDelayed(this, jLongValue);
        return true;
    }

    public boolean canClick() {
        String str;
        AccessibilityNodeInfo accessibilityNodeInfoFindAccessibilityNodeInfo;
        String str2;
        if (this.b.length() == 0) {
            return false;
        }
        int length = this.b.length();
        int i = 0;
        while (i < length) {
            if (this.g) {
                ClickCallback clickCallback = this.f;
                if (clickCallback != null) {
                    clickCallback.onDone(false, this.b, null, -1);
                }
                return false;
            }
            int i2 = i + 1;
            Object obj = this.b.get(Integer.valueOf(i2));
            if (obj instanceof LuaTable) {
                LuaTable luaTable = (LuaTable) obj;
                if (luaTable.length() != 0 && (str2 = (String) luaTable.get(1)) != null && a(str2)) {
                    this.b = luaTable;
                    return true;
                }
            } else if ((obj instanceof String) && (accessibilityNodeInfoFindAccessibilityNodeInfo = this.a.findAccessibilityNodeInfo((str = (String) obj))) != null) {
                this.a.toClick2(accessibilityNodeInfoFindAccessibilityNodeInfo);
                ClickCallback clickCallback2 = this.f;
                if (clickCallback2 != null) {
                    clickCallback2.onDone(true, this.b, str, i);
                }
                return true;
            }
            i = i2;
        }
        ClickCallback clickCallback3 = this.f;
        if (clickCallback3 != null) {
            clickCallback3.onDone(false, this.b, null, -1);
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
    public void run() throws PackageManager.NameNotFoundException, NumberFormatException {
        if (this.g) {
            ClickCallback clickCallback = this.f;
            if (clickCallback != null) {
                clickCallback.onDone(false, this.b, null, -1);
                return;
            }
            return;
        }
        if (this.d < 0 && this.e < 0) {
            this.c++;
        }
        Object obj = this.b.get(Integer.valueOf(this.c));
        if (obj == null) {
            ClickCallback clickCallback2 = this.f;
            if (clickCallback2 != null) {
                clickCallback2.onDone(this.c == this.b.length(), this.b, null, this.c);
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
            this.h = new ClickRunnable(this.a, luaTable);
            this.h.canClick(new ClickCallback() { // from class: com.androlua.util.ClickRunnable.1
                AnonymousClass1() {
                }

                @Override // com.androlua.util.ClickRunnable.ClickCallback
                public void onDone(boolean z, LuaTable luaTable2, String str, int i) throws PackageManager.NameNotFoundException, NumberFormatException {
                    ClickRunnable.this.h = null;
                    ClickRunnable.this.run();
                }
            });
        }
    }
}