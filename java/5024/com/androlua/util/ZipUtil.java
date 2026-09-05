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

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class ZipUtil {
    private static final Logger a = Logger.getLogger(ZipUtil.class.getName());
    private static final byte[] b = new byte[4096];

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:32:0x0068 -> B:49:0x0091). Please report as a decompilation issue!!! */
    private static void a(File file, ZipOutputStream zipOutputStream, String str) throws Throwable {
        File[] fileArrListFiles;
        BufferedInputStream bufferedInputStream;
        if (!file.isFile()) {
            if (!file.isDirectory() || (fileArrListFiles = file.listFiles()) == null || fileArrListFiles.length <= 0) {
                return;
            }
            for (File file2 : fileArrListFiles) {
                a(file2, zipOutputStream, str);
            }
            return;
        }
        String str2 = null;
        BufferedInputStream bufferedInputStream2 = 0;
        BufferedInputStream bufferedInputStream3 = 0;
        str2 = null;
        try {
        } catch (IOException e) {
            e.printStackTrace();
            str2 = str2;
        }
        try {
            try {
                bufferedInputStream = new BufferedInputStream(new FileInputStream(file), b.length);
                try {
                    String absolutePath = file.getAbsolutePath();
                    String strSubstring = file.getAbsolutePath().substring(absolutePath.indexOf(str));
                    System.out.println(strSubstring);
                    zipOutputStream.putNextEntry(new ZipEntry(strSubstring));
                    while (true) {
                        int i = bufferedInputStream.read(b, 0, b.length);
                        if (i == -1) {
                            break;
                        } else {
                            zipOutputStream.write(b, 0, i);
                        }
                    }
                    bufferedInputStream.close();
                    str2 = absolutePath;
                } catch (FileNotFoundException e2) {
                    e = e2;
                    bufferedInputStream2 = bufferedInputStream;
                    e.printStackTrace();
                    str2 = bufferedInputStream2;
                    if (bufferedInputStream2 != 0) {
                        bufferedInputStream2.close();
                        str2 = bufferedInputStream2;
                    }
                } catch (IOException e3) {
                    e = e3;
                    bufferedInputStream3 = bufferedInputStream;
                    e.printStackTrace();
                    str2 = bufferedInputStream3;
                    if (bufferedInputStream3 != 0) {
                        bufferedInputStream3.close();
                        str2 = bufferedInputStream3;
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
            bufferedInputStream = str2;
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
            int i = inputStream.read(b);
            if (i == -1) {
                return;
            } else {
                outputStream.write(b, 0, i);
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
            Method dump skipped, instructions count: 305
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
            Method dump skipped, instructions count: 271
            To view this dump change 'Code comments level' option to 'DEBUG'
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.util.ZipUtil.zip(java.lang.String, java.lang.String):boolean");
    }
}