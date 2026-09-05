package com.androlua;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.ServerSocket;
import java.net.Socket;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaServer implements LuaGcable {
    private ServerSocket a;
    private OnReadLineListener b;
    private boolean c;

    public interface OnReadLineListener {
        void onReadLine(LuaServer luaServer, SocketThread socketThread, String str);
    }

    private class ServerThread extends Thread {
        private final ServerSocket a;

        public ServerThread(ServerSocket serverSocket) {
            this.a = serverSocket;
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() throws IOException {
            while (true) {
                try {
                    LuaServer.this.new SocketThread(LuaServer.this.a.accept()).start();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
    }

    private class SocketThread extends Thread {
        private final Socket a;
        private BufferedWriter b;

        public SocketThread(Socket socket) {
            this.a = socket;
        }

        public boolean close() throws IOException {
            try {
                this.a.close();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        public boolean flush() throws IOException {
            try {
                this.b.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        public boolean newLine() throws IOException {
            try {
                this.b.newLine();
                this.b.flush();
                return true;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        @Override // java.lang.Thread, java.lang.Runnable
        public void run() throws IOException {
            try {
                BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(this.a.getInputStream()));
                this.b = new BufferedWriter(new OutputStreamWriter(this.a.getOutputStream()));
                while (true) {
                    String line = bufferedReader.readLine();
                    if (line == null) {
                        return;
                    }
                    if (LuaServer.this.b != null) {
                        LuaServer.this.b.onReadLine(LuaServer.this, this, line);
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        public boolean write(String str) {
            try {
                this.b.write(str);
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
    public void gc() throws IOException {
        ServerSocket serverSocket = this.a;
        if (serverSocket == null) {
            return;
        }
        try {
            serverSocket.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        this.c = true;
    }

    @Override // com.androlua.LuaGcable
    public boolean isGc() {
        return this.c;
    }

    public void setOnReadLineListener(OnReadLineListener onReadLineListener) {
        this.b = onReadLineListener;
    }

    public boolean start(int i) {
        if (this.a != null) {
            return false;
        }
        try {
            this.a = new ServerSocket(i);
            new ServerThread(this.a).start();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public boolean stop() throws IOException {
        try {
            this.a.close();
            this.a = null;
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}