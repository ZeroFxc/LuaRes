package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LNil extends LObject {
    public static final LNil NIL = new LNil();

    private LNil() {
    }

    @Override // base64.luacparse.parse.LObject
    public String toPrintString() {
        return "nil";
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        return this == o;
    }
}