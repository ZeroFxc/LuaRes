package com.androlua;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.os.Message;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.KeyEvent;
import android.view.View;
import android.webkit.ClientCertRequest;
import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;
import android.webkit.DownloadListener;
import android.webkit.HttpAuthHandler;
import android.webkit.JavascriptInterface;
import android.webkit.JsPromptResult;
import android.webkit.JsResult;
import android.webkit.SslErrorHandler;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.AbsoluteLayout;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListAdapter;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import com.luajava.LuaException;
import com.luajava.LuaFunction;
import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaWebView extends WebView implements LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private DownloadBroadcastReceiver f883a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private HashMap<Long, String[]> f884b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private OnDownloadCompleteListener f885c;
    private LuaActivity d;
    private ProgressBar e;
    private DisplayMetrics f;
    private Dialog g;
    private ListView h;
    private ValueCallback<Uri> i;
    private String j;
    private LuaFunction<Boolean> k;
    private boolean l;
    private String m;
    private OnReceivedTitleListener n;
    private OnReceivedIconListener o;

    private class Download implements DownloadListener {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        EditText f894a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private String f895b;

        /* JADX INFO: renamed from: c, reason: collision with root package name */
        private String f896c;
        private String d;
        private String e;
        private long f;
        private String g;

        private Download() {
        }

        private long a(boolean z) {
            if (LuaWebView.this.f883a == null) {
                IntentFilter intentFilter = new IntentFilter();
                intentFilter.addAction("android.intent.action.DOWNLOAD_COMPLETE");
                LuaWebView luaWebView = LuaWebView.this;
                luaWebView.f883a = new DownloadBroadcastReceiver();
                LuaWebView.this.d.registerReceiver(LuaWebView.this.f883a, intentFilter);
            }
            DownloadManager downloadManager = (DownloadManager) LuaWebView.this.d.getSystemService("download");
            Uri uri = Uri.parse(this.f895b);
            uri.getLastPathSegment();
            DownloadManager.Request request = new DownloadManager.Request(uri);
            String luaExtDir = LuaWebView.this.d.getLuaExtDir("Download");
            request.setDestinationInExternalPublicDir(new File(LuaWebView.this.d.getLuaExtDir()).getName() + "/Download", this.g);
            request.setTitle(this.g);
            request.setDescription(this.f895b);
            if (z) {
                request.setAllowedNetworkTypes(2);
            }
            File file = new File(luaExtDir, this.g);
            if (file.exists()) {
                file.delete();
            }
            request.setMimeType(this.e);
            long jEnqueue = downloadManager.enqueue(request);
            LuaWebView.this.f884b.put(Long.valueOf(jEnqueue), new String[]{new File(luaExtDir, this.g).getAbsolutePath(), this.e});
            return jEnqueue;
        }

        @Override // android.webkit.DownloadListener
        @SuppressLint({"DefaultLocale"})
        public void onDownloadStart(String str, String str2, String str3, String str4, long j) {
            Object[] objArr;
            String str5;
            int iIndexOf;
            int i;
            int iIndexOf2;
            this.f895b = str;
            this.f896c = str2;
            this.d = str3;
            this.e = str4;
            this.f = j;
            this.g = Uri.parse(this.f895b).getLastPathSegment();
            if (str3 != null && (iIndexOf = str3.indexOf("filename=\"")) != -1 && (iIndexOf2 = str3.indexOf(34, (i = iIndexOf + 10))) > i) {
                this.g = str3.substring(i, iIndexOf2);
            }
            this.f894a = new EditText(LuaWebView.this.d);
            this.f894a.setText(this.g);
            String str6 = String.valueOf(j) + "B";
            if (j <= 1048576) {
                if (j > 1024) {
                    objArr = new Object[]{Double.valueOf(Long.valueOf(j).doubleValue() / 1024.0d)};
                    str5 = "%.2f KB";
                }
                new AlertDialog.Builder(LuaWebView.this.d).setTitle("Download").setMessage("Type: " + str4 + "\nSize: " + str6).setView(this.f894a).setPositiveButton("Download", new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.Download.2
                    @Override // android.content.DialogInterface.OnClickListener
                    public void onClick(DialogInterface dialogInterface, int i2) {
                        Download download = Download.this;
                        download.g = download.f894a.getText().toString();
                        Download.this.a(false);
                    }
                }).setNegativeButton(android.R.string.cancel, (DialogInterface.OnClickListener) null).setNeutralButton("Only Wifi", new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.Download.1
                    @Override // android.content.DialogInterface.OnClickListener
                    public void onClick(DialogInterface dialogInterface, int i2) {
                        Download download = Download.this;
                        download.g = download.f894a.getText().toString();
                        Download.this.a(true);
                    }
                }).create().show();
            }
            objArr = new Object[]{Double.valueOf(Long.valueOf(j).doubleValue() / 1048576.0d)};
            str5 = "%.2f MB";
            str6 = String.format(str5, objArr);
            new AlertDialog.Builder(LuaWebView.this.d).setTitle("Download").setMessage("Type: " + str4 + "\nSize: " + str6).setView(this.f894a).setPositiveButton("Download", new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.Download.2
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i2) {
                    Download download = Download.this;
                    download.g = download.f894a.getText().toString();
                    Download.this.a(false);
                }
            }).setNegativeButton(android.R.string.cancel, (DialogInterface.OnClickListener) null).setNeutralButton("Only Wifi", new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.Download.1
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i2) {
                    Download download = Download.this;
                    download.g = download.f894a.getText().toString();
                    Download.this.a(true);
                }
            }).create().show();
        }
    }

    private class DownloadBroadcastReceiver extends BroadcastReceiver {
        private DownloadBroadcastReceiver() {
        }

        @Override // android.content.BroadcastReceiver
        public void onReceive(Context context, Intent intent) {
            long longExtra = intent.getLongExtra("extra_download_id", 0L);
            intent.getExtras();
            if (!LuaWebView.this.f884b.containsKey(Long.valueOf(longExtra)) || LuaWebView.this.f885c == null) {
                return;
            }
            String[] strArr = (String[]) LuaWebView.this.f884b.get(Long.valueOf(longExtra));
            LuaWebView.this.f885c.onDownloadComplete(strArr[0], strArr[1]);
        }
    }

    final class InJavaScriptLocalObj {
        InJavaScriptLocalObj() {
        }

        @JavascriptInterface
        public void get(String str) {
            Log.i("luaj", "get: " + str);
            LuaWebView.this.m = str;
        }
    }

    public interface JsInterface {
        @JavascriptInterface
        String execute(String str);
    }

    class JsObject {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private JsInterface f901a;

        public JsObject(JsInterface jsInterface) {
            this.f901a = jsInterface;
        }

        @JavascriptInterface
        public String execute(String str) {
            return this.f901a.execute(str);
        }
    }

    private class LuaJavaScriptInterface {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private LuaActivity f903a;

        public LuaJavaScriptInterface(LuaActivity luaActivity) {
            this.f903a = luaActivity;
        }

        @JavascriptInterface
        public Object callLuaFunction(String str) {
            return this.f903a.runFunc(str, new Object[0]);
        }

        @JavascriptInterface
        public Object callLuaFunction(String str, String str2) {
            return this.f903a.runFunc(str, str2);
        }

        @JavascriptInterface
        public Object doLuaString(String str) {
            return this.f903a.doString(str, new Object[0]);
        }
    }

    class LuaWebChromeClient extends WebChromeClient {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        EditText f905a;

        LuaWebChromeClient() {
            this.f905a = new EditText(LuaWebView.this.d);
        }

        @Override // android.webkit.WebChromeClient
        public Bitmap getDefaultVideoPoster() {
            return BitmapFactory.decodeResource(LuaWebView.this.d.getResources(), R.drawable.icon);
        }

        @Override // android.webkit.WebChromeClient
        public boolean onJsAlert(WebView webView, String str, String str2, final JsResult jsResult) {
            new AlertDialog.Builder(LuaWebView.this.d).setTitle(str).setMessage(str2).setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.1
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i) {
                    jsResult.confirm();
                }
            }).setCancelable(false).create().show();
            return true;
        }

        @Override // android.webkit.WebChromeClient
        public boolean onJsConfirm(WebView webView, String str, String str2, final JsResult jsResult) {
            AlertDialog.Builder builder = new AlertDialog.Builder(LuaWebView.this.d);
            builder.setTitle(str);
            builder.setMessage(str2);
            builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.2
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i) {
                    jsResult.confirm();
                }
            });
            builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.3
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i) {
                    jsResult.cancel();
                }
            });
            builder.setCancelable(false);
            builder.create();
            builder.show();
            return true;
        }

        @Override // android.webkit.WebChromeClient
        public boolean onJsPrompt(WebView webView, String str, String str2, String str3, final JsPromptResult jsPromptResult) {
            this.f905a.setText(str3);
            AlertDialog.Builder builder = new AlertDialog.Builder(LuaWebView.this.d);
            builder.setTitle(str);
            builder.setMessage(str2);
            builder.setView(this.f905a);
            builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.4
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i) {
                    jsPromptResult.confirm(LuaWebChromeClient.this.f905a.getText().toString());
                }
            });
            builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.5
                @Override // android.content.DialogInterface.OnClickListener
                public void onClick(DialogInterface dialogInterface, int i) {
                    jsPromptResult.cancel();
                }
            });
            builder.setOnCancelListener(new DialogInterface.OnCancelListener() { // from class: com.androlua.LuaWebView.LuaWebChromeClient.6
                @Override // android.content.DialogInterface.OnCancelListener
                public void onCancel(DialogInterface dialogInterface) {
                    jsPromptResult.cancel();
                }
            });
            builder.show();
            return true;
        }

        @Override // android.webkit.WebChromeClient
        public void onProgressChanged(WebView webView, int i) {
            if (i == 100) {
                LuaWebView.this.e.setVisibility(8);
            } else {
                LuaWebView.this.e.setVisibility(0);
                LuaWebView.this.e.setProgress(i);
            }
            super.onProgressChanged(webView, i);
        }

        @Override // android.webkit.WebChromeClient
        public void onReceivedIcon(WebView webView, Bitmap bitmap) {
            super.onReceivedIcon(webView, bitmap);
            if (LuaWebView.this.o != null) {
                LuaWebView.this.o.onReceivedIcon(bitmap);
            }
        }

        @Override // android.webkit.WebChromeClient
        public void onReceivedTitle(WebView webView, String str) {
            super.onReceivedTitle(webView, str);
            if (LuaWebView.this.n != null) {
                LuaWebView.this.n.onReceivedTitle(str);
            }
        }

        public void openFileChooser(ValueCallback<Uri> valueCallback) {
            openFileChooser(valueCallback, BuildConfig.FLAVOR);
        }

        public void openFileChooser(ValueCallback<Uri> valueCallback, String str) {
            if (LuaWebView.this.i != null) {
                return;
            }
            LuaWebView.this.i = valueCallback;
            LuaWebView luaWebView = LuaWebView.this;
            luaWebView.openFile(luaWebView.j);
        }

        public void openFileChooser(ValueCallback<Uri> valueCallback, String str, String str2) {
            openFileChooser(valueCallback, str);
        }
    }

    public interface LuaWebViewClient {
        public static final int ERROR_AUTHENTICATION = -4;
        public static final int ERROR_BAD_URL = -12;
        public static final int ERROR_CONNECT = -6;
        public static final int ERROR_FAILED_SSL_HANDSHAKE = -11;
        public static final int ERROR_FILE = -13;
        public static final int ERROR_FILE_NOT_FOUND = -14;
        public static final int ERROR_HOST_LOOKUP = -2;
        public static final int ERROR_IO = -7;
        public static final int ERROR_PROXY_AUTHENTICATION = -5;
        public static final int ERROR_REDIRECT_LOOP = -9;
        public static final int ERROR_TIMEOUT = -8;
        public static final int ERROR_TOO_MANY_REQUESTS = -15;
        public static final int ERROR_UNKNOWN = -1;
        public static final int ERROR_UNSUPPORTED_AUTH_SCHEME = -3;
        public static final int ERROR_UNSUPPORTED_SCHEME = -10;

        void doUpdateVisitedHistory(WebView webView, String str, boolean z);

        void onFormResubmission(WebView webView, Message message, Message message2);

        void onLoadResource(WebView webView, String str);

        void onPageFinished(WebView webView, String str);

        void onPageStarted(WebView webView, String str, Bitmap bitmap);

        void onProceededAfterSslError(WebView webView, SslError sslError);

        void onReceivedClientCertRequest(WebView webView, ClientCertRequest clientCertRequest, String str);

        void onReceivedError(WebView webView, int i, String str, String str2);

        void onReceivedHttpAuthRequest(WebView webView, HttpAuthHandler httpAuthHandler, String str, String str2);

        void onReceivedLoginRequest(WebView webView, String str, String str2, String str3);

        void onReceivedSslError(WebView webView, SslErrorHandler sslErrorHandler, SslError sslError);

        void onScaleChanged(WebView webView, float f, float f2);

        @Deprecated
        void onTooManyRedirects(WebView webView, Message message, Message message2);

        void onUnhandledKeyEvent(WebView webView, KeyEvent keyEvent);

        WebResourceResponse shouldInterceptRequest(WebView webView, String str);

        boolean shouldOverrideKeyEvent(WebView webView, KeyEvent keyEvent);

        boolean shouldOverrideUrlLoading(WebView webView, String str);
    }

    public interface OnDownloadCompleteListener {
        void onDownloadComplete(String str, String str2);
    }

    public interface OnDownloadStartListener {
        void onDownloadStart(String str, String str2, String str3, String str4, long j);
    }

    public interface OnReceivedIconListener {
        void onReceivedIcon(Bitmap bitmap);
    }

    public interface OnReceivedTitleListener {
        void onReceivedTitle(String str);
    }

    private class SimpleLuaWebViewClient extends WebViewClient {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private LuaWebViewClient f919a;

        public SimpleLuaWebViewClient(LuaWebViewClient luaWebViewClient) {
            this.f919a = luaWebViewClient;
        }

        @Override // android.webkit.WebViewClient
        public void doUpdateVisitedHistory(WebView webView, String str, boolean z) {
            this.f919a.doUpdateVisitedHistory(webView, str, z);
        }

        @Override // android.webkit.WebViewClient
        public void onFormResubmission(WebView webView, Message message, Message message2) {
            message.sendToTarget();
        }

        @Override // android.webkit.WebViewClient
        public void onLoadResource(WebView webView, String str) {
            this.f919a.onLoadResource(webView, str);
        }

        @Override // android.webkit.WebViewClient
        public void onPageFinished(WebView webView, String str) {
            this.f919a.onPageFinished(webView, str);
        }

        @Override // android.webkit.WebViewClient
        public void onPageStarted(WebView webView, String str, Bitmap bitmap) {
            this.f919a.onPageStarted(webView, str, bitmap);
        }

        public void onProceededAfterSslError(WebView webView, SslError sslError) {
            this.f919a.onProceededAfterSslError(webView, sslError);
        }

        public void onReceivedClientCertRequest(WebView webView, ClientCertRequest clientCertRequest, String str) {
            this.f919a.onReceivedClientCertRequest(webView, clientCertRequest, str);
        }

        @Override // android.webkit.WebViewClient
        public void onReceivedError(WebView webView, int i, String str, String str2) {
            this.f919a.onReceivedError(webView, i, str, str2);
        }

        @Override // android.webkit.WebViewClient
        public void onReceivedHttpAuthRequest(WebView webView, HttpAuthHandler httpAuthHandler, String str, String str2) {
            this.f919a.onReceivedHttpAuthRequest(webView, httpAuthHandler, str, str2);
        }

        @Override // android.webkit.WebViewClient
        public void onReceivedLoginRequest(WebView webView, String str, String str2, String str3) {
            this.f919a.onReceivedLoginRequest(webView, str, str2, str3);
        }

        @Override // android.webkit.WebViewClient
        public void onReceivedSslError(WebView webView, SslErrorHandler sslErrorHandler, SslError sslError) {
            this.f919a.onReceivedSslError(webView, sslErrorHandler, sslError);
        }

        @Override // android.webkit.WebViewClient
        public void onScaleChanged(WebView webView, float f, float f2) {
            this.f919a.onScaleChanged(webView, f, f2);
        }

        @Override // android.webkit.WebViewClient
        @Deprecated
        public void onTooManyRedirects(WebView webView, Message message, Message message2) {
            message.sendToTarget();
        }

        @Override // android.webkit.WebViewClient
        public void onUnhandledKeyEvent(WebView webView, KeyEvent keyEvent) {
            this.f919a.onUnhandledKeyEvent(webView, keyEvent);
        }

        @Override // android.webkit.WebViewClient
        public WebResourceResponse shouldInterceptRequest(WebView webView, WebResourceRequest webResourceRequest) {
            return super.shouldInterceptRequest(webView, webResourceRequest);
        }

        @Override // android.webkit.WebViewClient
        public WebResourceResponse shouldInterceptRequest(WebView webView, String str) {
            if (LuaWebView.this.k != null) {
                try {
                    if (((Boolean) LuaWebView.this.k.call(str)).booleanValue()) {
                        return new WebResourceResponse(null, null, null);
                    }
                } catch (LuaException e) {
                    e.printStackTrace();
                }
            }
            return this.f919a.shouldInterceptRequest(webView, str);
        }

        @Override // android.webkit.WebViewClient
        public boolean shouldOverrideKeyEvent(WebView webView, KeyEvent keyEvent) {
            return this.f919a.shouldOverrideKeyEvent(webView, keyEvent);
        }

        @Override // android.webkit.WebViewClient
        public boolean shouldOverrideUrlLoading(WebView webView, String str) {
            return this.f919a.shouldOverrideUrlLoading(webView, str);
        }
    }

    @SuppressLint({"AddJavascriptInterface", "SetJavaScriptEnabled"})
    public LuaWebView(LuaActivity luaActivity) {
        super(luaActivity);
        this.f884b = new HashMap<>();
        this.j = "/";
        luaActivity.regGc(this);
        this.d = luaActivity;
        getSettings().setJavaScriptEnabled(true);
        getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
        getSettings().setDisplayZoomControls(true);
        getSettings().setSupportZoom(true);
        getSettings().setDomStorageEnabled(true);
        if (Build.VERSION.SDK_INT >= 21) {
            getSettings().setMixedContentMode(0);
        }
        addJavascriptInterface(new LuaJavaScriptInterface(luaActivity), "androlua");
        addJavascriptInterface(new InJavaScriptLocalObj(), "java_obj");
        setWebViewClient(new WebViewClient() { // from class: com.androlua.LuaWebView.1
            @Override // android.webkit.WebViewClient
            public void onPageFinished(WebView webView, String str) {
                super.onPageFinished(webView, str);
                webView.loadUrl("javascript:window.java_obj.get('<html>'+document.getElementsByTagName('html')[0].innerHTML+'</html>');");
            }

            @Override // android.webkit.WebViewClient
            public void onReceivedSslError(WebView webView, final SslErrorHandler sslErrorHandler, SslError sslError) {
                AlertDialog.Builder builder = new AlertDialog.Builder(LuaWebView.this.d);
                builder.setTitle("SslError");
                builder.setMessage(sslError.toString());
                builder.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.1.1
                    @Override // android.content.DialogInterface.OnClickListener
                    public void onClick(DialogInterface dialogInterface, int i) {
                        sslErrorHandler.proceed();
                    }
                });
                builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() { // from class: com.androlua.LuaWebView.1.2
                    @Override // android.content.DialogInterface.OnClickListener
                    public void onClick(DialogInterface dialogInterface, int i) {
                        sslErrorHandler.cancel();
                    }
                });
                builder.setCancelable(false);
                builder.create();
                builder.show();
            }

            @Override // android.webkit.WebViewClient
            public WebResourceResponse shouldInterceptRequest(WebView webView, String str) {
                if (LuaWebView.this.k != null) {
                    try {
                        Boolean bool = (Boolean) LuaWebView.this.k.call(str);
                        if (bool != null && bool.booleanValue()) {
                            return new WebResourceResponse(null, null, null);
                        }
                    } catch (LuaException e) {
                        e.printStackTrace();
                    }
                }
                return null;
            }

            @Override // android.webkit.WebViewClient
            public boolean shouldOverrideUrlLoading(WebView webView, String str) {
                if (LuaWebView.this.k != null) {
                    try {
                        Boolean bool = (Boolean) LuaWebView.this.k.call(str);
                        if (bool != null) {
                            if (bool.booleanValue()) {
                                return true;
                            }
                        }
                    } catch (LuaException e) {
                        e.printStackTrace();
                    }
                }
                if (str.startsWith("http") || str.startsWith("file")) {
                    webView.loadUrl(str);
                    return true;
                }
                try {
                    LuaWebView.this.d.startActivityForResult(new Intent("android.intent.action.VIEW", Uri.parse(str)), 0);
                } catch (Exception e2) {
                    LuaWebView.this.d.sendError("LuaWebView", e2);
                }
                return true;
            }
        });
        this.f = luaActivity.getResources().getDisplayMetrics();
        int iApplyDimension = (int) TypedValue.applyDimension(1, 2.0f, this.f);
        this.e = new ProgressBar(luaActivity, null, android.R.attr.progressBarStyleHorizontal);
        this.e.setLayoutParams(new AbsoluteLayout.LayoutParams(-1, iApplyDimension, 0, 0));
        addView(this.e);
        setWebChromeClient(new LuaWebChromeClient());
        setDownloadListener(new Download());
    }

    @SuppressLint({"AddJavascriptInterface"})
    public void addJSInterface(JsInterface jsInterface, String str) {
        super.addJavascriptInterface(new JsObject(jsInterface), str);
    }

    @SuppressLint({"AddJavascriptInterface"})
    public void addJsInterface(JsInterface jsInterface, String str) {
        super.addJavascriptInterface(new JsObject(jsInterface), str);
    }

    @Override // android.webkit.WebView
    public void destroy() {
        DownloadBroadcastReceiver downloadBroadcastReceiver = this.f883a;
        if (downloadBroadcastReceiver != null) {
            this.d.unregisterReceiver(downloadBroadcastReceiver);
        }
        super.destroy();
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        destroy();
        this.l = true;
    }

    public String getCookie() {
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        return cookieManager.getCookie(getUrl());
    }

    public String getCookie(String str) {
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        return cookieManager.getCookie(str);
    }

    public String getSource() {
        return this.m;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.l;
    }

    @Override // android.webkit.WebView, android.view.View, android.view.KeyEvent.Callback
    public boolean onKeyDown(int i, KeyEvent keyEvent) {
        if (i != 4 || !canGoBack()) {
            return super.onKeyDown(i, keyEvent);
        }
        goBack();
        return true;
    }

    @Override // android.webkit.WebView, android.view.View
    protected void onScrollChanged(int i, int i2, int i3, int i4) {
        AbsoluteLayout.LayoutParams layoutParams = (AbsoluteLayout.LayoutParams) this.e.getLayoutParams();
        layoutParams.x = i;
        layoutParams.y = i2;
        this.e.setLayoutParams(layoutParams);
        super.onScrollChanged(i, i2, i3, i4);
    }

    public void openFile(String str) {
        if (this.g == null) {
            this.g = new Dialog(getContext());
            this.h = new ListView(getContext());
            this.h.setFastScrollEnabled(true);
            this.h.setFastScrollAlwaysVisible(true);
            this.g.setContentView(this.h);
            this.h.setOnItemClickListener(new AdapterView.OnItemClickListener() { // from class: com.androlua.LuaWebView.3
                @Override // android.widget.AdapterView.OnItemClickListener
                public void onItemClick(AdapterView<?> adapterView, View view, int i, long j) {
                    String string = ((TextView) view).getText().toString();
                    if (string.equals("../")) {
                        LuaWebView.this.j = new File(LuaWebView.this.j).getParent() + "/";
                        LuaWebView luaWebView = LuaWebView.this;
                        luaWebView.openFile(luaWebView.j);
                        return;
                    }
                    String str2 = LuaWebView.this.j + string;
                    if (!new File(str2).isDirectory()) {
                        LuaWebView.this.i.onReceiveValue(Uri.parse(str2));
                        return;
                    }
                    LuaWebView.this.j = str2;
                    LuaWebView luaWebView2 = LuaWebView.this;
                    luaWebView2.openFile(luaWebView2.j);
                }
            });
        }
        File file = new File(str);
        ArrayList arrayList = new ArrayList();
        arrayList.add("../");
        String[] list = file.list();
        if (list != null) {
            Arrays.sort(list);
            for (String str2 : list) {
                if (new File(this.j + str2).isDirectory()) {
                    arrayList.add(str2 + "/");
                }
            }
            for (String str3 : list) {
                if (new File(this.j + str3).isFile()) {
                    arrayList.add(str3);
                }
            }
        }
        this.h.setAdapter((ListAdapter) new ArrayAdapter(getContext(), android.R.layout.simple_list_item_1, arrayList));
        this.g.setTitle(this.j);
        this.g.show();
    }

    public void setAdsFilter(LuaFunction<Boolean> luaFunction) {
        this.k = luaFunction;
    }

    public void setCookie(String str) {
        String url = getUrl();
        CookieSyncManager.createInstance(this.d);
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        for (String str2 : str.split(";")) {
            cookieManager.setCookie(url, str2);
        }
        if (Build.VERSION.SDK_INT >= 21) {
            cookieManager.flush();
        }
        CookieSyncManager.getInstance().sync();
    }

    public void setCookie(String str, String str2) {
        CookieSyncManager.createInstance(this.d);
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        for (String str3 : str2.split(";")) {
            cookieManager.setCookie(str, str3);
        }
        if (Build.VERSION.SDK_INT >= 21) {
            cookieManager.flush();
        }
        CookieSyncManager.getInstance().sync();
    }

    @Override // android.webkit.WebView
    public void setDownloadListener(DownloadListener downloadListener) {
        super.setDownloadListener(downloadListener);
    }

    public void setOnDownloadCompleteListener(OnDownloadCompleteListener onDownloadCompleteListener) {
        this.f885c = onDownloadCompleteListener;
    }

    public void setOnDownloadStartListener(final OnDownloadStartListener onDownloadStartListener) {
        setDownloadListener(new DownloadListener() { // from class: com.androlua.LuaWebView.2
            @Override // android.webkit.DownloadListener
            public void onDownloadStart(String str, String str2, String str3, String str4, long j) {
                onDownloadStartListener.onDownloadStart(str, str2, str3, str4, j);
            }
        });
    }

    @Override // android.view.View
    public void setOnKeyListener(View.OnKeyListener onKeyListener) {
        super.setOnKeyListener(onKeyListener);
    }

    public void setOnReceivedIconListener(OnReceivedIconListener onReceivedIconListener) {
        this.o = onReceivedIconListener;
    }

    public void setOnReceivedTitleListener(OnReceivedTitleListener onReceivedTitleListener) {
        this.n = onReceivedTitleListener;
    }

    public void setProgressBar(ProgressBar progressBar) {
        this.e = progressBar;
    }

    public void setProgressBarEnabled(boolean z) {
        ProgressBar progressBar;
        int i;
        if (z) {
            progressBar = this.e;
            i = 0;
        } else {
            progressBar = this.e;
            i = 8;
        }
        progressBar.setVisibility(i);
    }

    public void setWebViewClient(LuaWebViewClient luaWebViewClient) {
        super.setWebViewClient(new SimpleLuaWebViewClient(luaWebViewClient));
    }
}