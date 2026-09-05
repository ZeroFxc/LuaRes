package com.androlua;

import android.util.Log;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.Socket;
import java.net.SocketException;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaClient implements LuaGcable {
    private OnReadLineListener a;
    private OnErrorListener b;
    private Socket c;
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
        private final Socket a;

        public SocketThread(Socket socket) {
            this.a = socket;
        }

        public boolean close() throws IOException {
            try {
                this.a.close();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.b == null) {
                    return false;
                }
                LuaClient.this.b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        public boolean flush() throws IOException {
            try {
                LuaClient.this.e.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.b == null) {
                    return false;
                }
                LuaClient.this.b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        public boolean newLine() throws IOException {
            try {
                LuaClient.this.e.newLine();
                LuaClient.this.e.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                if (LuaClient.this.b == null) {
                    return false;
                }
                LuaClient.this.b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() throws IOException {
            while (true) {
                try {
                    String line = LuaClient.this.d.readLine();
                    if (line == null) {
                        return;
                    }
                    if (LuaClient.this.a != null) {
                        LuaClient.this.a.onReadLine(LuaClient.this, this, line);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    if (LuaClient.this.b != null) {
                        LuaClient.this.b.onErrorLine(LuaClient.this, this, e.toString());
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
                if (LuaClient.this.b == null) {
                    return false;
                }
                LuaClient.this.b.onErrorLine(LuaClient.this, this, e.toString());
                return false;
            }
        }
    }

    public LuaClient() {
    }

    public LuaClient(LuaContext luaContext) {
        luaContext.regGc(this);
    }

    public boolean flush() throws IOException {
        try {
            this.e.flush();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }

    @Override // com.androlua.LuaGcable
    public void gc() throws IOException {
        stop();
        this.f = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.f;
    }

    public boolean newLine() throws IOException {
        try {
            this.e.newLine();
            this.e.flush();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }

    public void setOnReadLineListener(OnReadLineListener onReadLineListener) {
        this.a = onReadLineListener;
    }

    public boolean start(String str, int i) throws SocketException {
        if (this.c != null) {
            return false;
        }
        try {
            this.c = new Socket(str, i);
            this.c.setSoTimeout(3600000);
            this.d = new BufferedReader(new InputStreamReader(this.c.getInputStream()));
            this.e = new BufferedWriter(new OutputStreamWriter(this.c.getOutputStream()));
            new SocketThread(this.c).start();
            return true;
        } catch (IOException e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.b;
            if (onErrorListener != null) {
                onErrorListener.onErrorLine(this, null, e.toString());
            }
            return false;
        }
    }

    public boolean stop() throws IOException {
        Socket socket = this.c;
        if (socket == null) {
            return false;
        }
        try {
            socket.close();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            OnErrorListener onErrorListener = this.b;
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
            OnErrorListener onErrorListener = this.b;
            if (onErrorListener == null) {
                return false;
            }
            onErrorListener.onErrorLine(this, null, e.toString());
            return false;
        }
    }
}