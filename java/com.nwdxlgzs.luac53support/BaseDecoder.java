package com.nwdxlgzs.luac53support;

import java.util.HashMap;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class BaseDecoder implements DecInterface {
    @Override // com.nwdxlgzs.luac53support.DecInterface
    public boolean requireLuaCParse() {
        return false;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public boolean requireStrip() {
        return false;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public byte[] LuaCPreProcess(byte[] bArr) {
        return bArr;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public byte[] LuaCPostProcess(byte[] bArr) {
        return bArr;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public byte[] StringDecrypt(byte[] bArr) {
        return bArr;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public boolean BooleanDecrypt(boolean z) {
        return z;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public long IntegerDecrypt(long j) {
        return j;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public double NumberDecrypt(double d) {
        return d;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public Instruction InstructionDecrypt(Instruction instruction) {
        return instruction;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public HashMap<Integer, Integer> OPMapReplace() {
        return (HashMap) null;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public int IntDecrypt(int i) {
        return i;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public int NDecrypt(int i, String str) {
        return i;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public byte ByteDecrypt(byte b) {
        return b;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public byte[] BlockDecrypt(byte[] bArr) {
        return bArr;
    }

    @Override // com.nwdxlgzs.luac53support.DecInterface
    public Proto ProtoScan(Proto proto) {
        return proto;
    }
}