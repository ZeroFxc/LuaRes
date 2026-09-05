package com.nwdxlgzs.luac53support;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class DecTool extends defines {
    public static byte[] decrypt(byte[] bArr, DecInterface decInterface) {
        DecInterface decInterface2 = decInterface;
        if (decInterface2 == null) {
            decInterface2 = defines.NULL_Decoder;
        }
        byte[] bArrLuaCPreProcess = decInterface2.LuaCPreProcess(bArr);
        if (!decInterface2.requireLuaCParse()) {
            return decInterface2.LuaCPostProcess(bArrLuaCPreProcess);
        }
        return decInterface2.LuaCPostProcess(new Dump(decInterface2.ProtoScan(new Undump(bArrLuaCPreProcess, decInterface2).parse()), decInterface2).getBytes());
    }
}