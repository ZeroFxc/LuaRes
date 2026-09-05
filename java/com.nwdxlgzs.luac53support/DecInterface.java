package com.nwdxlgzs.luac53support;

import java.util.HashMap;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public interface DecInterface {
    byte[] BlockDecrypt(byte[] bArr);

    boolean BooleanDecrypt(boolean z);

    byte ByteDecrypt(byte b);

    Instruction InstructionDecrypt(Instruction instruction);

    int IntDecrypt(int i);

    long IntegerDecrypt(long j);

    byte[] LuaCPostProcess(byte[] bArr);

    byte[] LuaCPreProcess(byte[] bArr);

    int NDecrypt(int i, String str);

    double NumberDecrypt(double d);

    HashMap<Integer, Integer> OPMapReplace();

    Proto ProtoScan(Proto proto);

    byte[] StringDecrypt(byte[] bArr);

    boolean requireLuaCParse();

    boolean requireStrip();
}