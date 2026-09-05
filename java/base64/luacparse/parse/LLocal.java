package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LLocal extends BObject {
    public final int end;
    public boolean forLoop = false;
    public final LString name;
    public final int start;

    public LLocal(LString name, BInteger start, BInteger end) {
        this.name = name;
        this.start = start.asInt();
        this.end = end.asInt();
    }

    public String toString() {
        return this.name.deref();
    }
}