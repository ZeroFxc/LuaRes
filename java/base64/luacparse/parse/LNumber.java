package base64.luacparse.parse;

import base64.luacparse.parse.LNumberType;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LNumber extends LObject {
    public abstract long bits();

    public abstract boolean integralType();

    @Override // base64.luacparse.parse.LObject
    public abstract String toPrintString();

    public abstract double value();

    public static LNumber makeInteger(int number) {
        return new LIntNumber(number);
    }

    public static LNumber makeDouble(double x) {
        return new LDoubleNumber(x, LNumberType.NumberMode.MODE_FLOAT);
    }
}