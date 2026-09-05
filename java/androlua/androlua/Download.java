package com.androlua;

import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.widget.EditText;
import java.io.File;
import java.util.HashMap;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Download {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private final LuaContext f686a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private EditText f687b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private String f688c;
    private DownloadBroadcastReceiver d;
    private HashMap<Long, String[]> e = new HashMap<>();
    private OnDownloadCompleteListener f;
    private String g;
    private String h;
    private String i;
    private String j;
    private long k;
    private String l;

    private class DownloadBroadcastReceiver extends BroadcastReceiver {
        private DownloadBroadcastReceiver() {
        }

        @Override // android.content.BroadcastReceiver
        public void onReceive(Context context, Intent intent) {
            long longExtra = intent.getLongExtra("extra_download_id", 0L);
            intent.getExtras();
            if (!Download.this.e.containsKey(Long.valueOf(longExtra)) || Download.this.f == null) {
                return;
            }
            String[] strArr = (String[]) Download.this.e.get(Long.valueOf(longExtra));
            Download.this.f.onDownloadComplete(strArr[0], strArr[1]);
        }
    }

    public interface OnDownloadCompleteListener {
        void onDownloadComplete(String str, String str2);
    }

    public Download(LuaContext luaContext) {
        this.f686a = luaContext;
    }

    public long getContentLength() {
        return this.k;
    }

    public String getDestinationDir() {
        return this.h;
    }

    public String getFilePath() {
        return this.l;
    }

    public String getMimeType() {
        return this.j;
    }

    public String getUrl() {
        return this.f688c;
    }

    public String getUserAgent() {
        return this.i;
    }

    public void setContentLength(long j) {
        this.k = j;
    }

    public void setDestinationDir(String str) {
        this.h = str;
    }

    public void setFilePath(String str) {
        this.l = str;
    }

    public void setMessage(String str) {
        this.g = str;
    }

    public void setMimeType(String str) {
        this.j = str;
    }

    public void setOnDownloadCompleteListener(OnDownloadCompleteListener onDownloadCompleteListener) {
        this.f = onDownloadCompleteListener;
    }

    public void setUrl(String str) {
        this.f688c = str;
    }

    public void setUserAgent(String str) {
        this.i = str;
    }

    public long start(boolean z) {
        if (this.d == null) {
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction("android.intent.action.DOWNLOAD_COMPLETE");
            this.d = new DownloadBroadcastReceiver();
            this.f686a.getContext().registerReceiver(this.d, intentFilter);
        }
        DownloadManager downloadManager = (DownloadManager) this.f686a.getContext().getSystemService("download");
        Uri uri = Uri.parse(this.f688c);
        uri.getLastPathSegment();
        DownloadManager.Request request = new DownloadManager.Request(uri);
        if (this.h == null) {
            this.h = "Download";
        }
        request.setDestinationInExternalPublicDir(this.h, this.l);
        request.setTitle(this.l);
        request.setDescription(this.f688c);
        if (z) {
            request.setAllowedNetworkTypes(2);
        }
        if (this.j == null) {
            this.j = "*/*";
        }
        request.setMimeType(this.j);
        long jEnqueue = downloadManager.enqueue(request);
        this.e.put(Long.valueOf(jEnqueue), new String[]{new File(this.h, this.l).getAbsolutePath(), this.j});
        return jEnqueue;
    }

    public void start() {
    }

    public void start(String str, String str2, String str3, String str4) {
        this.f688c = str;
        this.g = str4;
        Uri uri = Uri.parse(this.f688c);
        this.l = str3;
        if (str3 == null) {
            this.l = uri.getLastPathSegment();
        }
        if (str2 == null) {
            this.h = "Download";
        }
        this.f687b = new EditText(this.f686a.getContext());
        this.f687b.setText(this.l);
        if (this.g == null) {
            this.g = str;
        }
        new AlertDialog.Builder(this.f686a.getContext()).setTitle("Download").setMessage(this.g).setView(this.f687b).setPositiveButton("Download", new DialogInterface.OnClickListener() { // from class: com.androlua.Download.2
            @Override // android.content.DialogInterface.OnClickListener
            public void onClick(DialogInterface dialogInterface, int i) {
                Download download = Download.this;
                download.l = download.f687b.getText().toString();
                Download.this.start(false);
            }
        }).setNegativeButton("Cancel", (DialogInterface.OnClickListener) null).setNeutralButton("Only Wifi", new DialogInterface.OnClickListener() { // from class: com.androlua.Download.1
            @Override // android.content.DialogInterface.OnClickListener
            public void onClick(DialogInterface dialogInterface, int i) {
                Download download = Download.this;
                download.l = download.f687b.getText().toString();
                Download.this.start(true);
            }
        }).create().show();
    }
}