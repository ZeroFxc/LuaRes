package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaString implements CharSequence {

    /* JADX INFO: renamed from: a */
    private byte[] f1193a;

    public LuaString(String str) {
        this.f1193a = new byte[0];
        this.f1193a = str.getBytes();
    }

    public LuaString(byte[] bArr) {
        this.f1193a = new byte[0];
        this.f1193a = bArr;
    }

    @Override // java.lang.CharSequence
    public char charAt(int i) {
        return (char) this.f1193a[i];
    }

    @Override // java.lang.CharSequence
    public int length() {
        return this.f1193a.length;
    }

    @Override // java.lang.CharSequence
    public CharSequence subSequence(int i, int i2) {
        return new String(this.f1193a, i, i2);
    }

    public byte[] toByteArray() {
        return this.f1193a;
    }

    @Override // java.lang.CharSequence
    public String toString() {
        return new String(this.f1193a);
    }
}