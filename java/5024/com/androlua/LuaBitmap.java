package com.androlua;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.ref.WeakReference;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.WeakHashMap;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaBitmap {
    private static HashMap<String, String> c;
    static WeakHashMap<String, WeakReference<Bitmap>> a = new WeakHashMap<>();
    private static long b = 3600000;
    private static String d = new File(LuaApplication.getInstance().getExternalCacheDir(), "images").getAbsolutePath();

    static {
        new File(d).mkdirs();
    }

    private static int a(BitmapFactory.Options options, int i, int i2) {
        int iCeil;
        int iMin;
        double d2 = options.outWidth;
        double d3 = options.outHeight;
        if (i2 == -1) {
            iCeil = 1;
        } else {
            Double.isNaN(d2);
            Double.isNaN(d3);
            double d4 = i2;
            Double.isNaN(d4);
            iCeil = (int) Math.ceil(Math.sqrt((d2 * d3) / d4));
        }
        if (i == -1) {
            iMin = 128;
        } else {
            double d5 = i;
            Double.isNaN(d2);
            Double.isNaN(d5);
            double dFloor = Math.floor(d2 / d5);
            Double.isNaN(d3);
            Double.isNaN(d5);
            iMin = (int) Math.min(dFloor, Math.floor(d3 / d5));
        }
        if (iMin < iCeil) {
            return iCeil;
        }
        if (i2 == -1 && i == -1) {
            return 1;
        }
        return i == -1 ? iCeil : iMin;
    }

    private static int b(BitmapFactory.Options options, int i, int i2) {
        int iA = a(options, i, i2);
        if (iA > 8) {
            return ((iA + 7) / 8) * 8;
        }
        int i3 = 1;
        while (i3 < iA) {
            i3 <<= 1;
        }
        return i3;
    }

    public static boolean checkCache(LuaContext luaContext, String str) {
        File file = new File(new File(d, String.format("%08x", Integer.valueOf(str.hashCode()))).getAbsolutePath());
        return file.exists() && b != -1 && System.currentTimeMillis() - file.lastModified() < b;
    }

    public static Bitmap decodeScale(int i, File file) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        int iPow = 1;
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), options);
        if (options.outHeight > i * 4 || options.outWidth > i) {
            double dMax = Math.max(options.outHeight, options.outWidth);
            Double.isNaN(i);
            Double.isNaN(dMax);
            iPow = (int) Math.pow(2.0d, (int) Math.round(Math.log(r3 / dMax) / Math.log(0.5d)));
        }
        BitmapFactory.Options options2 = new BitmapFactory.Options();
        options2.inSampleSize = iPow;
        return BitmapFactory.decodeFile(file.getAbsolutePath(), options2);
    }

    public static Bitmap getAssetBitmap(Context context, String str) throws IOException {
        InputStream inputStreamOpen = context.getAssets().open(str);
        Bitmap bitmapDecodeStream = BitmapFactory.decodeStream(inputStreamOpen);
        inputStreamOpen.close();
        return bitmapDecodeStream;
    }

    public static Bitmap getBitmap(LuaContext luaContext, String str) throws IOException {
        Bitmap httpBitmap;
        Bitmap bitmap;
        WeakReference<Bitmap> weakReference = a.get(str);
        if (weakReference != null && (bitmap = weakReference.get()) != null) {
            return bitmap;
        }
        if (str.toLowerCase().startsWith("http://") || str.toLowerCase().startsWith("https://")) {
            httpBitmap = getHttpBitmap(luaContext, str);
        } else if (str.charAt(0) != '/') {
            httpBitmap = getLocalBitmap(luaContext, luaContext.getLuaDir() + "/" + str);
        } else {
            httpBitmap = getLocalBitmap(luaContext, str);
        }
        a.put(str, new WeakReference<>(httpBitmap));
        return httpBitmap;
    }

    public static Bitmap getBitmapFromFile(File file, int i, int i2) {
        BitmapFactory.Options options;
        if (file != null && file.exists()) {
            if (i <= 0 || i2 <= 0) {
                options = null;
            } else {
                options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                BitmapFactory.decodeFile(file.getPath(), options);
                options.inSampleSize = b(options, Math.min(i, i2), i * i2);
                options.inJustDecodeBounds = false;
                options.inInputShareable = true;
                options.inPurgeable = true;
            }
            try {
                return BitmapFactory.decodeFile(file.getPath(), options);
            } catch (OutOfMemoryError e) {
                e.printStackTrace();
            }
        }
        return null;
    }

    public static long getCacheTime() {
        return b;
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public static Bitmap getHttpBitmap(LuaContext luaContext, String str) throws IOException {
        int width;
        File file;
        String absolutePath = new File(d, String.format("%08x", Integer.valueOf(str.hashCode()))).getAbsolutePath();
        File file2 = new File(absolutePath);
        file2.getParentFile().mkdirs();
        if (!file2.exists() || b == -1 || System.currentTimeMillis() - file2.lastModified() >= b) {
            new File(absolutePath).delete();
            HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(str).openConnection();
            httpURLConnection.setConnectTimeout(120000);
            httpURLConnection.setDoInput(true);
            HashMap<String, String> map = c;
            if (map != null) {
                for (Map.Entry<String, String> entry : map.entrySet()) {
                    httpURLConnection.setRequestProperty(entry.getKey(), entry.getValue());
                }
            }
            httpURLConnection.connect();
            InputStream inputStream = httpURLConnection.getInputStream();
            FileOutputStream fileOutputStream = new FileOutputStream(absolutePath);
            if (!LuaUtil.copyFile(inputStream, fileOutputStream)) {
                fileOutputStream.close();
                inputStream.close();
                new File(absolutePath).delete();
                throw new RuntimeException("LoadHttpBitmap Error.");
            }
            fileOutputStream.close();
            inputStream.close();
            width = luaContext.getWidth();
            file = new File(absolutePath);
        } else {
            width = luaContext.getWidth();
            file = new File(absolutePath);
        }
        return decodeScale(width, file);
    }

    public static Bitmap getHttpBitmap(String str) throws IOException {
        HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(str).openConnection();
        httpURLConnection.setDoInput(true);
        httpURLConnection.connect();
        InputStream inputStream = httpURLConnection.getInputStream();
        Bitmap bitmapDecodeStream = BitmapFactory.decodeStream(inputStream);
        inputStream.close();
        return bitmapDecodeStream;
    }

    public static Bitmap getImageFromPath(String str) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(str, options);
        options.inSampleSize = b(options, -1, 62500);
        options.inJustDecodeBounds = false;
        try {
            return BitmapFactory.decodeFile(str, options);
        } catch (Exception unused) {
            return null;
        }
    }

    public static Bitmap getLocalBitmap(LuaContext luaContext, String str) {
        return decodeScale(luaContext.getWidth(), new File(str));
    }

    public static Bitmap getLocalBitmap(String str) throws IOException {
        FileInputStream fileInputStream = new FileInputStream(str);
        Bitmap bitmapDecodeStream = BitmapFactory.decodeStream(fileInputStream);
        fileInputStream.close();
        return bitmapDecodeStream;
    }

    public static void removeBitmap(Bitmap bitmap) {
        for (Map.Entry<String, WeakReference<Bitmap>> entry : a.entrySet()) {
            if (bitmap.equals(entry.getValue().get())) {
                a.remove(entry.getKey());
                return;
            }
        }
    }

    public static void setCacheTime(long j) {
        b = j;
    }

    public static void setCookie(String str) {
        if (c == null) {
            c = new HashMap<>();
        }
        c.put("Cookie", str);
    }

    public static void setHeader(HashMap<String, String> map) {
        c = map;
    }

    public static void setReferer(String str) {
        if (c == null) {
            c = new HashMap<>();
        }
        c.put("Referer", str);
    }

    public static void setUserAgent(String str) {
        if (c == null) {
            c = new HashMap<>();
        }
        c.put("User-Agent", str);
    }
}