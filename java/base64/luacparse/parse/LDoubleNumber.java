package base64.luacparse.parse;

import base64.luacparse.parse.LNumberType;

/* JADX INFO: compiled from: LNumber.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LDoubleNumber extends LNumber {
    public final LNumberType.NumberMode mode;
    public final double number;

    public LDoubleNumber(double number, LNumberType.NumberMode mode) {
        this.number = number;
        this.mode = mode;
    }

    @Override // base64.luacparse.parse.LNumber, base64.luacparse.parse.LObject
    public String toPrintString() {
        if (this.mode != LNumberType.NumberMode.MODE_NUMBER || this.number != Math.round(this.number)) {
            return Double.toString(this.number);
        }
        if (Double.doubleToRawLongBits(this.number) == Double.doubleToRawLongBits(-0.0d)) {
            return "-0";
        }
        return Long.toString((long) this.number);
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        return o instanceof LDoubleNumber ? Double.doubleToRawLongBits(this.number) == Double.doubleToRawLongBits(((LDoubleNumber) o).number) : (o instanceof LNumber) && value() == ((LNumber) o).value();
    }

    @Override // base64.luacparse.parse.LNumber
    public double value() {
        return this.number;
    }

    @Override // base64.luacparse.parse.LNumber
    public boolean integralType() {
        return false;
    }

    @Override // base64.luacparse.parse.LNumber
    public long bits() {
        return Double.doubleToRawLongBits(this.number);
    }
}