package com.luajava;

import com.a.a.a.a.a.a.a;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintStream;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Console {
    public static void main(String[] strArr) {
        try {
            LuaState luaStateNewLuaState = LuaStateFactory.newLuaState();
            luaStateNewLuaState.openLibs();
            if (strArr.length > 0) {
                for (int i = 0; i < strArr.length; i++) {
                    int iLloadFile = luaStateNewLuaState.LloadFile(strArr[i]);
                    if (iLloadFile == 0) {
                        iLloadFile = luaStateNewLuaState.pcall(0, 0, 0);
                    }
                    if (iLloadFile != 0) {
                        throw new LuaException("Error on file: " + strArr[i] + ". " + luaStateNewLuaState.toString(-1));
                    }
                }
                return;
            }
            System.out.println("API Lua Java - console mode.");
            BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(System.in));
            PrintStream printStream = System.out;
            String str = "> ";
            while (true) {
                printStream.print(str);
                String line = bufferedReader.readLine();
                if (line == null || line.equals("exit")) {
                    break;
                }
                int iLloadBuffer = luaStateNewLuaState.LloadBuffer(line.getBytes(), "from console");
                if (iLloadBuffer == 0) {
                    iLloadBuffer = luaStateNewLuaState.pcall(0, 0, 0);
                }
                if (iLloadBuffer != 0) {
                    System.err.println("Error on line: " + line);
                    System.err.println(luaStateNewLuaState.toString(-1));
                }
                printStream = System.out;
                str = "> ";
            }
            luaStateNewLuaState.close();
        } catch (Exception e) {
            a.a(e);
        }
    }
}