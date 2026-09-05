package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class BIntegerType extends BObjectType<BInteger> {
    public static BIntegerType create50Type(int intSize) {
        return new BIntegerType50(intSize);
    }

    public static BIntegerType create54() {
        return new BIntegerType54();
    }

    public int getSize() {
        throw new IllegalStateException();
    }

    public BInteger create(int n) {
        return new BInteger(n);
    }
}