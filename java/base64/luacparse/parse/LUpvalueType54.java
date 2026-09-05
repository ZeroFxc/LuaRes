package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;

/* JADX INFO: compiled from: LUpvalueType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LUpvalueType54 extends LUpvalueType {
    LUpvalueType54() {
    }

    @Override // base64.luacparse.parse.BObjectType
    public LUpvalue parse(ByteBuffer buffer, BHeader header) {
        LUpvalue upvalue = new LUpvalue();
        upvalue.instack = buffer.get() != 0;
        upvalue.idx = buffer.get() & 255;
        upvalue.kind = buffer.get() & 255;
        return upvalue;
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LUpvalue object) throws IOException {
        out.write((byte) (object.instack ? 1 : 0));
        out.write(object.idx);
        out.write(object.kind);
    }
}