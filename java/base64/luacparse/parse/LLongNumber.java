package base64.luacparse.parse;

/* JADX INFO: compiled from: LNumber.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LLongNumber extends LNumber {
    public final long number;

    public LLongNumber(long number) {
        this.number = number;
    }

    @Override // base64.luacparse.parse.LNumber, base64.luacparse.parse.LObject
    public String toPrintString() {
        return Long.toString(this.number);
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        return o instanceof LLongNumber ? this.number == ((LLongNumber) o).number : (o instanceof LNumber) && value() == ((LNumber) o).value();
    }

    @Override // base64.luacparse.parse.LNumber
    public double value() {
        return this.number;
    }

    @Override // base64.luacparse.parse.LNumber
    public boolean integralType() {
        return true;
    }

    @Override // base64.luacparse.parse.LNumber
    public long bits() {
        return this.number;
    }
}