package com.luajava;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\andlua.dex */
public class LuaString implements CharSequence {
    private byte[] a;

    public LuaString(String str) {
        this.a = new byte[0];
        this.a = str.getBytes();
    }

    public LuaString(byte[] bArr) {
        this.a = new byte[0];
        this.a = bArr;
    }

    @Override // java.lang.CharSequence
    public char charAt(int i) {
        return (char) this.a[i];
    }

    @Override // java.lang.CharSequence
    public int length() {
        return this.a.length;
    }

    @Override // java.lang.CharSequence
    public CharSequence subSequence(int i, int i2) {
        return new String(this.a, i, i2);
    }

    public byte[] toByteArray() {
        return this.a;
    }

    @Override // java.lang.CharSequence
    public String toString() {
        return new String(this.a);
    }
}