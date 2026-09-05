package com.androlua;

import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.content.res.Resources;
import com.luajava.LuaException;
import dalvik.system.DexClassLoader;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaDexLoader {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static HashMap<String, LuaDexClassLoader> f774a = new HashMap<>();
    private LuaContext d;
    private String e;
    private AssetManager f;
    private LuaResources g;
    private Resources.Theme h;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private ArrayList<ClassLoader> f775b = new ArrayList<>();

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private HashMap<String, String> f776c = new HashMap<>();
    private String i = LuaApplication.getInstance().getOdexDir();

    public LuaDexLoader(LuaContext luaContext) {
        this.d = luaContext;
        this.e = luaContext.getLuaDir();
    }

    public AssetManager getAssets() {
        return this.f;
    }

    public ArrayList<ClassLoader> getClassLoaders() {
        return this.f775b;
    }

    public HashMap<String, String> getLibrarys() {
        return this.f776c;
    }

    public Resources getResources() {
        return this.g;
    }

    public Resources.Theme getTheme() {
        return this.h;
    }

    public LuaDexClassLoader loadApp(String str) {
        try {
            LuaDexClassLoader luaDexClassLoader = f774a.get(str);
            if (luaDexClassLoader == null) {
                ApplicationInfo applicationInfo = this.d.getContext().getPackageManager().getPackageInfo(str, 0).applicationInfo;
                LuaDexClassLoader luaDexClassLoader2 = new LuaDexClassLoader(applicationInfo.publicSourceDir, LuaApplication.getInstance().getOdexDir(), applicationInfo.nativeLibraryDir, this.d.getContext().getClassLoader());
                f774a.put(str, luaDexClassLoader2);
                luaDexClassLoader = luaDexClassLoader2;
            }
            if (!this.f775b.contains(luaDexClassLoader)) {
                this.f775b.add(luaDexClassLoader);
            }
            return luaDexClassLoader;
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
            return null;
        }
    }

    public DexClassLoader loadDex(String str) throws LuaException {
        LuaDexClassLoader luaDexClassLoader;
        String string;
        StringBuilder sb;
        LuaDexClassLoader luaDexClassLoaderLoadApp = f774a.get(str);
        if (luaDexClassLoaderLoadApp == null) {
            luaDexClassLoaderLoadApp = loadApp(str);
        }
        if (luaDexClassLoaderLoadApp == null) {
            if (str.charAt(0) != '/') {
                string = this.e + "/" + str;
            } else {
                string = str;
            }
            if (!new File(string).exists()) {
                if (new File(string + ".dex").exists()) {
                    sb = new StringBuilder();
                    sb.append(string);
                    sb.append(".dex");
                } else {
                    if (!new File(string + ".jar").exists()) {
                        throw new LuaException(string + " not found");
                    }
                    sb = new StringBuilder();
                    sb.append(string);
                    sb.append(".jar");
                }
                string = sb.toString();
            }
            String fileMD5 = LuaUtil.getFileMD5(string);
            if (fileMD5 == null || !fileMD5.equals("0")) {
                str = fileMD5;
            }
            luaDexClassLoader = f774a.get(str);
            if (luaDexClassLoader == null) {
                luaDexClassLoader = new LuaDexClassLoader(string, this.i, LuaApplication.getInstance().getApplicationInfo().nativeLibraryDir, this.d.getContext().getClassLoader());
                f774a.put(str, luaDexClassLoader);
            }
        } else {
            luaDexClassLoader = luaDexClassLoaderLoadApp;
        }
        if (!this.f775b.contains(luaDexClassLoader)) {
            this.f775b.add(luaDexClassLoader);
            String dexPath = luaDexClassLoader.getDexPath();
            if (dexPath.endsWith(".jar")) {
                loadResources(dexPath);
            }
        }
        return luaDexClassLoader;
    }

    public void loadLib(String str) throws LuaException {
        int iIndexOf = str.indexOf(".");
        String strSubstring = iIndexOf > 0 ? str.substring(0, iIndexOf) : str;
        if (strSubstring.startsWith("lib")) {
            strSubstring = strSubstring.substring(3);
        }
        String str2 = this.d.getContext().getDir(strSubstring, 0).getAbsolutePath() + "/lib" + strSubstring + ".so";
        if (!new File(str2).exists()) {
            if (!new File(this.e + "/libs/lib" + strSubstring + ".so").exists()) {
                throw new LuaException("can not find lib " + str);
            }
            LuaUtil.copyFile(this.e + "/libs/lib" + strSubstring + ".so", str2);
        }
        this.f776c.put(strSubstring, str2);
    }

    public void loadLibs() throws LuaException {
        File[] fileArrListFiles = new File(this.d.getLuaDir() + "/libs").listFiles();
        if (fileArrListFiles == null) {
            return;
        }
        for (File file : fileArrListFiles) {
            if (!file.isDirectory()) {
                if (file.getAbsolutePath().endsWith(".so")) {
                    loadLib(file.getName());
                } else {
                    loadDex(file.getAbsolutePath());
                }
            }
        }
    }

    public void loadResources(String str) {
        try {
            AssetManager assetManager = (AssetManager) AssetManager.class.newInstance();
            if (((Integer) assetManager.getClass().getMethod("addAssetPath", String.class).invoke(assetManager, str)).intValue() == 0) {
                return;
            }
            this.f = assetManager;
            Resources resources = this.d.getContext().getResources();
            this.g = new LuaResources(this.f, resources.getDisplayMetrics(), resources.getConfiguration());
            this.g.setSuperResources(resources);
            this.h = this.g.newTheme();
            this.h.setTo(this.d.getContext().getTheme());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}