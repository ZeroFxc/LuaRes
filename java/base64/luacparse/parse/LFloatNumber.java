package base64.luacparse.parse;

import base64.luacparse.parse.LNumberType;

/* JADX INFO: compiled from: LNumber.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LFloatNumber extends LNumber {
    public final LNumberType.NumberMode mode;
    public final float number;

    public LFloatNumber(float number, LNumberType.NumberMode mode) {
        this.number = number;
        this.mode = mode;
    }

    @Override // base64.luacparse.parse.LNumber, base64.luacparse.parse.LObject
    public String toPrintString() {
        if (this.mode == LNumberType.NumberMode.MODE_NUMBER && this.number == Math.round(this.number)) {
            if (Float.floatToRawIntBits(this.number) == Float.floatToRawIntBits(-0.0f)) {
                return "-0";
            }
            return Integer.toString((int) this.number);
        }
        return Float.toString(this.number);
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        return o instanceof LFloatNumber ? Float.floatToRawIntBits(this.number) == Float.floatToRawIntBits(((LFloatNumber) o).number) : (o instanceof LNumber) && value() == ((LNumber) o).value();
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
        return Float.floatToRawIntBits(this.number);
    }
}