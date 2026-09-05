package com.androlua;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.Thread;
import java.lang.reflect.Field;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class CrashHandler implements Thread.UncaughtExceptionHandler {
    public static final String TAG = "CrashHandler";
    private static CrashHandler a = new CrashHandler();
    private Thread.UncaughtExceptionHandler b;
    private Context c;
    private Map<String, String> d = new LinkedHashMap();
    private DateFormat e = new SimpleDateFormat("yyyy-MM-dd-HH-mm-ss");

    private CrashHandler() {
    }

    private boolean a(Throwable th) throws IllegalAccessException, PackageManager.NameNotFoundException, IOException, IllegalArgumentException {
        if (th == null) {
            return false;
        }
        collectDeviceInfo(this.c);
        b(th);
        return true;
    }

    private String b(Throwable th) throws IOException {
        StringBuffer stringBuffer = new StringBuffer();
        for (Map.Entry<String, String> entry : this.d.entrySet()) {
            stringBuffer.append(entry.getKey() + "=" + entry.getValue() + "\n");
        }
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        do {
            th.printStackTrace(printWriter);
            th = th.getCause();
        } while (th != null);
        printWriter.close();
        stringBuffer.append(stringWriter.toString());
        try {
            long jCurrentTimeMillis = System.currentTimeMillis();
            String str = "crash-" + this.e.format(new Date()) + "-" + jCurrentTimeMillis + ".log";
            if (Environment.getExternalStorageState().equals("mounted")) {
                File file = new File("/sdcard/androlua/crash/");
                if (!file.exists()) {
                    file.mkdirs();
                }
                FileOutputStream fileOutputStream = new FileOutputStream("/sdcard/androlua/crash/" + str);
                fileOutputStream.write(stringBuffer.toString().getBytes());
                Log.e("crash", stringBuffer.toString());
                fileOutputStream.close();
            }
            return str;
        } catch (Exception e) {
            Log.e(TAG, "an error occured while writing file...", e);
            return null;
        }
    }

    public static CrashHandler getInstance() {
        return a;
    }

    public void collectDeviceInfo(Context context) throws IllegalAccessException, PackageManager.NameNotFoundException, IllegalArgumentException {
        Map<String, String> map;
        String name;
        String string;
        Map<String, String> map2;
        String name2;
        String string2;
        try {
            PackageInfo packageInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 1);
            if (packageInfo != null) {
                String str = packageInfo.versionName == null ? "null" : packageInfo.versionName;
                String str2 = packageInfo.versionCode + BuildConfig.FLAVOR;
                this.d.put("versionName", str);
                this.d.put("versionCode", str2);
            }
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "an error occured when collect package info", e);
        }
        for (Field field : Build.class.getDeclaredFields()) {
            try {
                field.setAccessible(true);
                Object obj = field.get(null);
                if (obj instanceof String[]) {
                    map2 = this.d;
                    name2 = field.getName();
                    string2 = Arrays.toString((String[]) obj);
                } else {
                    map2 = this.d;
                    name2 = field.getName();
                    string2 = obj.toString();
                }
                map2.put(name2, string2);
                Log.d(TAG, field.getName() + " : " + field.get(null));
            } catch (Exception e2) {
                Log.e(TAG, "an error occured when collect crash info", e2);
            }
        }
        for (Field field2 : Build.VERSION.class.getDeclaredFields()) {
            try {
                field2.setAccessible(true);
                Object obj2 = field2.get(null);
                if (obj2 instanceof String[]) {
                    map = this.d;
                    name = field2.getName();
                    string = Arrays.toString((String[]) obj2);
                } else {
                    map = this.d;
                    name = field2.getName();
                    string = obj2.toString();
                }
                map.put(name, string);
                Log.d(TAG, field2.getName() + " : " + field2.get(null));
            } catch (Exception e3) {
                Log.e(TAG, "an error occured when collect crash info", e3);
            }
        }
    }

    public void init(Context context) {
        this.c = context;
        this.b = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler(this);
    }

    @Override // java.lang.Thread.UncaughtExceptionHandler
    public void uncaughtException(Thread thread, Throwable th) {
        Thread.UncaughtExceptionHandler uncaughtExceptionHandler;
        if (a(th) || (uncaughtExceptionHandler = this.b) == null) {
            return;
        }
        uncaughtExceptionHandler.uncaughtException(thread, th);
    }
}