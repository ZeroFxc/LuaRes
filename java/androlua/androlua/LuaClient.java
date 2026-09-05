package com.androlua;

import android.util.Log;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.Socket;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaClient implements LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private OnReadLineListener f765a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private OnErrorListener f766b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private Socket f767c;
    private BufferedReader d;
    private BufferedWriter e;
    private boolean f;

    public interface OnErrorListener {
        void onErrorLine(LuaClient luaClient, SocketThread socketThread, String str);
    }

    public interface OnReadLineListener {
        void onReadLine(LuaClient luaClient, SocketThread socketThread, String str);
    }

    private class SocketThread extends Thread {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private final Socket f768a;

        public SocketThread(Socket socket) {
            this.f768a = socket;
        }

        public boolean close() {
            try {
                this.f768a.close();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.f766b == null) {
                    return false;
                }
                LuaClient.this.f766b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        public boolean flush() {
            try {
                LuaClient.this.e.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.f766b == null) {
                    return false;
                }
                LuaClient.this.f766b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        public boolean newLine() {
            try {
                LuaClient.this.e.newLine();
                LuaClient.this.e.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.f766b == null) {
                    return false;
                }
                LuaClient.this.f766b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            while (true) {
                try {
                    String line = LuaClient.this.d.readLine();
                    if (line == null) {
                        return;
                    }
                    if (LuaClient.this.f765a != null) {
                        LuaClient.this.f765a.onReadLine(LuaClient.this, this, line);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    if (LuaClient.this.f766b != null) {
                        LuaClient.this.f766b.onErrorLine(LuaClient.this, this, e.toString());
                        return;
                    }
                    return;
                }
            }
        }

        public boolean write(String str) {
            try {
                Log.i("lua", str);
                LuaClient.this.e.write(str);
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.f766b == null) {
                    return false;
                }
                LuaClient.this.f766b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }
    }

    public LuaClient() {
    }

    public LuaClient(LuaContext luaContext) {
        luaContext.regGc(this);
    }

    public boolean flush() {
        try {
            this.e.flush();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.f766b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        stop();
        this.f = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.f;
    }

    public boolean newLine() {
        try {
            this.e.newLine();
            this.e.flush();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.f766b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }

    public void setOnReadLineListener(OnReadLineListener onReadLineListener) {
        this.f765a = onReadLineListener;
    }

    public boolean start(String str, int i) {
        if (this.f767c != null) {
            return false;
        }
        try {
            this.f767c = new Socket(str, i);
            this.f767c.setSoTimeout(3600000);
            this.d = new BufferedReader(new InputStreamReader(this.f767c.getInputStream()));
            this.e = new BufferedWriter(new OutputStreamWriter(this.f767c.getOutputStream()));
            new SocketThread(this.f767c).start();
            return true;
        } catch (IOException e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.f766b;
            if (onErrorListener != null) {
                onErrorListener.onErrorLine(this, null, e.toString());
            }
            return false;
        }
    }

    public boolean stop() {
        Socket socket = this.f767c;
        if (socket == null) {
            return false;
        }
        try {
            socket.close();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.f766b;
            if (onErrorListener != null) {
                onErrorListener.onErrorLine(this, null, e.toString());
            }
            return false;
        }
    }

    public boolean write(String str) {
        try {
            this.e.write(str);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.f766b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }
}