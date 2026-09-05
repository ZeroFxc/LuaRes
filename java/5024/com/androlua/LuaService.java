package com.androlua;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.net.Uri;
import android.os.Binder;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;
import com.androlua.LuaBroadcastReceiver;
import com.androlua.Ticker;
import com.luajava.JavaFunction;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import dalvik.system.DexClassLoader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaService extends Service implements LuaContext, LuaBroadcastReceiver.OnReceiveListener {
    private static LuaService a;
    private LuaDexLoader c;
    private String e;
    private MainHandler f;
    private String g;
    private LuaState h;
    private String i;
    private String j;
    private String k;
    private String l;
    public String luaCpath;
    public String luaDir;
    private String m;
    private BroadcastReceiver n;
    private Toast p;
    private long r;
    private LuaResources s;
    LuaBinder b = new LuaBinder();
    private ArrayList<LuaGcable> d = new ArrayList<>();
    private StringBuilder o = new StringBuilder();
    private StringBuilder q = new StringBuilder();

    public class LuaBinder extends Binder {
        public LuaBinder() {
        }

        public LuaService getService() {
            return LuaService.this;
        }
    }

    public class MainHandler extends Handler {
        public MainHandler() {
        }

        @Override // android.os.Handler
        public void handleMessage(Message message) throws LuaException {
            super.handleMessage(message);
            int i = message.what;
            if (i == 0) {
                LuaService.this.showToast(message.getData().getString("data"));
                return;
            }
            if (i == 1) {
                Bundle data = message.getData();
                LuaService.this.a(data.getString("data"), ((Object[]) data.getSerializable("args"))[0]);
            } else if (i == 2) {
                LuaService.this.runFunc(message.getData().getString("data"), new Object[0]);
            } else {
                if (i != 3) {
                    return;
                }
                LuaService.this.runFunc(message.getData().getString("data"), (Object[]) message.getData().getSerializable("args"));
            }
        }
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

    private void a() {
        this.h = LuaStateFactory.newLuaState();
        this.h.openLibs();
        this.h.pushJavaObject(this);
        this.h.setGlobal("service");
        this.h.getGlobal("service");
        this.h.setGlobal("this");
        this.h.pushContext(this);
        this.h.getGlobal("luajava");
        this.h.pushString(this.m);
        this.h.setField(-2, "luaextdir");
        this.h.pushString(this.luaDir);
        this.h.setField(-2, "luadir");
        this.h.pushString(this.i);
        this.h.setField(-2, "luapath");
        this.h.pop(1);
        new LuaAssetLoader(this, this.h);
        this.h.getGlobal("package");
        this.h.pushString(this.e);
        this.h.setField(-2, "path");
        this.h.pushString(this.luaCpath);
        this.h.setField(-2, "cpath");
        this.h.pop(1);
        new JavaFunction(this.h) { // from class: com.androlua.LuaService.2
            @Override // com.luajava.JavaFunction
            public int execute() {
                if (this.a.getTop() < 2) {
                    LuaService.this.sendMsg(BuildConfig.FLAVOR);
                    return 0;
                }
                for (int i = 2; i <= this.a.getTop(); i++) {
                    String string = null;
                    String strTypeName = this.a.typeName(this.a.type(i));
                    char c = '\uffff';
                    int iHashCode = strTypeName.hashCode();
                    if (iHashCode != -266011147) {
                        if (iHashCode == 64711720 && strTypeName.equals("boolean")) {
                            c = 1;
                        }
                    } else if (strTypeName.equals("userdata")) {
                        c = 0;
                    }
                    if (c == 0) {
                        Object javaObject = this.a.toJavaObject(i);
                        if (javaObject != null) {
                            string = javaObject.toString();
                        }
                    } else if (c != 1) {
                        string = this.a.toString(i);
                    } else {
                        string = this.a.toBoolean(i) ? "true" : "false";
                    }
                    if (string != null) {
                        strTypeName = string;
                    }
                    LuaService.this.o.append("\t");
                    LuaService.this.o.append(strTypeName);
                    LuaService.this.o.append("\t");
                }
                LuaService luaService = LuaService.this;
                luaService.sendMsg(luaService.o.toString().substring(1, LuaService.this.o.length() - 1));
                LuaService.this.o.setLength(0);
                return 0;
            }
        }.register("print");
        new JavaFunction(this.h) { // from class: com.androlua.LuaService.3
            @Override // com.luajava.JavaFunction
            public int execute() {
                ((LuaThread) this.a.toJavaObject(2)).set(this.a.toString(3), this.a.toJavaObject(4));
                return 0;
            }
        }.register("set");
        new JavaFunction(this.h) { // from class: com.androlua.LuaService.4
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

    private void a(String str, Object obj) {
        try {
            this.h.pushObjectValue(obj);
            this.h.setGlobal(str);
        } catch (LuaException e) {
            sendMsg(e.getMessage());
        }
    }

    private void a(String str, String str2) throws IOException {
        try {
            if (!new File(str).exists()) {
                return;
            }
            FileInputStream fileInputStream = new FileInputStream(str);
            FileOutputStream fileOutputStream = new FileOutputStream(str2);
            byte[] bArr = new byte[4096];
            int i = 0;
            while (true) {
                int i2 = fileInputStream.read(bArr);
                if (i2 == -1) {
                    fileInputStream.close();
                    return;
                } else {
                    i += i2;
                    System.out.println(i);
                    fileOutputStream.write(bArr, 0, i2);
                }
            }
        } catch (Exception e) {
            System.out.println("\u590d\u5236\u6587\u4ef6\u64cd\u4f5c\u51fa\u9519");
            e.printStackTrace();
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

    public static LuaService getService() {
        return a;
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

    public Object doAsset(String str, Object... objArr) throws LuaException {
        try {
            byte[] asset = readAsset(str);
            this.h.setTop(0);
            int iLloadBuffer = this.h.LloadBuffer(asset, str);
            if (iLloadBuffer == 0) {
                this.h.getGlobal("debug");
                this.h.getField(-1, "traceback");
                this.h.remove(-2);
                this.h.insert(-2);
                int length = objArr != null ? objArr.length : 0;
                for (int i = 0; i < length; i++) {
                    this.h.pushObjectValue(objArr[i]);
                }
                iLloadBuffer = this.h.pcall(length, 0, (-2) - length);
                if (iLloadBuffer == 0) {
                    return this.h.toJavaObject(-1);
                }
            }
            throw new LuaException(a(iLloadBuffer) + ": " + this.h.toString(-1));
        } catch (Exception e) {
            sendMsg(e.getMessage());
            return null;
        }
    }

    public Object doFile(String str) {
        return doFile(str, new Object[0]);
    }

    @Override // com.androlua.LuaContext
    public Object doFile(String str, Object[] objArr) throws LuaException {
        try {
            if (str.charAt(0) != '/') {
                str = this.luaDir + "/" + str;
            }
            this.h.setTop(0);
            int iLloadFile = this.h.LloadFile(str);
            if (iLloadFile == 0) {
                this.h.getGlobal("debug");
                this.h.getField(-1, "traceback");
                this.h.remove(-2);
                this.h.insert(-2);
                int length = objArr != null ? objArr.length : 0;
                for (int i = 0; i < length; i++) {
                    this.h.pushObjectValue(objArr[i]);
                }
                iLloadFile = this.h.pcall(length, 1, (-2) - length);
                if (iLloadFile == 0) {
                    return this.h.toJavaObject(-1);
                }
            }
            throw new LuaException(a(iLloadFile) + ": " + this.h.toString(-1));
        } catch (LuaException e) {
            sendMsg(e.getMessage());
            return null;
        }
    }

    public Object doString(String str, Object... objArr) throws LuaException {
        try {
            this.h.setTop(0);
            int iLloadString = this.h.LloadString(str);
            if (iLloadString == 0) {
                this.h.getGlobal("debug");
                this.h.getField(-1, "traceback");
                this.h.remove(-2);
                this.h.insert(-2);
                int length = objArr != null ? objArr.length : 0;
                for (int i = 0; i < length; i++) {
                    this.h.pushObjectValue(objArr[i]);
                }
                iLloadString = this.h.pcall(length, 1, (-2) - length);
                if (iLloadString == 0) {
                    return this.h.toJavaObject(-1);
                }
            }
            throw new LuaException(a(iLloadString) + ": " + this.h.toString(-1));
        } catch (LuaException e) {
            sendMsg(e.getMessage());
            return null;
        }
    }

    public Object get(String str) {
        this.h.getGlobal(str);
        return this.h.toJavaObject(-1);
    }

    @Override // android.content.ContextWrapper, android.content.Context
    public AssetManager getAssets() {
        LuaDexLoader luaDexLoader = this.c;
        return (luaDexLoader == null || luaDexLoader.getAssets() == null) ? super.getAssets() : this.c.getAssets();
    }

    public LuaBinder getBinder() {
        return this.b;
    }

    @Override // com.androlua.LuaContext
    public ArrayList<ClassLoader> getClassLoaders() {
        return this.c.getClassLoaders();
    }

    @Override // com.androlua.LuaContext
    public Context getContext() {
        return this;
    }

    @Override // com.androlua.LuaContext
    public Map getGlobalData() {
        return LuaApplication.getInstance().getGlobalData();
    }

    @Override // com.androlua.LuaContext
    public int getHeight() {
        return getResources().getDisplayMetrics().heightPixels;
    }

    public HashMap<String, String> getLibrarys() {
        return this.c.getLibrarys();
    }

    @Override // com.androlua.LuaContext
    public String getLuaCpath() {
        return this.luaCpath;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir() {
        return this.luaDir;
    }

    @Override // com.androlua.LuaContext
    public String getLuaDir(String str) {
        File file = new File(this.luaDir + "/" + str);
        if (file.exists() || file.mkdirs()) {
            return file.getAbsolutePath();
        }
        return null;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir() {
        return this.m;
    }

    @Override // com.androlua.LuaContext
    public String getLuaExtDir(String str) {
        File file = new File(this.m + "/" + str);
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
        return this.e;
    }

    @Override // com.androlua.LuaContext
    public String getLuaPath() {
        return this.i;
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
        LuaDexLoader luaDexLoader = this.c;
        if (luaDexLoader != null && luaDexLoader.getResources() != null) {
            resources = this.c.getResources();
        }
        this.s = new LuaResources(getAssets(), resources.getDisplayMetrics(), resources.getConfiguration());
        this.s.setSuperResources(resources);
        return this.s;
    }

    @Override // com.androlua.LuaContext
    public LuaState getLuaState() {
        return this.h;
    }

    @Override // android.content.ContextWrapper, android.content.Context
    public Resources getResources() {
        LuaDexLoader luaDexLoader = this.c;
        if (luaDexLoader != null && luaDexLoader.getResources() != null) {
            return this.c.getResources();
        }
        LuaResources luaResources = this.s;
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

    @Override // com.androlua.LuaContext
    public int getWidth() {
        return getResources().getDisplayMetrics().widthPixels;
    }

    public DexClassLoader loadDex(String str) {
        return this.c.loadDex(str);
    }

    public Object loadLib(String str) throws LuaException, IOException {
        int iIndexOf = str.indexOf(".");
        String strSubstring = iIndexOf > 0 ? str.substring(0, iIndexOf) : str;
        if (!new File(this.l + "/lib" + strSubstring + ".so").exists()) {
            if (!new File(this.luaDir + "/lib" + strSubstring + ".so").exists()) {
                throw new LuaException("can not find lib " + str);
            }
            a(this.luaDir + "/lib" + strSubstring + ".so", this.l + "/lib" + strSubstring + ".so");
        }
        return this.h.getLuaObject("require").call(str);
    }

    public void loadResources(String str) {
        this.c.loadResources(str);
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
        return newThread(luaObject, null);
    }

    public LuaThread newThread(LuaObject luaObject, Object[] objArr) {
        return new LuaThread((LuaContext) this, luaObject, true, objArr);
    }

    public LuaTimer newTimer(LuaObject luaObject) {
        return newTimer(luaObject, null);
    }

    public LuaTimer newTimer(LuaObject luaObject, Object[] objArr) {
        return new LuaTimer(this, luaObject, objArr);
    }

    @Override // android.app.Service
    public IBinder onBind(Intent intent) {
        startForeground(1, new Notification());
        return new LuaBinder();
    }

    @Override // android.app.Service
    public void onCreate() {
        super.onCreate();
        a = this;
        LuaApplication luaApplication = (LuaApplication) getApplication();
        this.j = luaApplication.getLocalDir();
        this.k = luaApplication.getOdexDir();
        this.l = luaApplication.getLibDir();
        this.g = luaApplication.getMdDir();
        this.luaCpath = luaApplication.getLuaCpath();
        this.luaDir = this.j;
        this.e = luaApplication.getLuaLpath();
        this.m = luaApplication.getLuaExtDir();
        this.f = new MainHandler();
    }

    @Override // android.app.Service
    public void onDestroy() throws LuaException {
        runFunc("onDestroy", new Object[0]);
        BroadcastReceiver broadcastReceiver = this.n;
        if (broadcastReceiver != null) {
            unregisterReceiver(broadcastReceiver);
        }
        super.onDestroy();
    }

    @Override // com.androlua.LuaBroadcastReceiver.OnReceiveListener
    public void onReceive(Context context, Intent intent) throws LuaException {
        runFunc("onReceive", context, intent);
    }

    @Override // android.app.Service
    public int onStartCommand(Intent intent, int i, int i2) throws LuaException {
        a = this;
        if (this.h == null) {
            startForeground(1, new Notification());
            this.i = intent.getStringExtra("luaPath");
            this.luaDir = intent.getStringExtra("luaDir");
            this.e = this.luaDir + "/?.lua;" + this.luaDir + "/lua/?.lua;" + this.luaDir + "/?/init.lua;" + this.e;
            Uri data = intent.getData();
            try {
                a();
                this.c = new LuaDexLoader(this);
                this.c.loadLibs();
                doFile(data != null ? data.getPath() : "service.lua");
            } catch (Exception e) {
                sendMsg(e.getMessage());
            }
        }
        runFunc("onStartCommand", intent, Integer.valueOf(i), Integer.valueOf(i2));
        runFunc("onStart", (Object[]) intent.getSerializableExtra("arg"));
        return super.onStartCommand(intent, i, i2);
    }

    @Override // android.app.Service
    public boolean onUnbind(Intent intent) {
        return super.onUnbind(intent);
    }

    public void push(int i, String str) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        message.setData(bundle);
        message.what = i;
        this.f.sendMessage(message);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public void push(int i, String str, Object[] objArr) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        bundle.putSerializable("args", objArr);
        message.setData(bundle);
        message.what = i;
        this.f.sendMessage(message);
    }

    public byte[] readAsset(String str) throws IOException {
        InputStream inputStreamOpen = getAssets().open(str);
        byte[] bArrA = a(inputStreamOpen);
        inputStreamOpen.close();
        return bArrA;
    }

    @Override // com.androlua.LuaContext
    public void regGc(LuaGcable luaGcable) {
        this.d.add(luaGcable);
    }

    public Intent registerReceiver(IntentFilter intentFilter) {
        BroadcastReceiver broadcastReceiver = this.n;
        if (broadcastReceiver != null) {
            unregisterReceiver(broadcastReceiver);
        }
        this.n = new LuaBroadcastReceiver(this);
        return super.registerReceiver(this.n, intentFilter);
    }

    public Intent registerReceiver(LuaBroadcastReceiver.OnReceiveListener onReceiveListener, IntentFilter intentFilter) {
        return super.registerReceiver((BroadcastReceiver) new LuaBroadcastReceiver(onReceiveListener), intentFilter);
    }

    public Intent registerReceiver(LuaBroadcastReceiver luaBroadcastReceiver, IntentFilter intentFilter) {
        return super.registerReceiver((BroadcastReceiver) luaBroadcastReceiver, intentFilter);
    }

    public Object runFunc(String str, Object... objArr) throws LuaException {
        LuaState luaState = this.h;
        if (luaState == null) {
            return null;
        }
        try {
            luaState.setTop(0);
            this.h.getGlobal(str);
            if (!this.h.isFunction(-1)) {
                return null;
            }
            this.h.getGlobal("debug");
            this.h.getField(-1, "traceback");
            this.h.remove(-2);
            this.h.insert(-2);
            int length = objArr != null ? objArr.length : 0;
            for (int i = 0; i < length; i++) {
                this.h.pushObjectValue(objArr[i]);
            }
            int iPcall = this.h.pcall(length, 1, (-2) - length);
            if (iPcall == 0) {
                return this.h.toJavaObject(-1);
            }
            throw new LuaException(a(iPcall) + ": " + this.h.toString(-1));
        } catch (LuaException e) {
            sendMsg(str + " " + e.getMessage());
            return null;
        }
    }

    @Override // com.androlua.LuaContext
    public void sendError(String str, Exception exc) throws LuaException {
        runFunc("onError", str, exc);
    }

    @Override // com.androlua.LuaContext
    public void sendMsg(String str) {
        Message message = new Message();
        Bundle bundle = new Bundle();
        bundle.putString("data", str);
        message.setData(bundle);
        message.what = 0;
        this.f.sendMessage(message);
        Log.i("lua", str);
    }

    @Override // com.androlua.LuaContext
    public void set(String str, Object obj) {
        push(1, str, new Object[]{obj});
    }

    public void setBinder(LuaBinder luaBinder) {
        this.b = luaBinder;
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
            r7.m = r8
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
            r7.m = r4
        L48:
            int r3 = r3 + 1
            goto L2e
        L4b:
            java.lang.String r0 = r7.m
            if (r0 != 0) goto L58
            java.io.File r8 = r7.getDir(r8, r2)
            java.lang.String r8 = r8.getAbsolutePath()
            goto L1d
        L58:
            java.io.File r8 = new java.io.File
            java.lang.String r0 = r7.m
            r8.<init>(r0)
            boolean r0 = r8.exists()
            if (r0 != 0) goto L68
            r8.mkdirs()
        L68:
            return
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaService.setLuaExtDir(java.lang.String):void");
    }

    @Override // com.androlua.LuaContext
    public boolean setSharedData(String str, Object obj) {
        return LuaApplication.getInstance().setSharedData(str, obj);
    }

    @SuppressLint({"ShowToast"})
    public void showToast(String str) {
        try {
            long jCurrentTimeMillis = System.currentTimeMillis();
            if (this.p == null || jCurrentTimeMillis - this.r > 1000) {
                this.q.setLength(0);
                this.p = Toast.makeText(this, str, 1);
                this.q.append(str);
            } else {
                this.q.append("\n");
                this.q.append(str);
                this.p.setText(this.q.toString());
                this.p.setDuration(1);
            }
            this.r = jCurrentTimeMillis;
            this.p.show();
        } catch (Exception e) {
            e.printStackTrace();
        }
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

    public LuaThread thread(LuaObject luaObject) {
        LuaThread luaThreadNewThread = newThread(luaObject, null);
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
        ticker.setOnTickListener(new Ticker.OnTickListener() { // from class: com.androlua.LuaService.1
            @Override // com.androlua.Ticker.OnTickListener
            public void onTick() throws LuaException {
                try {
                    luaObject.call(new Object[0]);
                } catch (LuaException e) {
                    e.printStackTrace();
                    LuaService.this.sendError("onTick", e);
                }
            }
        });
        ticker.setPeriod(j);
        ticker.start();
        return ticker;
    }

    public LuaTimer timer(LuaObject luaObject, long j) {
        return timer(luaObject, 0L, j, null);
    }

    public LuaTimer timer(LuaObject luaObject, long j, long j2) {
        return timer(luaObject, j, j2, null);
    }

    public LuaTimer timer(LuaObject luaObject, long j, long j2, Object[] objArr) {
        LuaTimer luaTimer = new LuaTimer(this, luaObject, objArr);
        luaTimer.start(j, j2);
        return luaTimer;
    }

    public LuaTimer timer(LuaObject luaObject, long j, Object[] objArr) {
        return timer(luaObject, 0L, j, objArr);
    }
}