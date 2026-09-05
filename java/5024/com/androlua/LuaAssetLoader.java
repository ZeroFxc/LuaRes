package com.androlua;

import android.content.Context;
import com.luajava.JavaFunction;
import com.luajava.LuaState;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaAssetLoader extends JavaFunction {
    private LuaState b;
    private Context c;

    public LuaAssetLoader(LuaContext luaContext, LuaState luaState) {
        super(luaState);
        this.b = luaState;
        this.c = luaContext.getContext();
    }

    private static byte[] a(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(4096);
        byte[] bArr = new byte[4096];
        while (true) {
            int i = inputStream.read(bArr);
            if (-1 == i) {
                byte[] byteArray = byteArrayOutputStream.toByteArray();
                byteArrayOutputStream.close();
                return byteArray;
            }
            byteArrayOutputStream.write(bArr, 0, i);
        }
    }

    @Override // com.luajava.JavaFunction
    public int execute() {
        String str = this.b.toString(-1).replace('.', '/') + ".lua";
        try {
            if (this.b.LloadBuffer(readAsset(str), str) != 0) {
                this.b.pushString("\n\t" + this.b.toString(-1));
            }
            return 1;
        } catch (IOException unused) {
            this.b.pushString("\n\tno file '/assets/" + str + "'");
            return 1;
        }
    }

    public byte[] readAsset(String str) throws IOException {
        InputStream inputStreamOpen = this.c.getAssets().open(str);
        byte[] bArrA = a(inputStreamOpen);
        inputStreamOpen.close();
        return bArrA;
    }
}