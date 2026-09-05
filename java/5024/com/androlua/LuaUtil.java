package com.androlua;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.BitmapDrawable;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Display;
import android.view.WindowManager;
import com.luajava.LuaFunction;
import com.luajava.LuaString;
import dalvik.system.DexFile;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Array;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.zip.Adler32;
import java.util.zip.CheckedOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaUtil {
    private static final byte[] a = new byte[8192];
    public static final HashMap<String, String> mFileTypes = new HashMap<>();

    static {
        mFileTypes.put("FFD8FF", "jpg");
        mFileTypes.put("89504E47", "png");
        mFileTypes.put("47494638", "gif");
        mFileTypes.put("49492A00", "tif");
        mFileTypes.put("424D", "bmp");
        mFileTypes.put("41433130", "dwg");
        mFileTypes.put("38425053", "psd");
        mFileTypes.put("7B5C727466", "rtf");
        mFileTypes.put("3C3F786D6C", "xml");
        mFileTypes.put("68746D6C3E", "html");
        mFileTypes.put("44656C69766572792D646174653A", "eml");
        mFileTypes.put("D0CF11E0", "doc");
        mFileTypes.put("5374616E64617264204A", "mdb");
        mFileTypes.put("252150532D41646F6265", "ps");
        mFileTypes.put("255044462D312E", "pdf");
        mFileTypes.put("504B0304", "docx");
        mFileTypes.put("52617221", "rar");
        mFileTypes.put("57415645", "wav");
        mFileTypes.put("41564920", "avi");
        mFileTypes.put("2E524D46", "rm");
        mFileTypes.put("000001BA", "mpg");
        mFileTypes.put("000001B3", "mpg");
        mFileTypes.put("6D6F6F76", "mov");
        mFileTypes.put("3026B2758E66CF11", "asf");
        mFileTypes.put("4D546864", "mid");
        mFileTypes.put("1F8B08", "gz");
    }

    private static int a(int i, int i2, int i3) {
        if (i >= i2) {
            i = i2;
        }
        return i < i3 ? i : i3;
    }

    private static int a(String str, String str2) {
        int length = str.length();
        int length2 = str2.length();
        if (length == 0) {
            return length2;
        }
        if (length2 == 0) {
            return length;
        }
        int[][] iArr = (int[][]) Array.newInstance((Class<?>) int.class, length + 1, length2 + 1);
        for (int i = 0; i <= length; i++) {
            iArr[i][0] = i;
        }
        for (int i2 = 0; i2 <= length2; i2++) {
            iArr[0][i2] = i2;
        }
        for (int i3 = 1; i3 <= length; i3++) {
            int i4 = i3 - 1;
            char cCharAt = str.charAt(i4);
            for (int i5 = 1; i5 <= length2; i5++) {
                int i6 = i5 - 1;
                char cCharAt2 = str2.charAt(i6);
                iArr[i3][i5] = a(iArr[i4][i5] + 1, iArr[i3][i6] + 1, iArr[i4][i6] + ((cCharAt == cCharAt2 || cCharAt == cCharAt2 + ' ' || cCharAt + ' ' == cCharAt2) ? 0 : 1));
            }
        }
        return iArr[length][length2];
    }

    private static String a(byte[] bArr) {
        StringBuilder sb = new StringBuilder();
        if (bArr == null || bArr.length <= 0) {
            return null;
        }
        for (byte b : bArr) {
            String upperCase = Integer.toHexString(b & 255).toUpperCase();
            if (upperCase.length() < 2) {
                sb.append(0);
            }
            sb.append(upperCase);
        }
        return sb.toString();
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:32:0x006c -> B:53:0x00b7). Please report as a decompilation issue!!! */
    private static void a(File file, ZipOutputStream zipOutputStream, String str) throws Throwable {
        File[] fileArrListFiles;
        BufferedInputStream bufferedInputStream;
        if (!file.isFile()) {
            if (!file.isDirectory() || (fileArrListFiles = file.listFiles()) == null || fileArrListFiles.length <= 0) {
                return;
            }
            for (File file2 : fileArrListFiles) {
                if (file2.isFile()) {
                    a(file2, zipOutputStream, str);
                } else {
                    a(file2, zipOutputStream, str + file2.getName() + "/");
                }
            }
            return;
        }
        BufferedInputStream bufferedInputStream2 = null;
        BufferedInputStream bufferedInputStream3 = null;
        BufferedInputStream bufferedInputStream4 = null;
        bufferedInputStream2 = null;
        try {
        } catch (IOException e) {
            e.printStackTrace();
            bufferedInputStream2 = bufferedInputStream2;
        }
        try {
            try {
                bufferedInputStream = new BufferedInputStream(new FileInputStream(file), a.length);
                try {
                    StringBuilder sb = new StringBuilder();
                    sb.append(str);
                    sb.append(file.getName());
                    String string = sb.toString();
                    System.out.println(string);
                    zipOutputStream.putNextEntry(new ZipEntry(string));
                    while (true) {
                        int i = bufferedInputStream.read(a, 0, a.length);
                        if (i == -1) {
                            break;
                        } else {
                            zipOutputStream.write(a, 0, i);
                        }
                    }
                    bufferedInputStream.close();
                    bufferedInputStream2 = sb;
                } catch (FileNotFoundException e2) {
                    e = e2;
                    bufferedInputStream3 = bufferedInputStream;
                    e.printStackTrace();
                    bufferedInputStream2 = bufferedInputStream3;
                    if (bufferedInputStream3 != null) {
                        bufferedInputStream3.close();
                        bufferedInputStream2 = bufferedInputStream3;
                    }
                } catch (IOException e3) {
                    e = e3;
                    bufferedInputStream4 = bufferedInputStream;
                    e.printStackTrace();
                    bufferedInputStream2 = bufferedInputStream4;
                    if (bufferedInputStream4 != null) {
                        bufferedInputStream4.close();
                        bufferedInputStream2 = bufferedInputStream4;
                    }
                } catch (Throwable th) {
                    th = th;
                    if (bufferedInputStream != null) {
                        try {
                            bufferedInputStream.close();
                        } catch (IOException e4) {
                            e4.printStackTrace();
                        }
                    }
                    throw th;
                }
            } catch (FileNotFoundException e5) {
                e = e5;
            } catch (IOException e6) {
                e = e6;
            }
        } catch (Throwable th2) {
            th = th2;
            bufferedInputStream = bufferedInputStream2;
        }
    }

    private boolean a(int i, int i2, int[][] iArr, int i3, int i4) {
        for (int i5 = 0; i5 < i3; i5++) {
            int i6 = i2 + i5;
            if (iArr[i][i6] != 1 || iArr[i + i4][i6] != 0) {
                return false;
            }
        }
        return true;
    }

    public static void assetsToSD(Context context, String str, String str2) throws IOException {
        FileOutputStream fileOutputStream = new FileOutputStream(str2);
        InputStream inputStreamOpen = context.getAssets().open(str);
        byte[] bArr = new byte[8192];
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

    public static Bitmap captureScreen(Activity activity) throws IOException {
        DisplayMetrics displayMetrics = new DisplayMetrics();
        Display defaultDisplay = ((WindowManager) activity.getSystemService("window")).getDefaultDisplay();
        defaultDisplay.getMetrics(displayMetrics);
        int i = displayMetrics.heightPixels;
        int i2 = displayMetrics.widthPixels;
        int pixelFormat = defaultDisplay.getPixelFormat();
        PixelFormat pixelFormat2 = new PixelFormat();
        PixelFormat.getPixelFormatInfo(pixelFormat, pixelFormat2);
        int i3 = pixelFormat2.bytesPerPixel;
        int i4 = i * i2;
        byte[] bArr = new byte[i3 * i4];
        try {
            Runtime.getRuntime().exec(new String[]{"/system/bin/su", "-c", "chmod 777 /dev/graphics/fb0"});
        } catch (IOException e) {
            e.printStackTrace();
        }
        try {
            new DataInputStream(new FileInputStream(new File("/dev/graphics/fb0"))).readFully(bArr);
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        int[] iArr = new int[i4];
        for (int i5 = 0; i5 < iArr.length; i5++) {
            int i6 = i5 * 4;
            iArr[i5] = ((bArr[i6 + 3] & 255) << 24) + ((bArr[i6] & 255) << 16) + ((bArr[i6 + 1] & 255) << 8) + (bArr[i6 + 2] & 255);
        }
        return Bitmap.createBitmap(iArr, i2, i, Bitmap.Config.ARGB_8888);
    }

    public static boolean copyDir(File file, File file2) throws IOException {
        File parentFile = file2.getParentFile();
        if (!parentFile.exists()) {
            parentFile.mkdirs();
        }
        if (!file.isDirectory()) {
            try {
                if (!file2.exists()) {
                    file2.createNewFile();
                }
                return copyFile(new FileInputStream(file), new FileOutputStream(file2));
            } catch (IOException e) {
                Log.i("lua", e.getMessage());
                return false;
            }
        }
        File[] fileArrListFiles = file.listFiles();
        boolean zCopyDir = true;
        if (fileArrListFiles == null || fileArrListFiles.length == 0) {
            if (file2.exists()) {
                return true;
            }
            return file2.mkdirs();
        }
        for (File file3 : fileArrListFiles) {
            zCopyDir = copyDir(file3, new File(file2, file3.getName()));
        }
        return zCopyDir;
    }

    public static boolean copyDir(String str, String str2) {
        return copyDir(new File(str), new File(str2));
    }

    public static void copyFile(String str, String str2) {
        try {
            copyFile(new FileInputStream(str), new FileOutputStream(str2));
        } catch (IOException e) {
            Log.i("lua", e.getMessage());
        }
    }

    public static boolean copyFile(InputStream inputStream, OutputStream outputStream) throws IOException {
        try {
            byte[] bArr = new byte[8192];
            while (true) {
                int i = inputStream.read(bArr);
                if (i == -1) {
                    return true;
                }
                outputStream.write(bArr, 0, i);
            }
        } catch (Exception e) {
            Log.i("lua", e.getMessage());
            return false;
        }
    }

    public static Object dump(LuaFunction luaFunction) throws IOException {
        try {
            byte[] bArrDump = luaFunction.dump();
            int iSqrt = (int) Math.sqrt(bArrDump.length);
            int i = iSqrt + 1;
            int[] iArr = new int[iSqrt * i];
            int length = bArrDump.length / 4;
            for (int i2 = 0; i2 < length; i2++) {
                int i3 = i2 * 4;
                iArr[i2] = Color.argb((int) bArrDump[i3], (int) bArrDump[i3 + 1], (int) bArrDump[i3 + 2], (int) bArrDump[i3 + 3]);
            }
            Bitmap bitmapCreateBitmap = Bitmap.createBitmap(iArr, iSqrt, i, Bitmap.Config.ARGB_8888);
            FileOutputStream fileOutputStream = new FileOutputStream("/sdcard/a.png");
            bitmapCreateBitmap.compress(Bitmap.CompressFormat.PNG, 100, fileOutputStream);
            fileOutputStream.close();
            return bitmapCreateBitmap;
        } catch (Exception e) {
            e.printStackTrace();
            return e;
        }
    }

    public static String[] getAllName(Context context, String str) {
        ArrayList arrayList = new ArrayList();
        try {
            Enumeration<String> enumerationEntries = new DexFile(context.getPackageCodePath()).entries();
            while (enumerationEntries.hasMoreElements()) {
                arrayList.add(enumerationEntries.nextElement());
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        try {
            Enumeration<? extends ZipEntry> enumerationEntries2 = new ZipFile(str).entries();
            while (enumerationEntries2.hasMoreElements()) {
                arrayList.add(enumerationEntries2.nextElement().getName().replaceAll("/", ".").replace(".class", BuildConfig.FLAVOR));
            }
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        String[] strArr = new String[arrayList.size()];
        arrayList.toArray(strArr);
        return strArr;
    }

    public static String getFileHeader(InputStream inputStream) throws IOException {
        try {
            byte[] bArr = new byte[4];
            inputStream.read(bArr, 0, bArr.length);
            String strA = a(bArr);
            if (inputStream == null) {
                return strA;
            }
            try {
                inputStream.close();
                return strA;
            } catch (IOException unused) {
                return strA;
            }
        } catch (Exception unused2) {
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException unused3) {
                }
            }
            return null;
        } catch (Throwable th) {
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException unused4) {
                }
            }
            throw th;
        }
    }

    public static String getFileMD5(File file) {
        try {
            return getFileMD5(new FileInputStream(file));
        } catch (FileNotFoundException unused) {
            return null;
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public static String getFileMD5(InputStream inputStream) throws IOException {
        byte[] bArr = new byte[8192];
        try {
            try {
                MessageDigest messageDigest = MessageDigest.getInstance("MD5");
                while (true) {
                    int i = inputStream.read(bArr);
                    if (i == -1) {
                        break;
                    }
                    messageDigest.update(bArr, 0, i);
                }
                StringBuilder sb = new StringBuilder();
                for (byte b : messageDigest.digest()) {
                    sb.append(String.format("%02x", Integer.valueOf(b & 255)));
                }
                return sb.toString();
            } catch (Exception e) {
                e.printStackTrace();
                try {
                    inputStream.close();
                } catch (Exception e2) {
                    e2.printStackTrace();
                }
                return null;
            }
        } finally {
            try {
                inputStream.close();
            } catch (Exception e3) {
                e3.printStackTrace();
            }
        }
    }

    public static String getFileMD5(String str) {
        return getFileMD5(new File(str));
    }

    public static String getFileSha1(File file) {
        try {
            return getFileSha1(new FileInputStream(file));
        } catch (FileNotFoundException unused) {
            return null;
        }
    }

    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    public static String getFileSha1(InputStream inputStream) throws IOException {
        byte[] bArr = new byte[8192];
        try {
            try {
                MessageDigest messageDigest = MessageDigest.getInstance("SHA-1");
                while (true) {
                    int i = inputStream.read(bArr);
                    if (i == -1) {
                        break;
                    }
                    messageDigest.update(bArr, 0, i);
                }
                StringBuilder sb = new StringBuilder();
                for (byte b : messageDigest.digest()) {
                    sb.append(String.format("%02x", Integer.valueOf(b & 255)));
                }
                return sb.toString();
            } catch (Exception e) {
                e.printStackTrace();
                try {
                    inputStream.close();
                } catch (Exception e2) {
                    e2.printStackTrace();
                }
                return null;
            }
        } finally {
            try {
                inputStream.close();
            } catch (Exception e3) {
                e3.printStackTrace();
            }
        }
    }

    public static String getFileSha1(String str) {
        return getFileMD5(new File(str));
    }

    public static String getFileType(File file) {
        try {
            return mFileTypes.get(getFileHeader(new FileInputStream(file)));
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            return "unknown";
        }
    }

    public static String getFileType(InputStream inputStream) {
        return mFileTypes.get(getFileHeader(inputStream));
    }

    public static String getFileType(String str) {
        try {
            return mFileTypes.get(getFileHeader(new FileInputStream(str)));
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            return "unknown";
        }
    }

    public static String getMD5(String str) throws NoSuchAlgorithmException {
        byte[] bytes = str.getBytes();
        int length = bytes.length;
        try {
            MessageDigest messageDigest = MessageDigest.getInstance("MD5");
            messageDigest.update(bytes, 0, length);
            byte[] bArrDigest = messageDigest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : bArrDigest) {
                sb.append(String.format("%02x", Integer.valueOf(b & 255)));
            }
            return sb.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public static String getMessageDigest(String str, String str2) throws NoSuchAlgorithmException {
        byte[] bytes = str.getBytes();
        int length = bytes.length;
        try {
            MessageDigest messageDigest = MessageDigest.getInstance(str2);
            messageDigest.update(bytes, 0, length);
            byte[] bArrDigest = messageDigest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : bArrDigest) {
                sb.append(String.format("%02x", Integer.valueOf(b & 255)));
            }
            return sb.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public static String getSha1(String str) throws NoSuchAlgorithmException {
        byte[] bytes = str.getBytes();
        int length = bytes.length;
        try {
            MessageDigest messageDigest = MessageDigest.getInstance("SHA-1");
            messageDigest.update(bytes, 0, length);
            byte[] bArrDigest = messageDigest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : bArrDigest) {
                sb.append(String.format("%02x", Integer.valueOf(b & 255)));
            }
            return sb.toString();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public static float getSimilarityRatio(String str, String str2) {
        return 1.0f - (a(str, str2) / Math.max(str.length(), str2.length()));
    }

    public static byte[] readAll(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(8192);
        byte[] bArr = new byte[8192];
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

    public static LuaString readApkFile(String str) {
        ZipFile zipFile = new ZipFile(LuaApplication.getInstance().getPackageCodePath());
        return new LuaString(readAll(zipFile.getInputStream(zipFile.getEntry(str))));
    }

    public static byte[] readAsset(Context context, String str) throws IOException {
        InputStream inputStreamOpen = context.getAssets().open(str);
        byte[] all = readAll(inputStreamOpen);
        inputStreamOpen.close();
        return all;
    }

    public static byte[] readZip(String str, String str2) {
        ZipFile zipFile = new ZipFile(str);
        return readAll(zipFile.getInputStream(zipFile.getEntry(str2)));
    }

    public static LuaString readZipFile(String str, String str2) {
        ZipFile zipFile = new ZipFile(str);
        return new LuaString(readAll(zipFile.getInputStream(zipFile.getEntry(str2))));
    }

    public static void rmDir(File file, String str) {
        if (file.isDirectory()) {
            for (File file2 : file.listFiles()) {
                rmDir(file2, str);
            }
            file.delete();
        }
        if (file.getName().endsWith(str)) {
            file.delete();
        }
    }

    public static boolean rmDir(File file) {
        if (file.isDirectory()) {
            for (File file2 : file.listFiles()) {
                rmDir(file2);
            }
        }
        return file.delete();
    }

    public static void unZip(String str) throws IOException {
        unZip(str, new File(str).getParent(), BuildConfig.FLAVOR);
    }

    public static void unZip(String str, String str2) throws IOException {
        unZip(str, str2, BuildConfig.FLAVOR);
    }

    public static void unZip(String str, String str2, String str3) throws IOException {
        ZipFile zipFile = new ZipFile(str);
        Enumeration<? extends ZipEntry> enumerationEntries = zipFile.entries();
        while (enumerationEntries.hasMoreElements()) {
            ZipEntry zipEntryNextElement = enumerationEntries.nextElement();
            String name = zipEntryNextElement.getName();
            if (name.startsWith(str3)) {
                if (zipEntryNextElement.isDirectory()) {
                    File file = new File(str2 + File.separator + name);
                    if (!file.exists()) {
                        file.mkdirs();
                    }
                } else {
                    File parentFile = new File(str2 + File.separator + name).getParentFile();
                    if (!parentFile.exists() && !parentFile.mkdirs()) {
                        throw new RuntimeException("create file " + parentFile.getName() + " fail");
                    }
                    FileOutputStream fileOutputStream = new FileOutputStream(str2 + File.separator + name);
                    InputStream inputStream = zipFile.getInputStream(zipEntryNextElement);
                    byte[] bArr = new byte[8192];
                    while (true) {
                        int i = inputStream.read(bArr);
                        if (i == -1) {
                            break;
                        } else {
                            fileOutputStream.write(bArr, 0, i);
                        }
                    }
                    fileOutputStream.close();
                    inputStream.close();
                }
            }
        }
        zipFile.close();
    }

    public static void unZip(String str, boolean z) throws IOException {
        if (!z) {
            unZip(str);
            return;
        }
        String name = new File(str).getName();
        int iLastIndexOf = name.lastIndexOf(".");
        if (iLastIndexOf > 0) {
            name = name.substring(0, iLastIndexOf);
        }
        int iIndexOf = name.indexOf("_");
        if (iIndexOf > 0) {
            name = name.substring(0, iIndexOf);
        }
        int iIndexOf2 = name.indexOf("(");
        if (iIndexOf2 > 0) {
            name = name.substring(0, iIndexOf2);
        }
        unZip(str, new File(str).getParent() + File.separator + name, BuildConfig.FLAVOR);
    }

    public static boolean zip(String str) {
        return zip(str, new File(str).getParent());
    }

    public static boolean zip(String str, String str2) {
        return zip(str, str2, new File(str).getName() + ".zip");
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Type inference failed for: r4v13, types: [java.lang.String] */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:23:0x005f -> B:57:0x007c). Please report as a decompilation issue!!! */
    public static boolean zip(String str, String str2, String str3) throws Throwable {
        File file = new File(str);
        File file2 = new File(str2, str3);
        boolean z = false;
        if (!file2.getParentFile().exists() && !file2.getParentFile().mkdirs()) {
            return false;
        }
        if (file2.exists()) {
            try {
                file2.createNewFile();
            } catch (IOException unused) {
                return false;
            }
        }
        ZipOutputStream zipOutputStream = null;
        ZipOutputStream zipOutputStream2 = null;
        zipOutputStream = null;
        try {
        } catch (IOException e) {
            e.printStackTrace();
            zipOutputStream = zipOutputStream;
        }
        try {
            try {
                CheckedOutputStream checkedOutputStream = new CheckedOutputStream(new FileOutputStream(file2), new Adler32());
                ZipOutputStream zipOutputStream3 = new ZipOutputStream(new BufferedOutputStream(checkedOutputStream));
                try {
                    ?? r4 = BuildConfig.FLAVOR;
                    a(file, zipOutputStream3, BuildConfig.FLAVOR);
                    checkedOutputStream.getChecksum().getValue();
                    z = true;
                    try {
                        zipOutputStream3.closeEntry();
                    } catch (IOException e2) {
                        e2.printStackTrace();
                    }
                    zipOutputStream3.close();
                    zipOutputStream = r4;
                } catch (FileNotFoundException e3) {
                    e = e3;
                    zipOutputStream2 = zipOutputStream3;
                    e.printStackTrace();
                    zipOutputStream = zipOutputStream2;
                    if (zipOutputStream2 != null) {
                        try {
                            zipOutputStream2.closeEntry();
                        } catch (IOException e4) {
                            e4.printStackTrace();
                        }
                        zipOutputStream2.close();
                        zipOutputStream = zipOutputStream2;
                    }
                    return z;
                } catch (Throwable th) {
                    th = th;
                    zipOutputStream = zipOutputStream3;
                    if (zipOutputStream != null) {
                        try {
                            zipOutputStream.closeEntry();
                        } catch (IOException e5) {
                            e5.printStackTrace();
                        }
                        try {
                            zipOutputStream.close();
                        } catch (IOException e6) {
                            e6.printStackTrace();
                        }
                    }
                    throw th;
                }
            } catch (FileNotFoundException e7) {
                e = e7;
            }
            return z;
        } catch (Throwable th2) {
            th = th2;
        }
    }

    public int checkPixel(int i, int i2, int[][] iArr) {
        int i3 = iArr[i][i2];
        if (i2 + 30 < iArr[i].length) {
            int i4 = 0;
            for (int i5 = 1; i5 <= 30; i5++) {
                if (iArr[i][i2 + i5] == 0) {
                    i4++;
                }
            }
            if (i4 > 15) {
                return 0;
            }
        }
        return i3;
    }

    public int getDifferenceValue(String str, String str2) {
        new File(str);
        new File(str2);
        try {
            Bitmap bitmapDecodeFile = BitmapFactory.decodeFile(str);
            Bitmap bitmapDecodeFile2 = BitmapFactory.decodeFile(str2);
            int width = bitmapDecodeFile.getWidth();
            int height = bitmapDecodeFile.getHeight();
            int[][] iArr = (int[][]) Array.newInstance((Class<?>) int.class, width, height);
            for (int i = 1; i < width; i++) {
                for (int i2 = 1; i2 < height; i2++) {
                    if (bitmapDecodeFile.getPixel(i, i2) == bitmapDecodeFile2.getPixel(i, i2)) {
                        iArr[i - 1][i2 - 1] = 0;
                    } else {
                        iArr[i - 1][i2 - 1] = 1;
                    }
                }
            }
            int i3 = -1;
            int i4 = 0;
            int i5 = 999;
            while (i4 < iArr.length) {
                int i6 = i3;
                for (int i7 = 0; i7 < iArr[i4].length; i7++) {
                    if (iArr[i4][i7] == 1) {
                        iArr[i4][i7] = checkPixel(i4, i7, iArr);
                        if (iArr[i4][i7] == 1) {
                            if (i4 > i6) {
                                i6 = i4;
                            } else if (i4 < i5) {
                                i5 = i4;
                            }
                        }
                    }
                }
                i4++;
                i3 = i6;
            }
            return (i3 + i5) / 2;
        } catch (Exception e) {
            e.printStackTrace();
            return 0;
        }
    }

    public BitmapDrawable toBlack(String str, float f, int i, int i2) {
        Bitmap bitmapDecodeFile = BitmapFactory.decodeFile(str);
        int width = bitmapDecodeFile.getWidth();
        int height = bitmapDecodeFile.getHeight();
        Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
        int i3 = width * height;
        int[] iArr = new int[i3];
        float[] fArr = new float[i3];
        float[] fArr2 = new float[3];
        int i4 = 0;
        float f2 = 0.0f;
        while (i4 < height) {
            float f3 = f2;
            for (int i5 = 0; i5 < width; i5++) {
                Color.colorToHSV(bitmapDecodeFile.getPixel(i5, i4), fArr2);
                fArr[(width * i4) + i5] = fArr2[2];
                f3 += fArr2[2];
            }
            i4++;
            f2 = f3;
        }
        float f4 = (f2 / i3) * f;
        int[][] iArr2 = (int[][]) Array.newInstance((Class<?>) int.class, width, height);
        for (int i6 = 0; i6 < height; i6++) {
            for (int i7 = 0; i7 < width; i7++) {
                int i8 = (width * i6) + i7;
                if (fArr[i8] > f4) {
                    iArr[i8] = -1;
                    iArr2[i7][i6] = 1;
                } else {
                    iArr[i8] = -16777216;
                    iArr2[i7][i6] = 0;
                }
            }
        }
        for (int i9 = width / 2; i9 < width - 10; i9++) {
            int i10 = width / 3;
            while (true) {
                if (i10 >= width) {
                    break;
                }
                if (a(i9, i10, iArr2, i, i2)) {
                    Log.i("find_color", i9 + BuildConfig.FLAVOR);
                    break;
                }
                i10++;
            }
        }
        return new BitmapDrawable(Bitmap.createBitmap(iArr, width, height, Bitmap.Config.RGB_565));
    }
}