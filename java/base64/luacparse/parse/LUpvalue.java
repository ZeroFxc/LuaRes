package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LUpvalue extends BObject {
    public LString bname;
    public int idx;
    public boolean instack;
    public int kind;
    public String name;

    public boolean equals(Object obj) {
        if (!(obj instanceof LUpvalue)) {
            return false;
        }
        LUpvalue upvalue = (LUpvalue) obj;
        if (this.instack != upvalue.instack || this.idx != upvalue.idx || this.kind != upvalue.kind) {
            return false;
        }
        if (this.name != upvalue.name) {
            return this.name != null && this.name.equals(upvalue.name);
        }
        return true;
    }
}