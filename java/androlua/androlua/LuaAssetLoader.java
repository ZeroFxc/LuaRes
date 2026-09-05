package com.androlua;

import android.content.Context;
import com.luajava.JavaFunction;
import com.luajava.LuaState;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaAssetLoader extends JavaFunction {

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaState f748b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private Context f749c;

    public LuaAssetLoader(LuaContext luaContext, LuaState luaState) {
        super(luaState);
        this.f748b = luaState;
        this.f749c = luaContext.getContext();
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
        String str = this.f748b.toString(-1).replace('.', '/') + ".lua";
        try {
            if (this.f748b.LloadBuffer(readAsset(str), str) != 0) {
                this.f748b.pushString("\n\t" + this.f748b.toString(-1));
            }
            return 1;
        } catch (IOException unused) {
            this.f748b.pushString("\n\tno file '/assets/" + str + "'");
            return 1;
        }
    }

    public byte[] readAsset(String str) throws IOException {
        InputStream inputStreamOpen = this.f749c.getAssets().open(str);
        byte[] bArrA = a(inputStreamOpen);
        inputStreamOpen.close();
        return bArrA;
    }
}