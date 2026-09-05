package com.androlua;

import android.util.Log;
import android.webkit.MimeTypeMap;
import com.androlua.util.AsyncTaskX;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.HashMap;
import java.util.Map;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Http {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private static HashMap<String, String> f695a;

    public static class HttpTask extends AsyncTaskX<Object, Object, Object> {
        private String l;
        private LuaObject m;
        private byte[] n;
        private String o;
        private String p;
        private String q;
        private HashMap<String, String> r;
        private String s;

        public HttpTask(String str, String str2, String str3, String str4, HashMap<String, String> map, LuaObject luaObject) {
            this.l = str;
            this.s = str2;
            this.q = str3;
            this.o = str4;
            this.p = str4;
            this.r = map;
            this.m = luaObject;
        }

        private byte[] a(Map<String, String> map) {
            StringBuilder sb = new StringBuilder();
            for (Map.Entry<String, String> entry : map.entrySet()) {
                sb.append(entry.getKey());
                sb.append("=");
                sb.append(entry.getValue());
                sb.append("&");
            }
            return sb.toString().getBytes(this.o);
        }

        private byte[] d(Object[] objArr) {
            if (objArr.length == 1) {
                Object obj = objArr[0];
                if (obj instanceof String) {
                    return ((String) obj).getBytes(this.o);
                }
                if (obj.getClass().getComponentType() == Byte.TYPE) {
                    return (byte[]) obj;
                }
                if (obj instanceof File) {
                    return LuaUtil.readAll(new FileInputStream((File) obj));
                }
                if (obj instanceof Map) {
                    return a((Map<String, String>) obj);
                }
            }
            return null;
        }

        /* JADX WARN: Removed duplicated region for block: B:72:0x01e4 A[Catch: Exception -> 0x01fb, TryCatch #0 {Exception -> 0x01fb, blocks: (B:70:0x01ce, B:72:0x01e4, B:73:0x01e7, B:75:0x01ed, B:77:0x01f3, B:78:0x01f7), top: B:98:0x01ce, outer: #1 }] */
        /* JADX WARN: Removed duplicated region for block: B:84:0x0205 A[Catch: Exception -> 0x0245, TryCatch #1 {Exception -> 0x0245, blocks: (B:3:0x000a, B:5:0x002d, B:6:0x0031, B:8:0x003e, B:9:0x004a, B:11:0x0050, B:12:0x0066, B:14:0x006a, B:15:0x0074, B:17:0x007a, B:18:0x0090, B:20:0x0094, B:21:0x009b, B:23:0x009f, B:24:0x00a4, B:26:0x00ac, B:28:0x00af, B:29:0x00d1, B:31:0x00dd, B:33:0x00e0, B:35:0x00f3, B:36:0x00fa, B:38:0x011d, B:40:0x0120, B:41:0x0129, B:44:0x0145, B:45:0x0149, B:47:0x014f, B:48:0x015c, B:50:0x0166, B:51:0x016a, B:53:0x0170, B:55:0x017e, B:57:0x0186, B:59:0x018c, B:60:0x0190, B:61:0x019b, B:68:0x01c7, B:82:0x01ff, B:84:0x0205, B:86:0x0217, B:87:0x021a, B:89:0x0220, B:91:0x0226, B:92:0x022a, B:93:0x022d, B:81:0x01fc, B:67:0x01c4, B:70:0x01ce, B:72:0x01e4, B:73:0x01e7, B:75:0x01ed, B:77:0x01f3, B:78:0x01f7, B:64:0x01a0), top: B:100:0x000a, inners: #0, #2 }] */
        @Override // com.androlua.util.AsyncTaskX
        /*
            Code decompiled incorrectly, please refer to instructions dump.
            To view partially-correct code enable 'Show inconsistent code' option in preferences
        */
        protected java.lang.Object a(java.lang.Object[] r17) {
            /*
                Method dump skipped, instruction units count: 601
                To view this dump change 'Code comments level' option to 'DEBUG'
            */
            throw new UnsupportedOperationException("Method not decompiled: com.androlua.Http.HttpTask.a(java.lang.Object[]):java.lang.Object");
        }

        @Override // com.androlua.util.AsyncTaskX
        protected void b(Object obj) {
            if (isCancelled()) {
                return;
            }
            try {
                this.m.call((Object[]) obj);
            } catch (LuaException e) {
                try {
                    this.m.getLuaState().getLuaObject("print").call(e.getMessage());
                } catch (LuaException unused) {
                }
                Log.i("lua", e.getMessage());
            }
        }

        public boolean cancel() {
            return super.cancel(true);
        }
    }

    static {
        try {
            SSLContext sSLContext = SSLContext.getInstance("SSL");
            sSLContext.init(null, new TrustManager[]{new X509TrustManager() { // from class: com.androlua.Http.1
                @Override // javax.net.ssl.X509TrustManager
                public void checkClientTrusted(X509Certificate[] x509CertificateArr, String str) {
                }

                @Override // javax.net.ssl.X509TrustManager
                public void checkServerTrusted(X509Certificate[] x509CertificateArr, String str) {
                }

                @Override // javax.net.ssl.X509TrustManager
                public X509Certificate[] getAcceptedIssuers() {
                    return new X509Certificate[0];
                }
            }}, new SecureRandom());
            HttpsURLConnection.setDefaultHostnameVerifier(new HostnameVerifier() { // from class: com.androlua.Http.2
                @Override // javax.net.ssl.HostnameVerifier
                public boolean verify(String str, SSLSession sSLSession) {
                    return true;
                }
            });
            HttpsURLConnection.setDefaultSSLSocketFactory(sSLContext.getSocketFactory());
        } catch (KeyManagementException | NoSuchAlgorithmException e) {
            e.printStackTrace();
        }
        try {
            SSLContext sSLContext2 = SSLContext.getInstance("SSL");
            sSLContext2.init(null, new TrustManager[]{new X509TrustManager() { // from class: com.androlua.Http.3
                @Override // javax.net.ssl.X509TrustManager
                public void checkClientTrusted(X509Certificate[] x509CertificateArr, String str) {
                }

                @Override // javax.net.ssl.X509TrustManager
                public void checkServerTrusted(X509Certificate[] x509CertificateArr, String str) {
                }

                @Override // javax.net.ssl.X509TrustManager
                public X509Certificate[] getAcceptedIssuers() {
                    return new X509Certificate[0];
                }
            }}, new SecureRandom());
            HttpsURLConnection.setDefaultHostnameVerifier(new HostnameVerifier() { // from class: com.androlua.Http.4
                @Override // javax.net.ssl.HostnameVerifier
                public boolean verify(String str, SSLSession sSLSession) {
                    return true;
                }
            });
            HttpsURLConnection.setDefaultSSLSocketFactory(sSLContext2.getSocketFactory());
        } catch (KeyManagementException | NoSuchAlgorithmException e2) {
            e2.printStackTrace();
        }
    }

    private static String a(String str) {
        int iLastIndexOf = str.lastIndexOf(46);
        if (iLastIndexOf < 0) {
            return "application/octet-stream";
        }
        String mimeTypeFromExtension = MimeTypeMap.getSingleton().getMimeTypeFromExtension(str.substring(iLastIndexOf + 1));
        return mimeTypeFromExtension != null ? mimeTypeFromExtension : "application/octet-stream";
    }

    private static String a(HashMap<String, String> map) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : map.entrySet()) {
            sb.append(entry.getKey());
            sb.append("=");
            sb.append(entry.getValue());
            sb.append("&");
        }
        if (!map.isEmpty()) {
            sb.deleteCharAt(sb.length() - 1);
        }
        return sb.toString();
    }

    private static byte[] a(HashMap<String, String> map, HashMap<String, String> map2, String str) {
        if (str == null) {
            str = "UTF-8";
        }
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        for (Map.Entry<String, String> entry : map.entrySet()) {
            try {
                byteArrayOutputStream.write(String.format("--%s\r\nContent-Disposition:form-data;name=\"%s\"\r\n\r\n%s\r\n", "----q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h6j7k8l9z0x1c2v3b4n5m6", entry.getKey(), entry.getValue()).getBytes(str));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        for (Map.Entry<String, String> entry2 : map2.entrySet()) {
            try {
                byteArrayOutputStream.write(String.format("--%s\r\nContent-Disposition:form-data;name=\"%s\";filename=\"%s\"\r\nContent-Type:%s\r\n\r\n", "----q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h6j7k8l9z0x1c2v3b4n5m6", entry2.getKey(), entry2.getValue(), a(entry2.getValue())).getBytes(str));
                byteArrayOutputStream.write(LuaUtil.readAll(new FileInputStream(entry2.getValue())));
                byteArrayOutputStream.write("\r\n".getBytes(str));
            } catch (IOException e2) {
                e2.printStackTrace();
            }
        }
        try {
            byteArrayOutputStream.write(String.format("--%s--\r\n", "----q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h6j7k8l9z0x1c2v3b4n5m6").getBytes(str));
        } catch (IOException e3) {
            e3.printStackTrace();
        }
        return byteArrayOutputStream.toByteArray();
    }

    public static HttpTask delete(String str, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "DELETE", null, null, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask delete(String str, String str2, LuaObject luaObject) {
        HttpTask httpTask = (str2.matches("[\\w\\-\\.:]+") && Charset.isSupported(str2)) ? new HttpTask(str, "DELETE", null, str2, null, luaObject) : new HttpTask(str, "DELETE", str2, null, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask delete(String str, String str2, String str3, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "DELETE", str2, str3, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask delete(String str, String str2, String str3, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "DELETE", str2, str3, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask delete(String str, String str2, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = (str2.matches("[\\w\\-\\.:]+") && Charset.isSupported(str2)) ? new HttpTask(str, "DELETE", null, str2, map, luaObject) : new HttpTask(str, "DELETE", str2, null, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask delete(String str, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "DELETE", null, null, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask download(String str, String str2, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", null, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask download(String str, String str2, String str3, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", str3, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask download(String str, String str2, String str3, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", str3, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask download(String str, String str2, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", null, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask get(String str, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", null, null, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask get(String str, String str2, LuaObject luaObject) {
        HttpTask httpTask = (str2.matches("[\\w\\-\\.:]+") && Charset.isSupported(str2)) ? new HttpTask(str, "GET", null, str2, null, luaObject) : new HttpTask(str, "GET", str2, null, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask get(String str, String str2, String str3, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", str2, str3, null, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask get(String str, String str2, String str3, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", str2, str3, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask get(String str, String str2, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = (str2.matches("[\\w\\-\\.:]+") && Charset.isSupported(str2)) ? new HttpTask(str, "GET", null, str2, map, luaObject) : new HttpTask(str, "GET", str2, null, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HttpTask get(String str, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "GET", null, null, map, luaObject);
        httpTask.execute(new Object[0]);
        return httpTask;
    }

    public static HashMap<String, String> getHeader() {
        return f695a;
    }

    public static HttpTask post(String str, String str2, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "POST", null, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, String str2, String str3, LuaObject luaObject) {
        HttpTask httpTask = (str3.matches("[\\w\\-.:]+") && Charset.isSupported(str3)) ? new HttpTask(str, "POST", null, str3, null, luaObject) : new HttpTask(str, "POST", str3, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, String str2, String str3, String str4, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "POST", str3, str4, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, String str2, String str3, String str4, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "POST", str3, str4, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, String str2, String str3, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = (str3.matches("[\\w\\-.:]+") && Charset.isSupported(str3)) ? new HttpTask(str, "POST", null, str3, map, luaObject) : new HttpTask(str, "POST", str3, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, String str2, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "POST", null, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask post(String str, HashMap<String, String> map, LuaObject luaObject) {
        return post(str, a(map), luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, String str2, LuaObject luaObject) {
        return post(str, a(map), str2, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, String str2, String str3, LuaObject luaObject) {
        return post(str, a(map), str2, str3, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, String str2, String str3, HashMap<String, String> map2, LuaObject luaObject) {
        return post(str, a(map), str2, str3, map2, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, String str2, HashMap<String, String> map2, LuaObject luaObject) {
        return post(str, a(map), str2, map2, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, LuaObject luaObject) {
        return post(str, map, map2, null, null, null, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, String str2, LuaObject luaObject) {
        return post(str, map, map2, str2, (HashMap<String, String>) new HashMap(), luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, String str2, String str3, LuaObject luaObject) {
        return post(str, map, map2, str2, str3, null, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, String str2, String str3, HashMap<String, String> map3, LuaObject luaObject) {
        if (map3 == null) {
            map3 = new HashMap<>();
        }
        HashMap<String, String> map4 = map3;
        map4.put("Content-Type", "multipart/form-data;boundary=----q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h6j7k8l9z0x1c2v3b4n5m6");
        HttpTask httpTask = new HttpTask(str, "POST", str2, str3, map4, luaObject);
        httpTask.execute(a(map, map2, str3));
        return httpTask;
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, String str2, HashMap<String, String> map3, LuaObject luaObject) {
        return (str2.matches("[\\w\\-.:]+") && Charset.isSupported(str2)) ? post(str, map, map2, str2, null, map3, luaObject) : post(str, map, map2, null, str2, map3, luaObject);
    }

    public static HttpTask post(String str, HashMap<String, String> map, HashMap<String, String> map2, HashMap<String, String> map3, LuaObject luaObject) {
        return post(str, map, map2, (String) null, map3, luaObject);
    }

    public static HttpTask put(String str, String str2, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "PUT", null, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask put(String str, String str2, String str3, LuaObject luaObject) {
        HttpTask httpTask = (str3.matches("[\\w\\-\\.:]+") && Charset.isSupported(str3)) ? new HttpTask(str, "PUT", null, str3, null, luaObject) : new HttpTask(str, "PUT", str3, null, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask put(String str, String str2, String str3, String str4, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "PUT", str3, str4, null, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask put(String str, String str2, String str3, String str4, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "PUT", str3, str4, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask put(String str, String str2, String str3, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = (str3.matches("[\\w\\-\\.:]+") && Charset.isSupported(str3)) ? new HttpTask(str, "PUT", null, str3, map, luaObject) : new HttpTask(str, "PUT", str3, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static HttpTask put(String str, String str2, HashMap<String, String> map, LuaObject luaObject) {
        HttpTask httpTask = new HttpTask(str, "PUT", null, null, map, luaObject);
        httpTask.execute(str2);
        return httpTask;
    }

    public static void setCookie(String str) {
        if (f695a == null) {
            f695a = new HashMap<>();
        }
        f695a.put("Cookie", str);
    }

    public static void setHeader(HashMap<String, String> map) {
        f695a = map;
    }

    public static void setReferer(String str) {
        if (f695a == null) {
            f695a = new HashMap<>();
        }
        f695a.put("Referer", str);
    }

    public static void setUserAgent(String str) {
        if (f695a == null) {
            f695a = new HashMap<>();
        }
        f695a.put("User-Agent", str);
    }
}