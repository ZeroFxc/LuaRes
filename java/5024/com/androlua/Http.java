package com.androlua;

import android.util.Log;
import android.webkit.MimeTypeMap;
import com.androlua.util.AsyncTaskX;
import com.luajava.LuaException;
import com.luajava.LuaObject;
import com.luajava.LuaString;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.Charset;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class Http {
    private static HashMap<String, String> a;

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

        @Override // com.androlua.util.AsyncTaskX
        protected Object a(Object[] objArr) throws IOException {
            int iIndexOf;
            try {
                HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(this.l).openConnection();
                httpURLConnection.setConnectTimeout(30000);
                HttpURLConnection.setFollowRedirects(true);
                httpURLConnection.setDoInput(true);
                httpURLConnection.setRequestProperty("Accept-Language", "zh-cn,zh;q=0.5");
                if (this.o == null) {
                    this.o = "UTF-8";
                }
                httpURLConnection.setRequestProperty("Accept-Charset", this.o);
                if (Http.a != null) {
                    for (Map.Entry entry : Http.a.entrySet()) {
                        httpURLConnection.setRequestProperty((String) entry.getKey(), (String) entry.getValue());
                    }
                }
                if (this.r != null) {
                    for (Map.Entry<String, String> entry2 : this.r.entrySet()) {
                        httpURLConnection.setRequestProperty(entry2.getKey(), entry2.getValue());
                    }
                }
                if (this.q != null) {
                    httpURLConnection.setRequestProperty("Cookie", this.q);
                }
                if (this.s != null) {
                    httpURLConnection.setRequestMethod(this.s);
                }
                if (!"GET".equals(this.s) && objArr.length != 0) {
                    this.n = d(objArr);
                    httpURLConnection.setDoOutput(true);
                    httpURLConnection.setRequestProperty("Content-length", BuildConfig.FLAVOR + this.n.length);
                }
                httpURLConnection.connect();
                if ("GET".equals(this.s) && objArr.length != 0) {
                    File file = new File((String) objArr[0]);
                    if (!file.getParentFile().exists()) {
                        file.getParentFile().mkdirs();
                    }
                    LuaUtil.copyFile(httpURLConnection.getInputStream(), new FileOutputStream(file));
                    return new Object[]{Integer.valueOf(httpURLConnection.getResponseCode()), objArr[0], httpURLConnection.getHeaderFields()};
                }
                if (objArr.length != 0) {
                    httpURLConnection.getOutputStream().write(this.n);
                }
                int responseCode = httpURLConnection.getResponseCode();
                Map<String, List<String>> headerFields = httpURLConnection.getHeaderFields();
                httpURLConnection.getContentEncoding();
                List<String> list = headerFields.get("Set-Cookie");
                StringBuilder sb = new StringBuilder();
                if (list != null) {
                    Iterator<String> it = list.iterator();
                    while (it.hasNext()) {
                        sb.append(it.next());
                        sb.append(";");
                    }
                }
                List<String> list2 = headerFields.get("Content-Type");
                if (list2 != null) {
                    Iterator<String> it2 = list2.iterator();
                    while (true) {
                        if (!it2.hasNext()) {
                            break;
                        }
                        String next = it2.next();
                        int iIndexOf2 = next.indexOf("charset");
                        if (iIndexOf2 != -1 && (iIndexOf = next.indexOf("=", iIndexOf2)) != -1) {
                            int iIndexOf3 = next.indexOf(";", iIndexOf);
                            if (iIndexOf3 == -1) {
                                iIndexOf3 = next.length();
                            }
                            this.o = next.substring(iIndexOf + 1, iIndexOf3);
                            this.p = this.o;
                        }
                    }
                }
                if (this.p == null) {
                    try {
                        InputStream inputStream = httpURLConnection.getInputStream();
                        byte[] all = LuaUtil.readAll(inputStream);
                        inputStream.close();
                        return new Object[]{Integer.valueOf(responseCode), new LuaString(all), sb.toString(), headerFields};
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                StringBuilder sb2 = new StringBuilder();
                try {
                    InputStream inputStream2 = httpURLConnection.getInputStream();
                    BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(inputStream2, this.o));
                    String line = bufferedReader.readLine();
                    if (line != null) {
                        sb2.append(line);
                    }
                    while (true) {
                        String line2 = bufferedReader.readLine();
                        if (line2 == null || isCancelled()) {
                            break;
                        }
                        sb2.append('\n');
                        sb2.append(line2);
                    }
                    inputStream2.close();
                } catch (Exception e2) {
                    e2.printStackTrace();
                }
                InputStream errorStream = httpURLConnection.getErrorStream();
                if (errorStream != null) {
                    BufferedReader bufferedReader2 = new BufferedReader(new InputStreamReader(errorStream, this.o));
                    String line3 = bufferedReader2.readLine();
                    if (line3 != null) {
                        sb2.append(line3);
                    }
                    while (true) {
                        String line4 = bufferedReader2.readLine();
                        if (line4 == null || isCancelled()) {
                            break;
                        }
                        sb2.append('\n');
                        sb2.append(line4);
                    }
                    errorStream.close();
                }
                return new Object[]{Integer.valueOf(responseCode), new String(sb2), sb.toString(), headerFields};
            } catch (Exception e3) {
                e3.printStackTrace();
                return new Object[]{-1, e3.getMessage()};
            }
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
        return a;
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
        if (a == null) {
            a = new HashMap<>();
        }
        a.put("Cookie", str);
    }

    public static void setHeader(HashMap<String, String> map) {
        a = map;
    }

    public static void setReferer(String str) {
        if (a == null) {
            a = new HashMap<>();
        }
        a.put("Referer", str);
    }

    public static void setUserAgent(String str) {
        if (a == null) {
            a = new HashMap<>();
        }
        a.put("User-Agent", str);
    }
}