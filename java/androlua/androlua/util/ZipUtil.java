package com.androlua.util;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Enumeration;
import java.util.logging.Logger;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class ZipUtil {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static final Logger f986a = Logger.getLogger(ZipUtil.class.getName());

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private static final byte[] f987b = new byte[4096];

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Type inference failed for: r0v10 */
    /* JADX WARN: Type inference failed for: r0v11 */
    /* JADX WARN: Type inference failed for: r0v13 */
    /* JADX WARN: Type inference failed for: r0v14 */
    /* JADX WARN: Type inference failed for: r0v15 */
    /* JADX WARN: Type inference failed for: r0v16 */
    /* JADX WARN: Type inference failed for: r0v17 */
    /* JADX WARN: Type inference failed for: r0v18 */
    /* JADX WARN: Type inference failed for: r0v19 */
    /* JADX WARN: Type inference failed for: r0v20 */
    /* JADX WARN: Type inference failed for: r0v21 */
    /* JADX WARN: Type inference failed for: r0v4 */
    /* JADX WARN: Type inference failed for: r0v5 */
    /* JADX WARN: Type inference failed for: r0v6 */
    /* JADX WARN: Type inference failed for: r0v7 */
    /* JADX WARN: Type inference failed for: r0v8, types: [java.io.BufferedInputStream] */
    /* JADX WARN: Type inference failed for: r0v9, types: [java.io.BufferedInputStream] */
    /* JADX WARN: Type inference failed for: r3v0 */
    /* JADX WARN: Type inference failed for: r3v1, types: [java.io.BufferedInputStream] */
    /* JADX WARN: Type inference failed for: r3v2, types: [java.io.BufferedInputStream] */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:32:0x0068 -> B:49:0x0091). Please report as a decompilation issue!!! */
    private static void a(File file, ZipOutputStream zipOutputStream, String str) throws Throwable {
        File[] fileArrListFiles;
        ?? bufferedInputStream;
        if (!file.isFile()) {
            if (!file.isDirectory() || (fileArrListFiles = file.listFiles()) == null || fileArrListFiles.length <= 0) {
                return;
            }
            for (File file2 : fileArrListFiles) {
                a(file2, zipOutputStream, str);
            }
            return;
        }
        ?? r0 = 0;
        ?? r02 = 0;
        ?? r03 = 0;
        r0 = 0;
        try {
        } catch (IOException e) {
            e.printStackTrace();
            r0 = r0;
        }
        try {
            try {
                bufferedInputStream = new BufferedInputStream(new FileInputStream(file), f987b.length);
                try {
                    String absolutePath = file.getAbsolutePath();
                    String strSubstring = file.getAbsolutePath().substring(absolutePath.indexOf(str));
                    System.out.println(strSubstring);
                    zipOutputStream.putNextEntry(new ZipEntry(strSubstring));
                    while (true) {
                        int i = bufferedInputStream.read(f987b, 0, f987b.length);
                        if (i == -1) {
                            break;
                        } else {
                            zipOutputStream.write(f987b, 0, i);
                        }
                    }
                    bufferedInputStream.close();
                    r0 = absolutePath;
                } catch (FileNotFoundException e2) {
                    e = e2;
                    r02 = bufferedInputStream;
                    e.printStackTrace();
                    r0 = r02;
                    if (r02 != 0) {
                        r02.close();
                        r0 = r02;
                    }
                } catch (IOException e3) {
                    e = e3;
                    r03 = bufferedInputStream;
                    e.printStackTrace();
                    r0 = r03;
                    if (r03 != 0) {
                        r03.close();
                        r0 = r03;
                    }
                } catch (Throwable th) {
                    th = th;
                    if (bufferedInputStream != 0) {
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
            bufferedInputStream = r0;
        }
    }

    public static void append(String str, String str2) throws IOException {
        ZipFile zipFile = new ZipFile(str);
        ZipOutputStream zipOutputStream = new ZipOutputStream(new FileOutputStream(str));
        Enumeration<? extends ZipEntry> enumerationEntries = zipFile.entries();
        while (enumerationEntries.hasMoreElements()) {
            ZipEntry zipEntryNextElement = enumerationEntries.nextElement();
            System.out.println("copy: " + zipEntryNextElement.getName());
            zipOutputStream.putNextEntry(zipEntryNextElement);
            if (!zipEntryNextElement.isDirectory()) {
                copy(zipFile.getInputStream(zipEntryNextElement), zipOutputStream);
            }
            zipOutputStream.closeEntry();
        }
        ZipEntry zipEntry = new ZipEntry(str2);
        System.out.println("append: " + zipEntry.getName());
        zipOutputStream.putNextEntry(zipEntry);
        copy(new FileInputStream(new File(str2)), zipOutputStream);
        zipOutputStream.closeEntry();
        zipFile.close();
        zipOutputStream.close();
    }

    public static void copy(InputStream inputStream, OutputStream outputStream) throws IOException {
        while (true) {
            int i = inputStream.read(f987b);
            if (i == -1) {
                return;
            } else {
                outputStream.write(f987b, 0, i);
            }
        }
    }

    /* JADX WARN: Removed duplicated region for block: B:52:0x0118  */
    /* JADX WARN: Removed duplicated region for block: B:53:0x011d  */
    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static boolean unzip(java.io.File r4, java.lang.String r5) throws java.lang.Throwable {
        /*
            Method dump skipped, instruction units count: 305
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.util.ZipUtil.unzip(java.io.File, java.lang.String):boolean");
    }

    public static boolean unzip(String str, String str2) {
        return unzip(new File(str), str2);
    }

    /* JADX WARN: Removed duplicated region for block: B:46:0x00ee  */
    /* JADX WARN: Removed duplicated region for block: B:47:0x00f3  */
    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:30:0x00cf -> B:71:0x00ec). Please report as a decompilation issue!!! */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static boolean zip(java.lang.String r4, java.lang.String r5) throws java.lang.Throwable {
        /*
            Method dump skipped, instruction units count: 271
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.util.ZipUtil.zip(java.lang.String, java.lang.String):boolean");
    }
}