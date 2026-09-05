package com.androlua;

import android.app.Application;
import android.content.Context;
import android.content.FileProvider;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.widget.Toast;
import com.luajava.LuaState;
import com.luajava.LuaTable;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaApplication extends Application implements LuaContext {
    private static LuaApplication a;
    private static HashMap<String, Object> b = new HashMap<>();
    protected String c;
    protected String d;
    protected String e;
    protected String f;
    protected String g;
    protected String h;
    protected String i;
    private SharedPreferences j;

    private static SharedPreferences a(Context context) {
        Context contextCreateDeviceProtectedStorageContext;
        if (Build.VERSION.SDK_INT >= 24 && (contextCreateDeviceProtectedStorageContext = context.createDeviceProtectedStorageContext()) != null) {
            return PreferenceManager.getDefaultSharedPreferences(contextCreateDeviceProtectedStorageContext);
        }
        return PreferenceManager.getDefaultSharedPreferences(context);
    }

    public static LuaApplication getInstance() {
        return a;
    }

    @Override // com.androlua.LuaContext
    public void call(String str, Object[] objArr) {
    }

    @Override // com.androlua.LuaContext
    public Object doFile(String str, Object[] objArr) {
        return null;
    }

    public Object get(String str) {
        return b.get(str);
    }

    @Override // com.androlua.LuaContext
    public ArrayList<ClassLoader> getClassLoaders() {
        return null;
    }

    @Override // com.androlua.LuaContext
    public Context getContext() {
        return this;
    }

    @Override // com.androlua.LuaContext
    public Map getGlobalData() {
        return b;
    }

    @Override // com.androlua.LuaContext
    public int getHeight() {
        return getResources().getDisplayMetrics().heightPixels;
    }

    public String getLibDir() {
        return this.e;
    }

    public String getLocalDir() {
        return this.c;
    }

    @Override // com.androlua.LuaContext
    public String getLuaCpath() {
        return this.g;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir() {
        return this.c;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir(String str) {
        return this.c;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir() {
        return this.i;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir(String str) {
        File file = new File(getLuaExtDir(), str);
        return (file.exists() || file.mkdirs()) ? file.getAbsolutePath() : file.getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtPath(String str) {
        return new File(getLuaExtDir(), str).getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtPath(String str, String str2) {
        return new File(getLuaExtDir(str), str2).getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public String getLuaLpath() {
        return this.h;
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath() {
        return null;
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath(String str) {
        return new File(getLuaDir(), str).getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath(String str, String str2) {
        return new File(getLuaDir(str), str2).getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public LuaState getLuaState() {
        return null;
    }

    public String getMdDir() {
        return this.f;
    }

    public String getOdexDir() {
        return this.d;
    }

    /* JADX WARN: Removed duplicated region for block: B:14:0x0033  */
    /* JADX WARN: Removed duplicated region for block: B:16:0x0036  */
    /* JADX WARN: Removed duplicated region for block: B:19:0x003e  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.lang.String getPathFromUri(android.net.Uri r8) {
        /*
            r7 = this;
            if (r8 == 0) goto L63
            r0 = 1
            java.lang.String[] r3 = new java.lang.String[r0]
            java.lang.String r1 = r7.getPackageName()
            r2 = 0
            r3[r2] = r1
            java.lang.String r1 = r8.getScheme()
            r4 = -1
            int r5 = r1.hashCode()
            r6 = 3143036(0x2ff57c, float:4.404332E-39)
            if (r5 == r6) goto L29
            r6 = 951530617(0x38b73479, float:8.735894E-5)
            if (r5 == r6) goto L20
            goto L33
        L20:
            java.lang.String r5 = "content"
            boolean r1 = r1.equals(r5)
            if (r1 == 0) goto L33
            goto L34
        L29:
            java.lang.String r2 = "file"
            boolean r1 = r1.equals(r2)
            if (r1 == 0) goto L33
            r2 = 1
            goto L34
        L33:
            r2 = -1
        L34:
            if (r2 == 0) goto L3e
            if (r2 == r0) goto L39
            goto L63
        L39:
            java.lang.String r8 = r8.getPath()
            goto L64
        L3e:
            android.content.ContentResolver r1 = r7.getContentResolver()
            r4 = 0
            r5 = 0
            r6 = 0
            r2 = r8
            android.database.Cursor r8 = r1.query(r2, r3, r4, r5, r6)
            if (r8 == 0) goto L63
            java.lang.String r0 = r7.getPackageName()
            int r0 = r8.getColumnIndexOrThrow(r0)
            if (r0 >= 0) goto L57
            goto L63
        L57:
            java.lang.String r0 = r8.getString(r0)
            r8.moveToFirst()
            r8.close()
            r8 = r0
            goto L64
        L63:
            r8 = 0
        L64:
            return r8
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaApplication.getPathFromUri(android.net.Uri):java.lang.String");
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData() {
        return this.j.getAll();
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData(String str) {
        return this.j.getAll().get(str);
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData(String str, Object obj) {
        Object obj2 = this.j.getAll().get(str);
        return obj2 == null ? obj : obj2;
    }

    public Uri getUriForFile(File file) {
        return FileProvider.getUriForFile(this, getPackageName(), file);
    }

    public Uri getUriForPath(String str) {
        return FileProvider.getUriForFile(this, getPackageName(), new File(str));
    }

    @Override // com.androlua.LuaContext
    public int getWidth() {
        return getResources().getDisplayMetrics().widthPixels;
    }

    /* JADX WARN: Removed duplicated region for block: B:20:0x008f  */
    @Override // android.app.Application
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public void onCreate() {
        /*
            Method dump skipped, instructions count: 269
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaApplication.onCreate():void");
    }

    @Override // com.androlua.LuaContext
    public void regGc(LuaGcable luaGcable) {
    }

    @Override // com.androlua.LuaContext
    public void sendError(String str, Exception exc) {
    }

    @Override // com.androlua.LuaContext
    public void sendMsg(String str) {
        Toast.makeText(this, str, 0).show();
    }

    @Override // com.androlua.LuaContext
    public void set(String str, Object obj) {
        b.put(str, obj);
    }

    @Override // com.androlua.LuaContext
    public void setLuaExtDir(String str) {
        String absolutePath;
        if (Environment.getExternalStorageState().equals("mounted")) {
            absolutePath = new File(Environment.getExternalStorageDirectory().getAbsolutePath(), str).getAbsolutePath();
        } else {
            for (File file : new File("/storage").listFiles()) {
                String[] list = file.list();
                if (list != null && list.length > 5) {
                    this.i = new File(file, str).getAbsolutePath();
                }
            }
            if (this.i != null) {
                return;
            } else {
                absolutePath = getDir(str, 0).getAbsolutePath();
            }
        }
        this.i = absolutePath;
    }

    @Override // com.androlua.LuaContext
    public boolean setSharedData(String str, Object obj) {
        Set<String> set;
        SharedPreferences.Editor editorEdit = this.j.edit();
        if (obj == null) {
            editorEdit.remove(str);
        } else if (obj instanceof String) {
            editorEdit.putString(str, obj.toString());
        } else if (obj instanceof Long) {
            editorEdit.putLong(str, ((Long) obj).longValue());
        } else if (obj instanceof Integer) {
            editorEdit.putInt(str, ((Integer) obj).intValue());
        } else if (obj instanceof Float) {
            editorEdit.putFloat(str, ((Float) obj).floatValue());
        } else {
            if (obj instanceof Set) {
                set = (Set) obj;
            } else if (obj instanceof LuaTable) {
                set = (HashSet) ((LuaTable) obj).values();
            } else {
                if (!(obj instanceof Boolean)) {
                    return false;
                }
                editorEdit.putBoolean(str, ((Boolean) obj).booleanValue());
            }
            editorEdit.putStringSet(str, set);
        }
        editorEdit.apply();
        return true;
    }
}