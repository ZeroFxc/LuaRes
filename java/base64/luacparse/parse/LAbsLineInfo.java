package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LAbsLineInfo extends LObject {
    public final int line;
    public final int pc;

    public LAbsLineInfo(int pc, int line) {
        this.pc = pc;
        this.line = line;
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        if (!(o instanceof LAbsLineInfo)) {
            return false;
        }
        LAbsLineInfo other = (LAbsLineInfo) o;
        return this.pc == other.pc && this.line == other.line;
    }
}