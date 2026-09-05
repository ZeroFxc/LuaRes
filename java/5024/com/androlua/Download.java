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

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class Download {
    private final LuaContext a;
    private EditText b;
    private String c;
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
        this.a = luaContext;
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
        return this.c;
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
        this.c = str;
    }

    public void setUserAgent(String str) {
        this.i = str;
    }

    public long start(boolean z) {
        if (this.d == null) {
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction("android.intent.action.DOWNLOAD_COMPLETE");
            this.d = new DownloadBroadcastReceiver();
            this.a.getContext().registerReceiver(this.d, intentFilter);
        }
        DownloadManager downloadManager = (DownloadManager) this.a.getContext().getSystemService("download");
        Uri uri = Uri.parse(this.c);
        uri.getLastPathSegment();
        DownloadManager.Request request = new DownloadManager.Request(uri);
        if (this.h == null) {
            this.h = "Download";
        }
        request.setDestinationInExternalPublicDir(this.h, this.l);
        request.setTitle(this.l);
        request.setDescription(this.c);
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
        this.c = str;
        this.g = str4;
        Uri uri = Uri.parse(this.c);
        this.l = str3;
        if (str3 == null) {
            this.l = uri.getLastPathSegment();
        }
        if (str2 == null) {
            this.h = "Download";
        }
        this.b = new EditText(this.a.getContext());
        this.b.setText(this.l);
        if (this.g == null) {
            this.g = str;
        }
        new AlertDialog.Builder(this.a.getContext()).setTitle("Download").setMessage(this.g).setView(this.b).setPositiveButton("Download", new DialogInterface.OnClickListener() { // from class: com.androlua.Download.2
            @Override // android.content.DialogInterface.OnClickListener
            public void onClick(DialogInterface dialogInterface, int i) {
                Download download = Download.this;
                download.l = download.b.getText().toString();
                Download.this.start(false);
            }
        }).setNegativeButton("Cancel", (DialogInterface.OnClickListener) null).setNeutralButton("Only Wifi", new DialogInterface.OnClickListener() { // from class: com.androlua.Download.1
            @Override // android.content.DialogInterface.OnClickListener
            public void onClick(DialogInterface dialogInterface, int i) {
                Download download = Download.this;
                download.l = download.b.getText().toString();
                Download.this.start(true);
            }
        }).create().show();
    }
}