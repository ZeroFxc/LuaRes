package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LBoolean extends LObject {
    private final boolean value;
    public static final LBoolean LTRUE = new LBoolean(true);
    public static final LBoolean LFALSE = new LBoolean(false);

    private LBoolean(boolean value) {
        this.value = value;
    }

    public boolean value() {
        return this.value;
    }

    @Override // base64.luacparse.parse.LObject
    public String toPrintString() {
        return Boolean.toString(this.value);
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        return this == o;
    }
}