package com.androlua;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.ServerSocket;
import java.net.Socket;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaServer implements LuaGcable {

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private ServerSocket f836a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private OnReadLineListener f837b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private boolean f838c;

    public interface OnReadLineListener {
        void onReadLine(LuaServer luaServer, SocketThread socketThread, String str);
    }

    private class ServerThread extends Thread {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private final ServerSocket f839a;

        public ServerThread(ServerSocket serverSocket) {
            this.f839a = serverSocket;
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            while (true) {
                try {
                    LuaServer.this.new SocketThread(LuaServer.this.f836a.accept()).start();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
    }

    private class SocketThread extends Thread {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private final Socket f841a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private BufferedWriter f842b;

        public SocketThread(Socket socket) {
            this.f841a = socket;
        }

        public boolean close() {
            try {
                this.f841a.close();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        public boolean flush() {
            try {
                this.f842b.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        public boolean newLine() {
            try {
                this.f842b.newLine();
                this.f842b.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() {
            try {
                BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(this.f841a.getInputStream()));
                this.f842b = new BufferedWriter(new OutputStreamWriter(this.f841a.getOutputStream()));
                while (true) {
                    String line = bufferedReader.readLine();
                    if (line == null) {
                        return;
                    }
                    if (LuaServer.this.f837b != null) {
                        LuaServer.this.f837b.onReadLine(LuaServer.this, this, line);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        public boolean write(String str) {
            try {
                this.f842b.write(str);
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }
    }

    public LuaServer() {
    }

    public LuaServer(LuaContext luaContext) {
        luaContext.regGc(this);
    }

    @Override // com.androlua.LuaGcable
    public void gc() {
        ServerSocket serverSocket = this.f836a;
        if (serverSocket == null) {
            return;
        }
        try {
            serverSocket.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        this.f838c = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.f838c;
    }

    public void setOnReadLineListener(OnReadLineListener onReadLineListener) {
        this.f837b = onReadLineListener;
    }

    public boolean start(int i) {
        if (this.f836a != null) {
            return false;
        }
        try {
            this.f836a = new ServerSocket(i);
            new ServerThread(this.f836a).start();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public boolean stop() {
        try {
            this.f836a.close();
            this.f836a = null;
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}