package com.androlua;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.widget.TextView;
import com.luajava.LuaFunction;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class Welcome extends Activity {
    private boolean a;
    private LuaApplication b;
    private String c;
    private String d;
    private long e;
    private long f;
    private boolean g;
    private String h;
    private String i;
    private ArrayList<String> j;

    @SuppressLint({"StaticFieldLeak"})
    public class UpdateTask extends AsyncTask<String, String, String> {
        private ZipFile a;
        private String b;

        private class FileWritingTask implements Runnable {
            private final ZipEntry a;
            private final String b;

            FileWritingTask(ZipEntry zipEntry, String str) {
                this.a = zipEntry;
                this.b = str;
            }

            /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
            @Override // java.lang.Runnable
            public void run() throws IOException {
                File file = new File(UpdateTask.this.b + File.separator + this.b);
                if (file.exists() && file.isDirectory()) {
                    LuaUtil.rmDir(file);
                }
                File parentFile = file.getParentFile();
                if (!parentFile.exists()) {
                    parentFile.mkdirs();
                }
                if (!parentFile.isDirectory()) {
                    throw new RuntimeException("WelcomeMTUnzip: ParentFile( path = \"" + parentFile.getAbsolutePath() + "\" ) is not a directory, the application can't write the File( name = \"" + file.getName() + "\" ) in a file.");
                }
                try {
                    InputStream inputStream = UpdateTask.this.a.getInputStream(this.a);
                    FileOutputStream fileOutputStream = new FileOutputStream(file);
                    byte[] bArr = new byte[2048];
                    while (true) {
                        int i = inputStream.read(bArr);
                        if (i < 0) {
                            fileOutputStream.close();
                            return;
                        }
                        fileOutputStream.write(bArr, 0, i);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                    throw new RuntimeException("WelcomeMTUnzip: unzip error at file " + file.getAbsolutePath() + ".");
                }
            }
        }

        public UpdateTask() {
        }

        private void a(long j, long j2) throws InterruptedException {
            LuaFunction function;
            LuaState luaStateNewLuaState = LuaStateFactory.newLuaState();
            luaStateNewLuaState.openLibs();
            try {
                if (luaStateNewLuaState.LloadBuffer(LuaUtil.readAsset(Welcome.this, "update.lua"), "update") == 0 && luaStateNewLuaState.pcall(0, 0, 0) == 0 && (function = luaStateNewLuaState.getFunction("onUpdate")) != null) {
                    function.call(Welcome.this.h, Welcome.this.i);
                }
            } catch (Exception unused) {
            }
            try {
                unApk("assets", Welcome.this.d);
                unApk("lua", Welcome.this.c);
            } catch (IOException e) {
                b(e.getMessage());
            }
        }

        private void b(String str) {
        }

        @Override // android.os.AsyncTask
        /* renamed from: a, reason: merged with bridge method [inline-methods] */
        protected String doInBackground(String[] strArr) throws InterruptedException {
            a(Welcome.this.e, Welcome.this.f);
            return null;
        }

        @Override // android.os.AsyncTask
        /* renamed from: a, reason: merged with bridge method [inline-methods] */
        protected void onPostExecute(String str) {
            Welcome.this.startActivity();
        }

        /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
        public void unApk(String str, String str2) throws InterruptedException, IOException {
            ArrayList arrayList = new ArrayList();
            ExecutorService executorServiceNewFixedThreadPool = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());
            int length = str.length() + 1;
            this.b = str2;
            this.a = new ZipFile(Welcome.this.getApplicationInfo().publicSourceDir);
            Enumeration<? extends ZipEntry> enumerationEntries = this.a.entries();
            ArrayList arrayList2 = new ArrayList();
            while (enumerationEntries.hasMoreElements()) {
                ZipEntry zipEntryNextElement = enumerationEntries.nextElement();
                String name = zipEntryNextElement.getName();
                if (name.indexOf(str) == 0) {
                    String str3 = str2 + File.separator + name.substring(length);
                    if (zipEntryNextElement.isDirectory()) {
                        File file = new File(str3);
                        if (!file.exists()) {
                            file.mkdirs();
                        }
                    } else {
                        arrayList2.add(zipEntryNextElement);
                        arrayList.add(str3 + File.separator);
                    }
                }
            }
            Iterator it = arrayList2.iterator();
            while (it.hasNext()) {
                ZipEntry zipEntry = (ZipEntry) it.next();
                String strSubstring = zipEntry.getName().substring(length);
                String str4 = str2 + File.separator + strSubstring;
                Iterator it2 = arrayList.iterator();
                boolean z = false;
                while (true) {
                    if (!it2.hasNext()) {
                        break;
                    } else if (str4.startsWith((String) it2.next())) {
                        z = true;
                        break;
                    }
                }
                if (!z) {
                    executorServiceNewFixedThreadPool.execute(new FileWritingTask(zipEntry, strSubstring));
                }
            }
            executorServiceNewFixedThreadPool.shutdown();
            try {
                executorServiceNewFixedThreadPool.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
                this.a.close();
            } catch (InterruptedException e) {
                e.printStackTrace();
                throw new RuntimeException("WelcomeMTUnzip: ExecutorService was interrupted.");
            }
        }
    }

    private void a(String str) {
        if (checkCallingOrSelfPermission(str) != 0) {
            this.j.add(str);
        }
    }

    public boolean checkInfo() throws PackageManager.NameNotFoundException {
        try {
            PackageInfo packageInfo = getPackageManager().getPackageInfo(getPackageName(), 0);
            long j = packageInfo.lastUpdateTime;
            String str = packageInfo.versionName;
            SharedPreferences sharedPreferences = getSharedPreferences("appInfo", 0);
            String string = sharedPreferences.getString("versionName", BuildConfig.FLAVOR);
            if (!str.equals(string)) {
                SharedPreferences.Editor editorEdit = sharedPreferences.edit();
                editorEdit.putString("versionName", str);
                editorEdit.apply();
                this.g = true;
                this.h = str;
                this.i = string;
            }
            long j2 = sharedPreferences.getLong("lastUpdateTime", 0L);
            if (j2 != j) {
                SharedPreferences.Editor editorEdit2 = sharedPreferences.edit();
                editorEdit2.putLong("lastUpdateTime", j);
                editorEdit2.apply();
                this.a = true;
                this.e = j;
                this.f = j2;
                return true;
            }
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        File file = new File(this.b.getLuaPath("main.lua"));
        return (file.exists() && file.isFile()) ? false : true;
    }

    @Override // android.app.Activity
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        TextView textView = new TextView(this);
        textView.setText("Powered by AndoLua+");
        textView.setTextColor(-7829368);
        textView.setGravity(48);
        setContentView(textView);
        this.b = (LuaApplication) getApplication();
        LuaApplication luaApplication = this.b;
        this.c = luaApplication.f;
        this.d = luaApplication.c;
        try {
            if (new File(luaApplication.getLuaPath("setup.png")).exists()) {
                getWindow().setBackgroundDrawable(new LuaBitmapDrawable(this.b, this.b.getLuaPath("setup.png"), getResources().getDrawable(R.drawable.welcome)));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        if (!checkInfo()) {
            startActivity();
            return;
        }
        if (Build.VERSION.SDK_INT >= 23) {
            LuaState luaStateNewLuaState = LuaStateFactory.newLuaState();
            luaStateNewLuaState.openLibs();
            try {
                if (luaStateNewLuaState.LloadBuffer(LuaUtil.readAsset(this, "init.lua"), "init") == 0 && luaStateNewLuaState.pcall(0, 0, 0) == 0 && luaStateNewLuaState.getGlobal("check_permissions") == 1 && luaStateNewLuaState.toBoolean(-1)) {
                    new UpdateTask().execute(new String[0]);
                    return;
                }
            } catch (Exception unused) {
            }
            try {
                this.j = new ArrayList<>();
                for (String str : getPackageManager().getPackageInfo(getPackageName(), 4096).requestedPermissions) {
                    try {
                        a(str);
                    } catch (Exception e2) {
                        e2.printStackTrace();
                    }
                }
                if (!this.j.isEmpty()) {
                    String[] strArr = new String[this.j.size()];
                    this.j.toArray(strArr);
                    requestPermissions(strArr, 0);
                    return;
                }
            } catch (Exception e3) {
                e3.printStackTrace();
            }
        }
        new UpdateTask().execute(new String[0]);
    }

    @Override // android.app.Activity
    public void onRequestPermissionsResult(int i, String[] strArr, int[] iArr) {
        super.onRequestPermissionsResult(i, strArr, iArr);
        new UpdateTask().execute(new String[0]);
    }

    public void startActivity() {
        Intent intent = new Intent(this, (Class<?>) Main.class);
        boolean z = this.g;
        if (z) {
            intent.putExtra("isVersionChanged", z);
            intent.putExtra("newVersionName", this.h);
            intent.putExtra("oldVersionName", this.i);
        }
        startActivity(intent);
        finish();
    }
}