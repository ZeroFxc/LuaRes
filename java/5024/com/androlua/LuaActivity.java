package com.androlua;

import android.R;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.AlertDialog;
import android.app.Fragment;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.FileProvider;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.content.res.AssetManager;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Parcelable;
import android.os.StrictMode;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.ContextMenu;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.MimeTypeMap;
import android.widget.ArrayListAdapter;
import android.widget.LinearLayout;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import com.androlua.LuaBroadcastReceiver;
import com.androlua.LuaService;
import com.androlua.Ticker;
import com.baidu.mobstat.StatService;
import com.luajava.JavaFunction;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import dalvik.system.DexClassLoader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.io.Serializable;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaActivity extends Activity implements LuaBroadcastReceiver.OnReceiveListener, LuaContext {
    private static String b;
    private String A;
    private String B;
    private String C;
    private LuaBroadcastReceiver D;
    private String E;
    private String F;
    private boolean G;
    private LuaResources I;
    private LuaObject L;
    private String d;
    private Handler e;
    private TextView f;
    private String g;
    private LuaDexLoader h;
    private int i;
    private int j;
    private ListView k;
    private ArrayListAdapter<String> l;
    private LuaState m;
    private String n;
    private Toast q;
    private LinearLayout r;
    private boolean s;
    private long t;
    private Menu u;
    private LuaObject v;
    private LuaObject w;
    private LuaObject x;
    private LuaObject y;
    private String z;
    private static ArrayList<String> a = new ArrayList<>();
    private static final HashMap<String, LuaActivity> c = new HashMap<>();
    private StringBuilder o = new StringBuilder();
    private Boolean p = false;
    private boolean H = true;
    private ArrayList<LuaGcable> J = new ArrayList<>();
    private String K = "main";

    public class MainHandler extends Handler {
        public MainHandler() {
        }

        @Override // android.os.Handler
        public void handleMessage(Message message) {
            super.handleMessage(message);
            int i = message.what;
            if (i == 0) {
                String string = message.getData().getString("data");
                if (LuaActivity.this.H) {
                    LuaActivity.this.showToast(string);
                }
                LuaActivity.this.f.append(string + "\n");
                LuaActivity.this.l.add(string);
                return;
            }
            if (i == 1) {
                Bundle data = message.getData();
                LuaActivity.this.a(data.getString("data"), ((Object[]) data.getSerializable("args"))[0]);
            } else if (i == 2) {
                LuaActivity.this.runFunc(message.getData().getString("data"), new Object[0]);
            } else {
                if (i != 3) {
                    return;
                }
                LuaActivity.this.runFunc(message.getData().getString("data"), (Object[]) message.getData().getSerializable("args"));
            }
        }
    }

    private File a(String str) {
        int iIndexOf = str.indexOf(".");
        if (iIndexOf > 0) {
            str = str.substring(0, iIndexOf);
        }
        File file = new File(this.d + "/lib" + str + ".so");
        if (file.isFile()) {
            return file;
        }
        File file2 = new File(this.d + "/lib/" + Build.CPU_ABI + "/lib" + str + ".so");
        if (file2.isFile()) {
            return file2;
        }
        return null;
    }

    private String a(int i) {
        switch (i) {
            case 1:
                return "Yield error";
            case 2:
                return "Runtime error";
            case 3:
                return "Syntax error";
            case 4:
                return "Out of memory";
            case 5:
                return "GC error";
            case 6:
                return "error error";
            default:
                return "Unknown error " + i;
        }
    }

    private String a(File file) {
        int iLastIndexOf = file.getName().lastIndexOf(46);
        if (iLastIndexOf < 0) {
            return "application/octet-stream";
        }
        String mimeTypeFromExtension = MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.getName().substring(iLastIndexOf + 1));
        return mimeTypeFromExtension != null ? mimeTypeFromExtension : "application/octet-stream";
    }

    private void a() throws IllegalAccessException, NoSuchFieldException, IllegalArgumentException {
        try {
            Field declaredField = ClassLoader.getSystemClassLoader().loadClass("de.robv.android.xposed.XposedBridge").getDeclaredField("disableHooks");
            declaredField.setAccessible(true);
            declaredField.set(null, true);
        } catch (Exception unused) {
        }
    }

    private void a(Object obj, String str) throws NoSuchFieldException {
        try {
            Field declaredField = obj.getClass().getDeclaredField(str);
            declaredField.setAccessible(true);
            ((HashMap) declaredField.get(obj)).clear();
            LuaDialog luaDialog = new LuaDialog(this);
            luaDialog.setTitle("\u63d0\u793a3");
            luaDialog.setMessage("\u4f60\u7684\u624b\u673a\u8fd0\u884c\u73af\u5883\u4e0d\u5b89\u5168");
            luaDialog.setPosButton("\u786e\u5b9a");
            luaDialog.show();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void a(String str, Object obj) {
        synchronized (this.m) {
            try {
                this.m.pushObjectValue(obj);
                this.m.setGlobal(str);
            } catch (LuaException e) {
                sendError("setField", e);
            }
        }
    }

    private static byte[] a(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(4096);
        byte[] bArr = new byte[4096];
        while (true) {
            int i = inputStream.read(bArr);
            if (-1 == i) {
                byte[] byteArray = byteArrayOutputStream.toByteArray();
                byteArrayOutputStream.close();
                return byteArray;
            }
            byteArrayOutputStream.write(bArr, 0, i);
        }
    }

    private void b() throws IllegalAccessException, InstantiationException {
        try {
            Object objNewInstance = ClassLoader.getSystemClassLoader().loadClass("de.robv.android.xposed.XposedHelpers").newInstance();
            if (objNewInstance != null) {
                a(objNewInstance, "fieldCache");
                a(objNewInstance, "methodCache");
                a(objNewInstance, "constructorCache");
            }
        } catch (Exception unused) {
        }
    }

    private void c() throws LuaException {
        if (new File(this.d + "/init.lua").exists()) {
            try {
                int iLloadFile = this.m.LloadFile(this.d + "/init.lua");
                if (iLloadFile == 0) {
                    this.m.newTable();
                    LuaObject luaObject = this.m.getLuaObject(-1);
                    this.m.setUpValue(-2, 1);
                    int iPcall = this.m.pcall(0, 0, 0);
                    if (iPcall == 0) {
                        if (b == null) {
                            LuaObject field = luaObject.getField("app_key");
                            if (field.isString()) {
                                b = field.toString();
                                StatService.setAppKey(field.toString());
                            }
                            LuaObject field2 = luaObject.getField("app_channel");
                            if (field2.isString()) {
                                StatService.setAppChannel(this, field2.toString(), true);
                            }
                            StatService.setOn(this, 1);
                        }
                        LuaObject field3 = luaObject.getField("appname");
                        if (field3.isString()) {
                            setTitle(field3.getString());
                        }
                        LuaObject field4 = luaObject.getField("app_name");
                        if (field4.isString()) {
                            setTitle(field4.getString());
                        }
                        LuaObject field5 = luaObject.getField("debugmode");
                        if (field5.isBoolean()) {
                            this.H = field5.getBoolean();
                        }
                        LuaObject field6 = luaObject.getField("debug_mode");
                        if (field6.isBoolean()) {
                            this.H = field6.getBoolean();
                        }
                        LuaObject field7 = luaObject.getField("theme");
                        if (field7.isNumber()) {
                            setTheme((int) field7.getInteger());
                            return;
                        } else {
                            if (field7.isString()) {
                                setTheme(R.style.class.getField(field7.getString()).getInt(null));
                                return;
                            }
                            return;
                        }
                    }
                    iLloadFile = iPcall;
                }
                throw new LuaException(a(iLloadFile) + ": " + this.m.toString(-1));
            } catch (Exception e) {
                sendMsg(e.getMessage());
            }
        }
    }

    private void d() throws LuaException {
        this.m = LuaStateFactory.newLuaState();
        this.m.openLibs();
        this.m.pushJavaObject(this);
        this.m.setGlobal("activity");
        this.m.getGlobal("activity");
        this.m.setGlobal("this");
        this.m.pushContext(this);
        this.m.getGlobal("luajava");
        this.m.pushString(this.C);
        this.m.setField(-2, "luaextdir");
        this.m.pushString(this.d);
        this.m.setField(-2, "luadir");
        this.m.pushString(this.n);
        this.m.setField(-2, "luapath");
        this.m.pop(1);
        c();
        new LuaPrint(this, this.m).register("print");
        this.m.getGlobal("package");
        this.m.pushString(this.E);
        this.m.setField(-2, "path");
        this.m.pushString(this.g);
        this.m.setField(-2, "cpath");
        this.m.pop(1);
        new JavaFunction(this.m) { // from class: com.androlua.LuaActivity.4
            @Override // com.luajava.JavaFunction
            public int execute() {
                ((LuaThread) this.a.toJavaObject(2)).set(this.a.toString(3), this.a.toJavaObject(4));
                return 0;
            }
        }.register("set");
        new JavaFunction(this.m) { // from class: com.androlua.LuaActivity.5
            @Override // com.luajava.JavaFunction
            public int execute() {
                LuaThread luaThread = (LuaThread) this.a.toJavaObject(2);
                int top = this.a.getTop();
                if (top <= 3) {
                    if (top != 3) {
                        return 0;
                    }
                    luaThread.call(this.a.toString(3));
                    return 0;
                }
                Object[] objArr = new Object[top - 3];
                for (int i = 4; i <= top; i++) {
                    objArr[i - 4] = this.a.toJavaObject(i);
                }
                luaThread.call(this.a.toString(3), objArr);
                return 0;
            }
        }.register("call");
    }

    public static LuaActivity getActivity(String str) {
        return c.get(str);
    }

    public void assetsToSD(String str, String str2) throws IOException {
        FileOutputStream fileOutputStream = new FileOutputStream(str2);
        InputStream inputStreamOpen = getAssets().open(str);
        byte[] bArr = new byte[4096];
        while (true) {
            int i = inputStreamOpen.read(bArr);
            if (i <= 0) {
                fileOutputStream.flush();
                inputStreamOpen.close();
                fileOutputStream.close();
                return;
            }
            fileOutputStream.write(bArr, 0, i);
        }
    }

    public boolean bindService(int i) {
        return bindService(new ServiceConnection() { // from class: com.androlua.LuaActivity.2
            @Override // android.content.ServiceConnection
            public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
                LuaActivity.this.runFunc("onServiceConnected", componentName, ((LuaService.LuaBinder) iBinder).getService());
            }

            @Override // android.content.ServiceConnection
            public void onServiceDisconnected(ComponentName componentName) {
                LuaActivity.this.runFunc("onServiceDisconnected", componentName);
            }
        }, i);
    }

    public boolean bindService(ServiceConnection serviceConnection, int i) {
        Intent intent = new Intent(this, (Class<?>) LuaService.class);
        intent.putExtra("luaDir", this.d);
        intent.putExtra("luaPath", this.n);
        return super.bindService(intent, serviceConnection, i);
    }

    public void call(String str) {
        push(2, str);
    }

    @Override // com.androlua.LuaContext
    public void call(String str, Object[] objArr) {
        if (objArr.length == 0) {
            push(2, str);
        } else {
            push(3, str, objArr);
        }
    }

    public void createShortcut(String str, String str2) {
        String str3;
        Intent intent = new Intent("android.intent.action.MAIN");
        intent.addCategory("android.intent.category.DEFAULT");
        intent.setClassName(getPackageName(), LuaActivity.class.getName());
        intent.setData(Uri.parse(str));
        if (Build.VERSION.SDK_INT >= 22) {
            intent.addFlags(524288);
            intent.addFlags(134217728);
        }
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                ((ShortcutManager) getSystemService("shortcut")).requestPinShortcut(new ShortcutInfo.Builder(this, str).setIcon(Icon.createWithResource(this, R.drawable.icon)).setShortLabel(str2).setIntent(intent).build(), null);
                return;
            } catch (Exception e) {
                e.printStackTrace();
                str3 = "\u6dfb\u52a0\u5feb\u6377\u65b9\u5f0f\u51fa\u9519";
            }
        } else {
            Intent intent2 = new Intent("com.android.launcher.action.INSTALL_SHORTCUT");
            Parcelable parcelableFromContext = Intent.ShortcutIconResource.fromContext(this, R.drawable.icon);
            intent2.putExtra("android.intent.extra.shortcut.NAME", str2);
            intent2.putExtra("android.intent.extra.shortcut.INTENT", intent);
            intent2.putExtra("duplicate", 0);
            intent2.putExtra("android.intent.extra.shortcut.ICON_RESOURCE", parcelableFromContext);
            sendBroadcast(intent2);
            str3 = "\u5df2\u6dfb\u52a0\u5feb\u6377\u65b9\u5f0f";
        }
        Toast.makeText(this, str3, 0).show();
    }

    public void createShortcut(String str, String str2, String str3) {
        String str4;
        Intent intent = new Intent("android.intent.action.MAIN");
        intent.addCategory("android.intent.category.DEFAULT");
        intent.setClassName(getPackageName(), LuaActivity.class.getName());
        intent.setData(Uri.parse(str));
        if (Build.VERSION.SDK_INT >= 22) {
            intent.addFlags(524288);
            intent.addFlags(134217728);
        }
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                ((ShortcutManager) getSystemService("shortcut")).requestPinShortcut(new ShortcutInfo.Builder(this, str).setIcon(Icon.createWithFilePath(str3)).setShortLabel(str2).setIntent(intent).build(), null);
                return;
            } catch (Exception e) {
                e.printStackTrace();
                str4 = "\u6dfb\u52a0\u5feb\u6377\u65b9\u5f0f\u51fa\u9519";
            }
        } else {
            Intent intent2 = new Intent("com.android.launcher.action.INSTALL_SHORTCUT");
            intent2.putExtra("android.intent.extra.shortcut.NAME", str2);
            intent2.putExtra("android.intent.extra.shortcut.INTENT", intent);
            intent2.putExtra("duplicate", 0);
            intent2.putExtra("android.intent.extra.shortcut.ICON", BitmapFactory.decodeFile(str3));
            sendBroadcast(intent2);
            str4 = "\u5df2\u6dfb\u52a0\u5feb\u6377\u65b9\u5f0f";
        }
        Toast.makeText(this, str4, 0).show();
    }

    public Object doAsset(String str, Object[] objArr) throws LuaException {
        int iPcall;
        int i = 0;
        try {
            byte[] asset = readAsset(str);
            this.m.setTop(0);
            int iLloadBuffer = this.m.LloadBuffer(asset, str);
            if (iLloadBuffer == 0) {
                try {
                    this.m.getGlobal("debug");
                    this.m.getField(-1, "traceback");
                    this.m.remove(-2);
                    this.m.insert(-2);
                    int length = objArr.length;
                    for (Object obj : objArr) {
                        this.m.pushObjectValue(obj);
                    }
                    iPcall = this.m.pcall(length, 0, (-2) - length);
                    if (iPcall == 0) {
                        return this.m.toJavaObject(-1);
                    }
                } catch (Exception e) {
                    e = e;
                    i = iLloadBuffer;
                    setTitle(a(i));
                    setContentView(this.r);
                    sendMsg(e.getMessage());
                    return null;
                }
            } else {
                iPcall = iLloadBuffer;
            }
            throw new LuaException(a(iPcall) + ": " + this.m.toString(-1));
        } catch (Exception e2) {
            e = e2;
        }
    }

    public Object doFile(String str) {
        return doFile(str, new Object[0]);
    }

    @Override // com.androlua.LuaContext
    public Object doFile(String str, Object[] objArr) throws LuaException {
        LuaException e;
        int iLloadFile;
        int i;
        int iIndexOf;
        try {
            if (str.charAt(0) != '/') {
                str = this.d + "/" + str;
            }
            this.m.setTop(0);
            iLloadFile = this.m.LloadFile(str);
            if (iLloadFile == 0) {
                try {
                    this.m.getGlobal("debug");
                    this.m.getField(-1, "traceback");
                    this.m.remove(-2);
                    this.m.insert(-2);
                    int length = objArr.length;
                    for (Object obj : objArr) {
                        this.m.pushObjectValue(obj);
                    }
                    iLloadFile = this.m.pcall(length, 1, (-2) - length);
                    if (iLloadFile == 0) {
                        return this.m.toJavaObject(-1);
                    }
                } catch (LuaException e2) {
                    e = e2;
                    setTitle(a(iLloadFile));
                    setContentView(this.r);
                    sendMsg(e.getMessage());
                    String message = e.getMessage();
                    int iIndexOf2 = message.indexOf("android.permission.");
                    if (iIndexOf2 <= 0 || (iIndexOf = message.indexOf(".", (i = iIndexOf2 + 19))) <= i) {
                        boolean z = this.G;
                        return null;
                    }
                    String strSubstring = message.substring(i, iIndexOf);
                    this.m.getGlobal("require");
                    this.m.pushString("permission");
                    this.m.pcall(1, 0, 0);
                    this.m.getGlobal("permission_info");
                    this.m.getField(-1, strSubstring);
                    if (this.m.isString(-1)) {
                        strSubstring = strSubstring + " (" + this.m.toString(-1) + ")";
                    }
                    sendMsg("\u6743\u9650\u9519\u8bef: " + strSubstring);
                    return null;
                }
            }
            Intent intent = new Intent();
            intent.putExtra("data", this.m.toString(-1));
            setResult(iLloadFile, intent);
            throw new LuaException(a(iLloadFile) + ": " + this.m.toString(-1));
        } catch (LuaException e3) {
            e = e3;
            iLloadFile = 0;
        }
    }

    public Object doString(String str, Object... objArr) throws LuaException {
        try {
            this.m.setTop(0);
            int iLloadString = this.m.LloadString(str);
            if (iLloadString == 0) {
                this.m.getGlobal("debug");
                this.m.getField(-1, "traceback");
                this.m.remove(-2);
                this.m.insert(-2);
                int length = objArr.length;
                for (Object obj : objArr) {
                    this.m.pushObjectValue(obj);
                }
                iLloadString = this.m.pcall(length, 1, (-2) - length);
                if (iLloadString == 0) {
                    return this.m.toJavaObject(-1);
                }
            }
            throw new LuaException(a(iLloadString) + ": " + this.m.toString(-1));
        } catch (LuaException e) {
            sendMsg(e.getMessage());
            return null;
        }
    }

    public void finish(boolean z) {
        Intent intent;
        if (!z) {
            super.finish();
        } else if (Build.VERSION.SDK_INT < 21 || (intent = getIntent()) == null || (intent.getFlags() & 524288) == 0) {
            super.finish();
        } else {
            finishAndRemoveTask();
        }
    }

    public Object get(String str) {
        Object javaObject;
        synchronized (this.m) {
            this.m.getGlobal(str);
            javaObject = this.m.toJavaObject(-1);
        }
        return javaObject;
    }

    public Object getArg(int i) {
        Object[] objArr = (Object[]) getIntent().getSerializableExtra("arg");
        if (objArr == null || objArr.length >= i) {
            return null;
        }
        return objArr[i];
    }

    @Override // android.view.ContextThemeWrapper, android.content.ContextWrapper, android.content.Context
    public AssetManager getAssets() {
        LuaDexLoader luaDexLoader = this.h;
        return (luaDexLoader == null || luaDexLoader.getAssets() == null) ? super.getAssets() : this.h.getAssets();
    }

    @Override // com.androlua.LuaContext
    public ArrayList<ClassLoader> getClassLoaders() {
        return this.h.getClassLoaders();
    }

    @Override // com.androlua.LuaContext
    public Context getContext() {
        return this;
    }

    public View getDecorView() {
        return getWindow().getDecorView();
    }

    @Override // com.androlua.LuaContext
    public Map getGlobalData() {
        return ((LuaApplication) getApplication()).getGlobalData();
    }

    @Override // com.androlua.LuaContext
    public int getHeight() {
        return this.j;
    }

    public HashMap<String, String> getLibrarys() {
        return this.h.getLibrarys();
    }

    public String getLocalDir() {
        return this.z;
    }

    @Override // com.androlua.LuaContext
    public String getLuaCpath() {
        return this.g;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir() {
        return this.d;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir(String str) {
        File file = new File(this.d + "/" + str);
        if (file.exists() || file.mkdirs()) {
            return file.getAbsolutePath();
        }
        return null;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir() {
        return this.C;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir(String str) {
        File file = new File(getLuaExtDir(), str);
        if (file.exists() || file.mkdirs()) {
            return file.getAbsolutePath();
        }
        return null;
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
        return this.E;
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath() {
        Uri data = getIntent().getData();
        if (data == null) {
            return null;
        }
        String path = data.getPath();
        if (!new File(path).exists() && new File(getLuaPath(path)).exists()) {
            path = getLuaPath(path);
        }
        this.n = path;
        File file = new File(path);
        this.d = new File(this.n).getParent();
        if (!file.getName().equals("main.lua") || !new File(this.d, "init.lua").exists()) {
            String parent = this.d;
            while (true) {
                if (parent == null) {
                    break;
                }
                if (a.contains(parent)) {
                    this.d = parent;
                    break;
                }
                if (new File(parent, "main.lua").exists() && new File(parent, "init.lua").exists()) {
                    this.d = parent;
                    if (!a.contains(this.d)) {
                    }
                } else {
                    parent = new File(parent).getParent();
                }
            }
        } else if (!a.contains(this.d)) {
            a.add(this.d);
        }
        return path;
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath(String str) {
        return new File(getLuaDir(), str).getAbsolutePath();
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath(String str, String str2) {
        return new File(getLuaDir(str), str2).getAbsolutePath();
    }

    public LuaResources getLuaResources() {
        Resources resources = super.getResources();
        LuaDexLoader luaDexLoader = this.h;
        if (luaDexLoader != null && luaDexLoader.getResources() != null) {
            resources = this.h.getResources();
        }
        this.I = new LuaResources(getAssets(), resources.getDisplayMetrics(), resources.getConfiguration());
        this.I.setSuperResources(resources);
        return this.I;
    }

    @Override // com.androlua.LuaContext
    public LuaState getLuaState() {
        return this.m;
    }

    public Menu getOptionsMenu() {
        return this.u;
    }

    /* JADX WARN: Removed duplicated region for block: B:14:0x0031  */
    /* JADX WARN: Removed duplicated region for block: B:16:0x0034  */
    /* JADX WARN: Removed duplicated region for block: B:19:0x003c  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public java.lang.String getPathFromUri(android.net.Uri r8) {
        /*
            r7 = this;
            if (r8 == 0) goto L61
            r0 = 1
            java.lang.String[] r3 = new java.lang.String[r0]
            r1 = 0
            java.lang.String r2 = "_data"
            r3[r1] = r2
            java.lang.String r2 = r8.getScheme()
            r4 = -1
            int r5 = r2.hashCode()
            r6 = 3143036(0x2ff57c, float:4.404332E-39)
            if (r5 == r6) goto L27
            r6 = 951530617(0x38b73479, float:8.735894E-5)
            if (r5 == r6) goto L1e
            goto L31
        L1e:
            java.lang.String r5 = "content"
            boolean r2 = r2.equals(r5)
            if (r2 == 0) goto L31
            goto L32
        L27:
            java.lang.String r1 = "file"
            boolean r1 = r2.equals(r1)
            if (r1 == 0) goto L31
            r1 = 1
            goto L32
        L31:
            r1 = -1
        L32:
            if (r1 == 0) goto L3c
            if (r1 == r0) goto L37
            goto L61
        L37:
            java.lang.String r8 = r8.getPath()
            goto L62
        L3c:
            android.content.ContentResolver r1 = r7.getContentResolver()
            r4 = 0
            r5 = 0
            r6 = 0
            r2 = r8
            android.database.Cursor r8 = r1.query(r2, r3, r4, r5, r6)
            if (r8 == 0) goto L61
            java.lang.String r0 = r7.getPackageName()
            int r0 = r8.getColumnIndexOrThrow(r0)
            if (r0 >= 0) goto L55
            goto L61
        L55:
            java.lang.String r0 = r8.getString(r0)
            r8.moveToFirst()
            r8.close()
            r8 = r0
            goto L62
        L61:
            r8 = 0
        L62:
            return r8
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaActivity.getPathFromUri(android.net.Uri):java.lang.String");
    }

    public String getQuery(String str) {
        Uri data = getIntent().getData();
        if (data == null) {
            return null;
        }
        return data.getQueryParameter(str);
    }

    @Override // android.view.ContextThemeWrapper, android.content.ContextWrapper, android.content.Context
    public Resources getResources() {
        LuaDexLoader luaDexLoader = this.h;
        if (luaDexLoader != null && luaDexLoader.getResources() != null) {
            return this.h.getResources();
        }
        LuaResources luaResources = this.I;
        return luaResources != null ? luaResources : super.getResources();
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData() {
        return LuaApplication.getInstance().getSharedData();
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData(String str) {
        return LuaApplication.getInstance().getSharedData(str);
    }

    @Override // com.androlua.LuaContext
    public Object getSharedData(String str, Object obj) {
        return LuaApplication.getInstance().getSharedData(str, obj);
    }

    public Resources getSuperResources() {
        return super.getResources();
    }

    public Uri getUriForFile(File file) {
        return FileProvider.getUriForFile(this, getPackageName(), file);
    }

    public Uri getUriForPath(String str) {
        return FileProvider.getUriForFile(this, getPackageName(), new File(str));
    }

    @Override // com.androlua.LuaContext
    public int getWidth() {
        return this.i;
    }

    public void initMain() {
        a.add(getLocalDir());
    }

    public void installApk(String str) {
        Intent intent = new Intent("android.intent.action.VIEW");
        File file = new File(str);
        intent.setFlags(1);
        intent.setDataAndType(getUriForFile(file), a(file));
        intent.addFlags(268435456);
        startActivity(intent);
    }

    public DexClassLoader loadApp(String str) {
        return this.h.loadApp(str);
    }

    public Bitmap loadBitmap(String str) {
        return LuaBitmap.getBitmap(this, str);
    }

    public DexClassLoader loadDex(String str) {
        return this.h.loadDex(str);
    }

    public Object loadLib(String str) throws LuaException {
        int iIndexOf = str.indexOf(".");
        String strSubstring = iIndexOf > 0 ? str.substring(0, iIndexOf) : str;
        if (!new File(this.B + "/lib" + strSubstring + ".so").exists()) {
            File fileA = a(str);
            if (fileA == null) {
                throw new LuaException("can not find lib " + str);
            }
            LuaUtil.copyFile(fileA.getAbsolutePath(), this.B + "/lib" + strSubstring + ".so");
        }
        return this.m.getLuaObject("require").call(str);
    }

    public Object loadLib(String str, long j) throws LuaException {
        String absolutePath;
        StringBuilder sb;
        int iIndexOf = str.indexOf(".");
        String strSubstring = iIndexOf > 0 ? str.substring(0, iIndexOf) : str;
        File file = new File(this.B + "/lib" + strSubstring + ".so");
        SharedPreferences sharedPreferences = getSharedPreferences("lib", 0);
        if (j == -1) {
            if (!file.exists()) {
                return null;
            }
            file.delete();
            sharedPreferences.edit().putLong(str, -1L).apply();
            return null;
        }
        if (file.exists()) {
            if (sharedPreferences.getLong(str, -1L) < j) {
                File fileA = a(str);
                if (fileA == null) {
                    throw new LuaException("can not find new lib " + str);
                }
                file.delete();
                absolutePath = fileA.getAbsolutePath();
                sb = new StringBuilder();
            }
            return this.m.getLuaObject("require").call(str);
        }
        File fileA2 = a(str);
        if (fileA2 == null) {
            throw new LuaException("can not find lib " + str);
        }
        absolutePath = fileA2.getAbsolutePath();
        sb = new StringBuilder();
        sb.append(this.B);
        sb.append("/lib");
        sb.append(strSubstring);
        sb.append(".so");
        LuaUtil.copyFile(absolutePath, sb.toString());
        sharedPreferences.edit().putLong(str, j).apply();
        return this.m.getLuaObject("require").call(str);
    }

    public void loadResources(String str) {
        this.h.loadResources(str);
    }

    public void newActivity(int i, String str) throws FileNotFoundException {
        newActivity(i, str, new Object[0]);
    }

    public void newActivity(int i, String str, int i2, int i3) throws FileNotFoundException {
        newActivity(i, str, i2, i3, new Object[0]);
    }

    public void newActivity(int i, String str, int i2, int i3, boolean z) throws FileNotFoundException {
        newActivity(i, str, i2, i3, null, z);
    }

    public void newActivity(int i, String str, int i2, int i3, Object[] objArr) throws FileNotFoundException {
        newActivity(i, str, i2, i3, objArr, false);
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Removed duplicated region for block: B:13:0x006b  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public void newActivity(int r6, java.lang.String r7, int r8, int r9, java.lang.Object[] r10, boolean r11) throws java.io.FileNotFoundException {
        /*
            r5 = this;
            android.content.Intent r0 = new android.content.Intent
            java.lang.Class<com.androlua.LuaActivity> r1 = com.androlua.LuaActivity.class
            r0.<init>(r5, r1)
            if (r11 == 0) goto L10
            android.content.Intent r0 = new android.content.Intent
            java.lang.Class<com.androlua.LuaActivityX> r1 = com.androlua.LuaActivityX.class
            r0.<init>(r5, r1)
        L10:
            java.lang.String r1 = "name"
            r0.putExtra(r1, r7)
            r1 = 0
            char r1 = r7.charAt(r1)
            r2 = 47
            if (r1 == r2) goto L34
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            java.lang.String r2 = r5.d
            r1.append(r2)
            java.lang.String r2 = "/"
            r1.append(r2)
            r1.append(r7)
            java.lang.String r7 = r1.toString()
        L34:
            java.io.File r1 = new java.io.File
            r1.<init>(r7)
            boolean r2 = r1.isDirectory()
            if (r2 == 0) goto L6b
            java.io.File r2 = new java.io.File
            java.lang.StringBuilder r3 = new java.lang.StringBuilder
            r3.<init>()
            r3.append(r7)
            java.lang.String r4 = "/main.lua"
            r3.append(r4)
            java.lang.String r3 = r3.toString()
            r2.<init>(r3)
            boolean r2 = r2.exists()
            if (r2 == 0) goto L6b
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            r1.append(r7)
            r1.append(r4)
            java.lang.String r7 = r1.toString()
            goto L8e
        L6b:
            boolean r2 = r1.isDirectory()
            if (r2 != 0) goto L77
            boolean r1 = r1.exists()
            if (r1 != 0) goto L8e
        L77:
            java.lang.String r1 = ".lua"
            boolean r2 = r7.endsWith(r1)
            if (r2 != 0) goto L8e
            java.lang.StringBuilder r2 = new java.lang.StringBuilder
            r2.<init>()
            r2.append(r7)
            r2.append(r1)
            java.lang.String r7 = r2.toString()
        L8e:
            java.io.File r1 = new java.io.File
            r1.<init>(r7)
            boolean r1 = r1.exists()
            if (r1 == 0) goto Ld7
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            java.lang.String r2 = "file://"
            r1.append(r2)
            r1.append(r7)
            java.lang.String r7 = r1.toString()
            android.net.Uri r7 = android.net.Uri.parse(r7)
            r0.setData(r7)
            if (r11 == 0) goto Lc3
            int r7 = android.os.Build.VERSION.SDK_INT
            r1 = 21
            if (r7 < r1) goto Lc3
            r7 = 524288(0x80000, float:7.34684E-40)
            r0.addFlags(r7)
            r7 = 134217728(0x8000000, float:3.85186E-34)
            r0.addFlags(r7)
        Lc3:
            if (r10 == 0) goto Lca
            java.lang.String r7 = "arg"
            r0.putExtra(r7, r10)
        Lca:
            if (r11 == 0) goto Ld0
            r5.startActivity(r0)
            goto Ld3
        Ld0:
            r5.startActivityForResult(r0, r6)
        Ld3:
            r5.overridePendingTransition(r8, r9)
            return
        Ld7:
            java.io.FileNotFoundException r6 = new java.io.FileNotFoundException
            r6.<init>(r7)
            throw r6
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaActivity.newActivity(int, java.lang.String, int, int, java.lang.Object[], boolean):void");
    }

    public void newActivity(int i, String str, boolean z) throws FileNotFoundException {
        newActivity(i, str, (Object[]) null, z);
    }

    public void newActivity(int i, String str, Object[] objArr) throws FileNotFoundException {
        newActivity(i, str, objArr, false);
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Removed duplicated region for block: B:13:0x006b  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public void newActivity(int r6, java.lang.String r7, java.lang.Object[] r8, boolean r9) throws java.io.FileNotFoundException {
        /*
            r5 = this;
            android.content.Intent r0 = new android.content.Intent
            java.lang.Class<com.androlua.LuaActivity> r1 = com.androlua.LuaActivity.class
            r0.<init>(r5, r1)
            if (r9 == 0) goto L10
            android.content.Intent r0 = new android.content.Intent
            java.lang.Class<com.androlua.LuaActivityX> r1 = com.androlua.LuaActivityX.class
            r0.<init>(r5, r1)
        L10:
            java.lang.String r1 = "name"
            r0.putExtra(r1, r7)
            r1 = 0
            char r1 = r7.charAt(r1)
            r2 = 47
            if (r1 == r2) goto L34
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            java.lang.String r2 = r5.d
            r1.append(r2)
            java.lang.String r2 = "/"
            r1.append(r2)
            r1.append(r7)
            java.lang.String r7 = r1.toString()
        L34:
            java.io.File r1 = new java.io.File
            r1.<init>(r7)
            boolean r2 = r1.isDirectory()
            if (r2 == 0) goto L6b
            java.io.File r2 = new java.io.File
            java.lang.StringBuilder r3 = new java.lang.StringBuilder
            r3.<init>()
            r3.append(r7)
            java.lang.String r4 = "/main.lua"
            r3.append(r4)
            java.lang.String r3 = r3.toString()
            r2.<init>(r3)
            boolean r2 = r2.exists()
            if (r2 == 0) goto L6b
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            r1.append(r7)
            r1.append(r4)
            java.lang.String r7 = r1.toString()
            goto L8e
        L6b:
            boolean r2 = r1.isDirectory()
            if (r2 != 0) goto L77
            boolean r1 = r1.exists()
            if (r1 != 0) goto L8e
        L77:
            java.lang.String r1 = ".lua"
            boolean r2 = r7.endsWith(r1)
            if (r2 != 0) goto L8e
            java.lang.StringBuilder r2 = new java.lang.StringBuilder
            r2.<init>()
            r2.append(r7)
            r2.append(r1)
            java.lang.String r7 = r2.toString()
        L8e:
            java.io.File r1 = new java.io.File
            r1.<init>(r7)
            boolean r1 = r1.exists()
            if (r1 == 0) goto Ld4
            if (r9 == 0) goto Lab
            int r1 = android.os.Build.VERSION.SDK_INT
            r2 = 21
            if (r1 < r2) goto Lab
            r1 = 524288(0x80000, float:7.34684E-40)
            r0.addFlags(r1)
            r1 = 134217728(0x8000000, float:3.85186E-34)
            r0.addFlags(r1)
        Lab:
            java.lang.StringBuilder r1 = new java.lang.StringBuilder
            r1.<init>()
            java.lang.String r2 = "file://"
            r1.append(r2)
            r1.append(r7)
            java.lang.String r7 = r1.toString()
            android.net.Uri r7 = android.net.Uri.parse(r7)
            r0.setData(r7)
            if (r8 == 0) goto Lca
            java.lang.String r7 = "arg"
            r0.putExtra(r7, r8)
        Lca:
            if (r9 == 0) goto Ld0
            r5.startActivity(r0)
            goto Ld3
        Ld0:
            r5.startActivityForResult(r0, r6)
        Ld3:
            return
        Ld4:
            java.io.FileNotFoundException r6 = new java.io.FileNotFoundException
            r6.<init>(r7)
            throw r6
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaActivity.newActivity(int, java.lang.String, java.lang.Object[], boolean):void");
    }

    public void newActivity(String str) throws FileNotFoundException {
        newActivity(1, str, new Object[0]);
    }

    public void newActivity(String str, int i, int i2) throws FileNotFoundException {
        newActivity(1, str, i, i2, new Object[0]);
    }

    public void newActivity(String str, int i, int i2, boolean z) throws FileNotFoundException {
        newActivity(1, str, i, i2, null, z);
    }

    public void newActivity(String str, int i, int i2, Object[] objArr) throws FileNotFoundException {
        newActivity(1, str, i, i2, objArr);
    }

    public void newActivity(String str, int i, int i2, Object[] objArr, boolean z) throws FileNotFoundException {
        newActivity(1, str, i, i2, objArr, z);
    }

    public void newActivity(String str, boolean z) throws FileNotFoundException {
        newActivity(1, str, (Object[]) null, z);
    }

    public void newActivity(String str, Object[] objArr) throws FileNotFoundException {
        newActivity(1, str, objArr);
    }

    public void newActivity(String str, Object[] objArr, boolean z) throws FileNotFoundException {
        newActivity(1, str, objArr, z);
    }

    public LuaAsyncTask newTask(LuaObject luaObject) {
        return newTask(luaObject, null, null);
    }

    public LuaAsyncTask newTask(LuaObject luaObject, LuaObject luaObject2) {
        return newTask(luaObject, null, luaObject2);
    }

    public LuaAsyncTask newTask(LuaObject luaObject, LuaObject luaObject2, LuaObject luaObject3) {
        return new LuaAsyncTask(this, luaObject, luaObject2, luaObject3);
    }

    public LuaThread newThread(LuaObject luaObject) {
        return newThread(luaObject, new Object[0]);
    }

    public LuaThread newThread(LuaObject luaObject, Object[] objArr) {
        return new LuaThread((LuaContext) this, luaObject, true, objArr);
    }

    public LuaTimer newTimer(LuaObject luaObject) {
        return newTimer(luaObject, new Object[0]);
    }

    public LuaTimer newTimer(LuaObject luaObject, Object[] objArr) {
        return new LuaTimer(this, luaObject, objArr);
    }

    @Override // android.app.Activity
    protected void onActivityResult(int i, int i2, Intent intent) {
        String stringExtra;
        if (intent != null && (stringExtra = intent.getStringExtra("name")) != null) {
            Object[] objArr = (Object[]) intent.getSerializableExtra("data");
            if (objArr == null) {
                runFunc("onResult", stringExtra);
            } else {
                Object[] objArr2 = new Object[objArr.length + 1];
                objArr2[0] = stringExtra;
                int i3 = 0;
                while (i3 < objArr.length) {
                    int i4 = i3 + 1;
                    objArr2[i4] = objArr[i3];
                    i3 = i4;
                }
                Object objRunFunc = runFunc("onResult", objArr2);
                if (objRunFunc != null && objRunFunc.getClass() == Boolean.class && ((Boolean) objRunFunc).booleanValue()) {
                    return;
                }
            }
        }
        runFunc("onActivityResult", Integer.valueOf(i), Integer.valueOf(i2), intent);
        super.onActivityResult(i, i2, intent);
    }

    @Override // android.app.Activity, android.content.ComponentCallbacks
    public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        WindowManager windowManager = (WindowManager) getSystemService("window");
        DisplayMetrics displayMetrics = new DisplayMetrics();
        windowManager.getDefaultDisplay().getMetrics(displayMetrics);
        this.i = displayMetrics.widthPixels;
        this.j = displayMetrics.heightPixels;
        runFunc("onConfigurationChanged", configuration);
    }

    @Override // android.app.Activity, android.view.Window.Callback
    public void onContentChanged() {
        super.onContentChanged();
        this.s = true;
    }

    @Override // android.app.Activity
    public boolean onContextItemSelected(MenuItem menuItem) {
        runFunc("onContextItemSelected", menuItem);
        return super.onContextItemSelected(menuItem);
    }

    @Override // android.app.Activity
    public void onCreate(Bundle bundle) throws IllegalAccessException, NoSuchFieldException, InstantiationException, IllegalArgumentException {
        setTheme(android.R.style.Theme.Holo.Light.NoActionBar);
        StrictMode.setThreadPolicy(new StrictMode.ThreadPolicy.Builder().permitAll().build());
        super.onCreate(null);
        WindowManager windowManager = (WindowManager) getSystemService("window");
        DisplayMetrics displayMetrics = new DisplayMetrics();
        windowManager.getDefaultDisplay().getMetrics(displayMetrics);
        this.i = displayMetrics.widthPixels;
        this.j = displayMetrics.heightPixels;
        this.r = new LinearLayout(this);
        ScrollView scrollView = new ScrollView(this);
        scrollView.setFillViewport(true);
        this.f = new TextView(this);
        this.f.setTextColor(-16777216);
        scrollView.addView(this.f, new ViewGroup.LayoutParams(-1, -2));
        this.f.setText(BuildConfig.FLAVOR);
        this.f.setTextIsSelectable(true);
        this.k = new ListView(this);
        this.k.setFastScrollEnabled(true);
        this.l = new ArrayListAdapter<String>(this, android.R.layout.simple_list_item_1) { // from class: com.androlua.LuaActivity.1
            public View getView(int i, View view, ViewGroup viewGroup) {
                TextView textView = (TextView) super.getView(i, view, viewGroup);
                if (view == null) {
                    textView.setTextIsSelectable(true);
                }
                return textView;
            }
        };
        this.k.setAdapter((ListAdapter) this.l);
        this.r.addView(this.k, new ViewGroup.LayoutParams(-1, -2));
        LuaApplication luaApplication = (LuaApplication) getApplication();
        if (luaApplication.getClass() != LuaApplication.class) {
            while (luaApplication.getClass() != LuaApplication.class) {
            }
        }
        this.z = luaApplication.getLocalDir();
        this.A = luaApplication.getOdexDir();
        this.B = luaApplication.getLibDir();
        this.F = luaApplication.getMdDir();
        this.g = luaApplication.getLuaCpath();
        this.d = this.z;
        this.E = luaApplication.getLuaLpath();
        this.C = luaApplication.getLuaExtDir();
        this.e = new MainHandler();
        try {
            this.f.setText(BuildConfig.FLAVOR);
            this.l.clear();
            Object[] objArr = (Object[]) getIntent().getSerializableExtra("arg");
            if (objArr == null) {
                objArr = new Object[0];
            }
            this.n = getLuaPath();
            this.K = new File(this.n).getName();
            int iLastIndexOf = this.K.lastIndexOf(".");
            if (iLastIndexOf > 0) {
                this.K = this.K.substring(0, iLastIndexOf);
            }
            this.E = this.d + "/?.lua;" + this.d + "/lua/?.lua;" + this.d + "/?/init.lua;" + this.E;
            d();
            this.h = new LuaDexLoader(this);
            this.h.loadLibs();
            c.put(this.K, this);
            doFile(this.n, objArr);
            this.p = true;
            if (!this.K.equals("main")) {
                runFunc("main", objArr);
            }
            runFunc(this.K, objArr);
            runFunc("onCreate", bundle);
            if (!this.s) {
                TypedArray typedArrayObtainStyledAttributes = getTheme().obtainStyledAttributes(new int[]{android.R.attr.colorBackground, android.R.attr.textColorPrimary, android.R.attr.textColorHighlightInverse});
                int color = typedArrayObtainStyledAttributes.getColor(0, 16711935);
                int color2 = typedArrayObtainStyledAttributes.getColor(1, 16711935);
                typedArrayObtainStyledAttributes.recycle();
                this.f.setTextColor(color2);
                this.r.setBackgroundColor(color);
                setContentView(this.r);
            }
            this.L = this.m.getLuaObject("onKeyShortcut");
            if (this.L.isNil()) {
                this.L = null;
            }
            this.v = this.m.getLuaObject("onKeyDown");
            if (this.v.isNil()) {
                this.v = null;
            }
            this.w = this.m.getLuaObject("onKeyUp");
            if (this.w.isNil()) {
                this.w = null;
            }
            this.x = this.m.getLuaObject("onKeyLongPress");
            if (this.x.isNil()) {
                this.x = null;
            }
            this.y = this.m.getLuaObject("onTouchEvent");
            if (this.y.isNil()) {
                this.y = null;
            }
            LuaObject luaObject = this.m.getLuaObject("onAccessibilityEvent");
            if (luaObject.isFunction()) {
                LuaAccessibilityService.onAccessibilityEvent = luaObject.getFunction();
            }
            a();
            b();
            try {
                throw new RuntimeException(BuildConfig.FLAVOR);
            } catch (Exception e) {
                ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
                e.printStackTrace(new PrintStream(byteArrayOutputStream));
                String[] strArrSplit = byteArrayOutputStream.toString().split("\n");
                for (int i = 1; i < strArrSplit.length; i++) {
                    String str = strArrSplit[i];
                    if (!str.contains(BuildConfig.APPLICATION_ID) && !str.contains("com.nirenr.talkman") && !str.contains("android.app") && !str.contains("android.os") && !str.contains("java.lang") && !str.contains("com.android")) {
                        runFunc("onHook", new Object[0]);
                        return;
                    }
                }
            }
        } catch (Exception e2) {
            sendMsg(e2.getMessage());
            setContentView(this.r);
        }
    }

    @Override // android.app.Activity, android.view.View.OnCreateContextMenuListener
    public void onCreateContextMenu(ContextMenu contextMenu, View view, ContextMenu.ContextMenuInfo contextMenuInfo) {
        runFunc("onCreateContextMenu", contextMenu, view, contextMenuInfo);
        super.onCreateContextMenu(contextMenu, view, contextMenuInfo);
    }

    @Override // android.app.Activity
    public boolean onCreateOptionsMenu(Menu menu) {
        this.u = menu;
        runFunc("onCreateOptionsMenu", menu);
        return super.onCreateOptionsMenu(menu);
    }

    @Override // android.app.Activity
    protected void onDestroy() {
        LuaBroadcastReceiver luaBroadcastReceiver = this.D;
        if (luaBroadcastReceiver != null) {
            unregisterReceiver(luaBroadcastReceiver);
        }
        Iterator<LuaGcable> it = this.J.iterator();
        while (it.hasNext()) {
            it.next().gc();
        }
        c.remove(this.K);
        runFunc("onDestroy", new Object[0]);
        super.onDestroy();
        System.gc();
        this.m.gc(2, 1);
    }

    @Override // android.app.Activity, android.view.KeyEvent.Callback
    public boolean onKeyDown(int i, KeyEvent keyEvent) {
        LuaObject luaObject = this.v;
        if (luaObject != null) {
            try {
                Object objCall = luaObject.call(Integer.valueOf(i), keyEvent);
                if (objCall != null && objCall.getClass() == Boolean.class) {
                    if (((Boolean) objCall).booleanValue()) {
                        return true;
                    }
                }
            } catch (LuaException e) {
                sendError("onKeyDown", e);
            }
        }
        return super.onKeyDown(i, keyEvent);
    }

    @Override // android.app.Activity, android.view.KeyEvent.Callback
    public boolean onKeyLongPress(int i, KeyEvent keyEvent) {
        LuaObject luaObject = this.x;
        if (luaObject != null) {
            try {
                Object objCall = luaObject.call(Integer.valueOf(i), keyEvent);
                if (objCall != null && objCall.getClass() == Boolean.class) {
                    if (((Boolean) objCall).booleanValue()) {
                        return true;
                    }
                }
            } catch (LuaException e) {
                sendError("onKeyLongPress", e);
            }
        }
        return super.onKeyLongPress(i, keyEvent);
    }

    @Override // android.app.Activity
    public boolean onKeyShortcut(int i, KeyEvent keyEvent) {
        LuaObject luaObject = this.L;
        if (luaObject != null) {
            try {
                Object objCall = luaObject.call(Integer.valueOf(i), keyEvent);
                if (objCall != null && objCall.getClass() == Boolean.class) {
                    if (((Boolean) objCall).booleanValue()) {
                        return true;
                    }
                }
            } catch (LuaException e) {
                sendError("onKeyShortcut", e);
            }
        }
        return super.onKeyShortcut(i, keyEvent);
    }

    @Override // android.app.Activity, android.view.KeyEvent.Callback
    public boolean onKeyUp(int i, KeyEvent keyEvent) {
        LuaObject luaObject = this.w;
        if (luaObject != null) {
            try {
                Object objCall = luaObject.call(Integer.valueOf(i), keyEvent);
                if (objCall != null && objCall.getClass() == Boolean.class) {
                    if (((Boolean) objCall).booleanValue()) {
                        return true;
                    }
                }
            } catch (LuaException e) {
                sendError("onKeyUp", e);
            }
        }
        return super.onKeyUp(i, keyEvent);
    }

    @Override // android.app.Activity, android.view.Window.Callback
    public boolean onMenuItemSelected(int i, MenuItem menuItem) {
        if (!menuItem.hasSubMenu()) {
            runFunc("onMenuItemSelected", Integer.valueOf(i), menuItem);
        }
        return super.onMenuItemSelected(i, menuItem);
    }

    @Override // android.app.Activity
    public boolean onOptionsItemSelected(MenuItem menuItem) {
        Object objRunFunc = !menuItem.hasSubMenu() ? runFunc("onOptionsItemSelected", menuItem) : null;
        if (objRunFunc != null && objRunFunc.getClass() == Boolean.class && ((Boolean) objRunFunc).booleanValue()) {
            return true;
        }
        return super.onOptionsItemSelected(menuItem);
    }

    @Override // android.app.Activity
    protected void onPause() {
        super.onPause();
        runFunc("onPause", new Object[0]);
    }

    @Override // com.androlua.LuaBroadcastReceiver.OnReceiveListener
    public void onReceive(Context context, Intent intent) {
        runFunc("onReceive", context, intent);
    }

    @Override // android.app.Activity
    public void onRequestPermissionsResult(int i, String[] strArr, int[] iArr) {
        super.onRequestPermissionsResult(i, strArr, iArr);
        runFunc("onRequestPermissionsResult", Integer.valueOf(i), strArr, iArr);
    }

    @Override // android.app.Activity
    protected void onResume() {
        super.onResume();
        runFunc("onResume", new Object[0]);
    }

    @Override // android.app.Activity
    protected void onStart() {
        super.onStart();
        runFunc("onStart", new Object[0]);
        StatService.onPageStart(this, this.K);
    }

    @Override // android.app.Activity
    protected void onStop() {
        super.onStop();
        runFunc("onStop", new Object[0]);
        StatService.onPageEnd(this, this.K);
    }

    @Override // android.app.Activity
    public boolean onTouchEvent(MotionEvent motionEvent) {
        LuaObject luaObject = this.y;
        if (luaObject != null) {
            try {
                Object objCall = luaObject.call(motionEvent);
                if (objCall != null && objCall.getClass() == Boolean.class) {
                    if (((Boolean) objCall).booleanValue()) {
                        return true;
                    }
                }
            } catch (LuaException e) {
                sendError("onTouchEvent", e);
            }
        }
        return super.onTouchEvent(motionEvent);
    }

    public void push(int i, String str) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        message.setData(bundle);
        message.what = i;
        this.e.sendMessage(message);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void push(int i, String str, Object[] objArr) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        bundle.putSerializable("args", objArr);
        message.setData(bundle);
        message.what = i;
        this.e.sendMessage(message);
    }

    public byte[] readAsset(String str) throws IOException {
        InputStream inputStreamOpen = getAssets().open(str);
        byte[] bArrA = a(inputStreamOpen);
        inputStreamOpen.close();
        return bArrA;
    }

    @Override // com.androlua.LuaContext
    public void regGc(LuaGcable luaGcable) {
        this.J.add(luaGcable);
    }

    public Intent registerReceiver(IntentFilter intentFilter) {
        LuaBroadcastReceiver luaBroadcastReceiver = this.D;
        if (luaBroadcastReceiver != null) {
            unregisterReceiver(luaBroadcastReceiver);
        }
        this.D = new LuaBroadcastReceiver(this);
        return super.registerReceiver((BroadcastReceiver) this.D, intentFilter);
    }

    public Intent registerReceiver(LuaBroadcastReceiver.OnReceiveListener onReceiveListener, IntentFilter intentFilter) {
        return super.registerReceiver((BroadcastReceiver) new LuaBroadcastReceiver(onReceiveListener), intentFilter);
    }

    public Intent registerReceiver(LuaBroadcastReceiver luaBroadcastReceiver, IntentFilter intentFilter) {
        return super.registerReceiver((BroadcastReceiver) luaBroadcastReceiver, intentFilter);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void result(Object[] objArr) {
        Intent intent = new Intent();
        intent.putExtra("name", getIntent().getStringExtra("name"));
        intent.putExtra("data", (Serializable) objArr);
        setResult(0, intent);
        finish();
    }

    public Object runFunc(String str, Object... objArr) {
        LuaState luaState = this.m;
        if (luaState == null) {
            return null;
        }
        synchronized (luaState) {
            try {
                this.m.setTop(0);
                this.m.pushGlobalTable();
                this.m.pushString(str);
                this.m.rawGet(-2);
                if (this.m.isFunction(-1)) {
                    this.m.getGlobal("debug");
                    this.m.getField(-1, "traceback");
                    this.m.remove(-2);
                    this.m.insert(-2);
                    int length = objArr.length;
                    for (Object obj : objArr) {
                        this.m.pushObjectValue(obj);
                    }
                    int iPcall = this.m.pcall(length, 1, (-2) - length);
                    if (iPcall == 0) {
                        return this.m.toJavaObject(-1);
                    }
                    throw new LuaException(a(iPcall) + ": " + this.m.toString(-1));
                }
            } catch (LuaException e) {
                sendError(str, e);
            }
            return null;
        }
    }

    @Override // com.androlua.LuaContext
    public void sendError(String str, Exception exc) {
        Object objRunFunc = runFunc("onError", str, exc);
        if (objRunFunc != null && objRunFunc.getClass() == Boolean.class && ((Boolean) objRunFunc).booleanValue()) {
            return;
        }
        sendMsg(str + ": " + exc.getMessage());
    }

    @Override // com.androlua.LuaContext
    public void sendMsg(String str) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        message.setData(bundle);
        message.what = 0;
        this.e.sendMessage(message);
        Log.i("lua", str);
    }

    @Override // com.androlua.LuaContext
    public void set(String str, Object obj) {
        push(1, str, new Object[]{obj});
    }

    public void setContentView(LuaObject luaObject) throws LuaException {
        setContentView(luaObject, (LuaObject) null);
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public void setContentView(LuaObject luaObject, LuaObject luaObject2) throws LuaException {
        Object[] objArr;
        LuaObject luaObject3 = this.m.getLuaObject("loadlayout");
        if (luaObject.isString()) {
            objArr = new Object[]{luaObject.getString(), luaObject2};
        } else {
            if (!luaObject.isTable()) {
                throw new LuaException("layout may be table or string.");
            }
            objArr = new Object[]{luaObject, luaObject2};
        }
        super.setContentView((View) luaObject3.call(objArr));
    }

    public void setContentView(String str) {
        setContentView(str, (LuaObject) null);
    }

    public void setContentView(String str, LuaObject luaObject) {
        super.setContentView((View) this.m.getLuaObject("loadlayout").call(str, luaObject));
    }

    public void setDebug(boolean z) {
        this.H = z;
    }

    public void setFragment(Fragment fragment) {
        this.s = true;
        setContentView(new View(this));
        getFragmentManager().beginTransaction().replace(android.R.id.content, fragment).commit();
    }

    public void setLuaDir(String str) {
        this.d = str;
    }

    /* JADX WARN: Removed duplicated region for block: B:20:0x0065  */
    /* JADX WARN: Removed duplicated region for block: B:26:? A[RETURN, SYNTHETIC] */
    @Override // com.androlua.LuaContext
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public void setLuaExtDir(java.lang.String r8) {
        /*
            r7 = this;
            java.lang.String r0 = android.os.Environment.getExternalStorageState()
            java.lang.String r1 = "mounted"
            boolean r0 = r0.equals(r1)
            if (r0 == 0) goto L20
            java.io.File r0 = android.os.Environment.getExternalStorageDirectory()
            java.lang.String r0 = r0.getAbsolutePath()
            java.io.File r1 = new java.io.File
            r1.<init>(r0, r8)
            java.lang.String r8 = r1.getAbsolutePath()
        L1d:
            r7.C = r8
            goto L58
        L20:
            java.io.File r0 = new java.io.File
            java.lang.String r1 = "/storage"
            r0.<init>(r1)
            java.io.File[] r0 = r0.listFiles()
            int r1 = r0.length
            r2 = 0
            r3 = 0
        L2e:
            if (r3 >= r1) goto L4b
            r4 = r0[r3]
            java.lang.String[] r5 = r4.list()
            if (r5 != 0) goto L39
            goto L48
        L39:
            int r5 = r5.length
            r6 = 5
            if (r5 <= r6) goto L48
            java.io.File r5 = new java.io.File
            r5.<init>(r4, r8)
            java.lang.String r4 = r5.getAbsolutePath()
            r7.C = r4
        L48:
            int r3 = r3 + 1
            goto L2e
        L4b:
            java.lang.String r0 = r7.C
            if (r0 != 0) goto L58
            java.io.File r8 = r7.getDir(r8, r2)
            java.lang.String r8 = r8.getAbsolutePath()
            goto L1d
        L58:
            java.io.File r8 = new java.io.File
            java.lang.String r0 = r7.C
            r8.<init>(r0)
            boolean r0 = r8.exists()
            if (r0 != 0) goto L68
            r8.mkdirs()
        L68:
            return
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaActivity.setLuaExtDir(java.lang.String):void");
    }

    @Override // com.androlua.LuaContext
    public boolean setSharedData(String str, Object obj) {
        return LuaApplication.getInstance().setSharedData(str, obj);
    }

    @Override // android.app.Activity
    public void setTitle(CharSequence charSequence) {
        ActivityManager.TaskDescription taskDescription;
        super.setTitle(charSequence);
        if (Build.VERSION.SDK_INT >= 21) {
            try {
                taskDescription = new ActivityManager.TaskDescription(charSequence.toString(), loadBitmap(getLuaPath("icon.png")));
            } catch (IOException e) {
                e.printStackTrace();
                taskDescription = new ActivityManager.TaskDescription(charSequence.toString());
            }
            setTaskDescription(taskDescription);
        }
    }

    public void shareFile(String str) {
        Intent intent = new Intent("android.intent.action.SEND");
        File file = new File(str);
        intent.setType(a(file));
        intent.setFlags(1);
        intent.putExtra("android.intent.extra.STREAM", getUriForFile(file));
        startActivity(Intent.createChooser(intent, file.getName()));
    }

    public void showLogs() {
        new AlertDialog.Builder(this).setTitle("Logs").setAdapter(this.l, null).setPositiveButton(android.R.string.ok, (DialogInterface.OnClickListener) null).create().show();
    }

    @SuppressLint({"ShowToast"})
    public void showToast(String str) {
        long jCurrentTimeMillis = System.currentTimeMillis();
        if (this.q == null || jCurrentTimeMillis - this.t > 1000) {
            this.o.setLength(0);
            this.q = Toast.makeText(this, str, 1);
            this.o.append(str);
            this.q.show();
        } else {
            this.o.append("\n");
            this.o.append(str);
            this.q.setText(this.o.toString());
            this.q.setDuration(1);
        }
        this.t = jCurrentTimeMillis;
    }

    public ComponentName startService() {
        return startService(null, null);
    }

    public ComponentName startService(String str) {
        return startService(str, null);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public ComponentName startService(String str, Object[] objArr) {
        StringBuilder sb;
        Intent intent = new Intent(this, (Class<?>) LuaService.class);
        intent.putExtra("luaDir", this.d);
        intent.putExtra("luaPath", this.n);
        if (str != null) {
            if (str.charAt(0) != '/') {
                sb = new StringBuilder();
                sb.append("file://");
                sb.append(this.d);
                sb.append("/");
                sb.append(str);
                str = ".lua";
            } else {
                sb = new StringBuilder();
                sb.append("file://");
            }
            sb.append(str);
            intent.setData(Uri.parse(sb.toString()));
        }
        if (objArr != 0) {
            intent.putExtra("arg", (Serializable) objArr);
        }
        return super.startService(intent);
    }

    public ComponentName startService(Object[] objArr) {
        return startService(null, objArr);
    }

    public boolean stopService() {
        return stopService(new Intent(this, (Class<?>) LuaService.class));
    }

    public LuaAsyncTask task(long j, LuaObject luaObject) {
        return task(j, (Object[]) null, (LuaObject) null);
    }

    public LuaAsyncTask task(long j, Object[] objArr, LuaObject luaObject) {
        LuaAsyncTask luaAsyncTask = new LuaAsyncTask(this, j, luaObject);
        luaAsyncTask.execute(objArr);
        return luaAsyncTask;
    }

    public LuaAsyncTask task(LuaObject luaObject) {
        return task(luaObject, null, null, null);
    }

    public LuaAsyncTask task(LuaObject luaObject, LuaObject luaObject2, LuaObject luaObject3) {
        return task(luaObject, null, luaObject2, luaObject3);
    }

    public LuaAsyncTask task(LuaObject luaObject, Object[] objArr) {
        return task(luaObject, objArr, null, null);
    }

    public LuaAsyncTask task(LuaObject luaObject, Object[] objArr, LuaObject luaObject2) {
        return task(luaObject, null, null, luaObject2);
    }

    public LuaAsyncTask task(LuaObject luaObject, Object[] objArr, LuaObject luaObject2, LuaObject luaObject3) {
        LuaAsyncTask luaAsyncTask = new LuaAsyncTask(this, luaObject, luaObject2, luaObject3);
        luaAsyncTask.execute(objArr);
        return luaAsyncTask;
    }

    public long test(String str, int i) {
        long jCurrentTimeMillis = System.currentTimeMillis();
        for (int i2 = 0; i2 < i; i2++) {
            this.m.LdoString(str);
        }
        return System.currentTimeMillis() - jCurrentTimeMillis;
    }

    public LuaThread thread(LuaObject luaObject) {
        LuaThread luaThreadNewThread = newThread(luaObject, new Object[0]);
        luaThreadNewThread.start();
        return luaThreadNewThread;
    }

    public LuaThread thread(LuaObject luaObject, Object[] objArr) {
        LuaThread luaThread = new LuaThread((LuaContext) this, luaObject, true, objArr);
        luaThread.start();
        return luaThread;
    }

    public Ticker ticker(final LuaObject luaObject, long j) {
        Ticker ticker = new Ticker();
        ticker.setOnTickListener(new Ticker.OnTickListener() { // from class: com.androlua.LuaActivity.3
            @Override // com.androlua.Ticker.OnTickListener
            public void onTick() {
                try {
                    luaObject.call(new Object[0]);
                } catch (LuaException e) {
                    e.printStackTrace();
                    LuaActivity.this.sendError("onTick", e);
                }
            }
        });
        ticker.start();
        ticker.setPeriod(j);
        return ticker;
    }

    public LuaTimer timer(LuaObject luaObject, long j) {
        return timer(luaObject, 0L, j, new Object[0]);
    }

    public LuaTimer timer(LuaObject luaObject, long j, long j2) {
        return timer(luaObject, j, j2, new Object[0]);
    }

    public LuaTimer timer(LuaObject luaObject, long j, long j2, Object[] objArr) {
        LuaTimer luaTimer = new LuaTimer(this, luaObject, objArr);
        luaTimer.start(j, j2);
        return luaTimer;
    }

    public LuaTimer timer(LuaObject luaObject, long j, Object[] objArr) {
        return timer(luaObject, 0L, j, objArr);
    }

    public void unZipAssets(String str, String str2) throws IOException {
        File file = new File(str2);
        if (!file.exists()) {
            file.mkdirs();
        }
        try {
            ZipInputStream zipInputStream = new ZipInputStream(getAssets().open(str));
            byte[] bArr = new byte[4096];
            for (ZipEntry nextEntry = zipInputStream.getNextEntry(); nextEntry != null; nextEntry = zipInputStream.getNextEntry()) {
                if (nextEntry.isDirectory()) {
                    new File(str2 + File.separator + nextEntry.getName()).mkdir();
                } else {
                    File file2 = new File(str2 + File.separator + nextEntry.getName());
                    file2.createNewFile();
                    FileOutputStream fileOutputStream = new FileOutputStream(file2);
                    while (true) {
                        int i = zipInputStream.read(bArr);
                        if (i <= 0) {
                            break;
                        } else {
                            fileOutputStream.write(bArr, 0, i);
                        }
                    }
                    fileOutputStream.close();
                }
            }
            zipInputStream.close();
        } catch (IOException unused) {
        }
    }

    @Override // android.content.ContextWrapper, android.content.Context
    public void unregisterReceiver(BroadcastReceiver broadcastReceiver) {
        try {
            super.unregisterReceiver(broadcastReceiver);
        } catch (Exception e) {
            Log.i("lua", "unregisterReceiver: " + broadcastReceiver);
            e.printStackTrace();
        }
    }
}