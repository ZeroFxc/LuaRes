package com.androlua.util;

import android.util.Log;
import java.io.DataOutputStream;
import java.io.IOException;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class RootUtil {
    private static boolean a;

    /* JADX WARN: Removed duplicated region for block: B:58:0x00a2 A[EXC_TOP_SPLITTER, SYNTHETIC] */
    /* JADX WARN: Removed duplicated region for block: B:65:0x0098 A[EXC_TOP_SPLITTER, SYNTHETIC] */
    /* JADX WARN: Removed duplicated region for block: B:73:? A[SYNTHETIC] */
    /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
    /* JADX WARN: Unsupported multi-entry loop pattern (BACK_EDGE: B:17:0x006c -> B:62:0x0093). Please report as a decompilation issue!!! */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public static java.lang.String execRootCmd(java.lang.String r7) throws java.lang.Throwable {
        /*
            java.lang.String r0 = "\n"
            java.lang.String r1 = ""
            r2 = 0
            java.lang.Runtime r3 = java.lang.Runtime.getRuntime()     // Catch: java.lang.Throwable -> L7b java.lang.Exception -> L7f
            java.lang.String r4 = "su"
            java.lang.Process r3 = r3.exec(r4)     // Catch: java.lang.Throwable -> L7b java.lang.Exception -> L7f
            java.io.DataOutputStream r4 = new java.io.DataOutputStream     // Catch: java.lang.Throwable -> L7b java.lang.Exception -> L7f
            java.io.OutputStream r5 = r3.getOutputStream()     // Catch: java.lang.Throwable -> L7b java.lang.Exception -> L7f
            r4.<init>(r5)     // Catch: java.lang.Throwable -> L7b java.lang.Exception -> L7f
            java.io.DataInputStream r5 = new java.io.DataInputStream     // Catch: java.lang.Throwable -> L74 java.lang.Exception -> L77
            java.io.InputStream r6 = r3.getInputStream()     // Catch: java.lang.Throwable -> L74 java.lang.Exception -> L77
            r5.<init>(r6)     // Catch: java.lang.Throwable -> L74 java.lang.Exception -> L77
            java.lang.String r2 = "linin.root"
            android.util.Log.i(r2, r7)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            java.lang.StringBuilder r2 = new java.lang.StringBuilder     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.<init>()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.append(r7)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.append(r0)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            java.lang.String r7 = r2.toString()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r4.writeBytes(r7)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r4.flush()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            java.lang.String r7 = "exit\n"
            r4.writeBytes(r7)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r4.flush()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
        L43:
            java.lang.String r7 = r5.readLine()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            if (r7 == 0) goto L5c
            java.lang.StringBuilder r2 = new java.lang.StringBuilder     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.<init>()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.append(r1)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.append(r7)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r2.append(r0)     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            java.lang.String r1 = r2.toString()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            goto L43
        L5c:
            r3.waitFor()     // Catch: java.lang.Throwable -> L70 java.lang.Exception -> L72
            r4.close()     // Catch: java.io.IOException -> L63
            goto L67
        L63:
            r7 = move-exception
            r7.printStackTrace()
        L67:
            r5.close()     // Catch: java.io.IOException -> L6b
            goto L93
        L6b:
            r7 = move-exception
            r7.printStackTrace()
            goto L93
        L70:
            r7 = move-exception
            goto L96
        L72:
            r7 = move-exception
            goto L79
        L74:
            r7 = move-exception
            r5 = r2
            goto L96
        L77:
            r7 = move-exception
            r5 = r2
        L79:
            r2 = r4
            goto L81
        L7b:
            r7 = move-exception
            r4 = r2
            r5 = r4
            goto L96
        L7f:
            r7 = move-exception
            r5 = r2
        L81:
            r7.printStackTrace()     // Catch: java.lang.Throwable -> L94
            if (r2 == 0) goto L8e
            r2.close()     // Catch: java.io.IOException -> L8a
            goto L8e
        L8a:
            r7 = move-exception
            r7.printStackTrace()
        L8e:
            if (r5 == 0) goto L93
            r5.close()     // Catch: java.io.IOException -> L6b
        L93:
            return r1
        L94:
            r7 = move-exception
            r4 = r2
        L96:
            if (r4 == 0) goto La0
            r4.close()     // Catch: java.io.IOException -> L9c
            goto La0
        L9c:
            r0 = move-exception
            r0.printStackTrace()
        La0:
            if (r5 == 0) goto Laa
            r5.close()     // Catch: java.io.IOException -> La6
            goto Laa
        La6:
            r0 = move-exception
            r0.printStackTrace()
        Laa:
            throw r7
            return
        */
        throw new UnsupportedOperationException("Method not decompiled: com.androlua.util.RootUtil.execRootCmd(java.lang.String):java.lang.String");
    }

    public static int execRootCmdSilent(String str) throws Throwable {
        DataOutputStream dataOutputStream;
        DataOutputStream dataOutputStream2 = null;
        try {
            try {
                Process processExec = Runtime.getRuntime().exec("su");
                dataOutputStream = new DataOutputStream(processExec.getOutputStream());
                try {
                    Log.i("linin.root", str);
                    dataOutputStream.writeBytes(str + "\n");
                    dataOutputStream.flush();
                    dataOutputStream.writeBytes("exit\n");
                    dataOutputStream.flush();
                    processExec.waitFor();
                    int iExitValue = processExec.exitValue();
                    try {
                        dataOutputStream.close();
                        return iExitValue;
                    } catch (IOException e) {
                        e.printStackTrace();
                        return iExitValue;
                    }
                } catch (Exception e2) {
                    e = e2;
                    dataOutputStream2 = dataOutputStream;
                    e.printStackTrace();
                    if (dataOutputStream2 != null) {
                        try {
                            dataOutputStream2.close();
                        } catch (IOException e3) {
                            e3.printStackTrace();
                        }
                    }
                    return -1;
                } catch (Throwable th) {
                    th = th;
                    if (dataOutputStream != null) {
                        try {
                            dataOutputStream.close();
                        } catch (IOException e4) {
                            e4.printStackTrace();
                        }
                    }
                    throw th;
                }
            } catch (Throwable th2) {
                th = th2;
                dataOutputStream = dataOutputStream2;
            }
        } catch (Exception e5) {
            e = e5;
        }
    }

    public static boolean haveRoot() {
        String str;
        if (a) {
            str = "mHaveRoot = true, have root!";
        } else {
            if (execRootCmdSilent("echo test") != -1) {
                Log.i("linin.root", "have root!");
                a = true;
                return a;
            }
            str = "not root!";
        }
        Log.i("linin.root", str);
        return a;
    }

    public static boolean root() throws IOException {
        try {
            Runtime.getRuntime().exec(new String[]{"/system/bin/su", "-c", "chmod 777 /dev/graphics/fb0"});
            Log.i("linin.root", "root success!");
            return true;
        } catch (IOException e) {
            e.printStackTrace();
            Log.i("linin.root", "root fail!");
            return false;
        }
    }
}