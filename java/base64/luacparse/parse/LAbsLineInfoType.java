package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LAbsLineInfoType extends BObjectType<LAbsLineInfo> {
    @Override // base64.luacparse.parse.BObjectType
    public LAbsLineInfo parse(ByteBuffer buffer, BHeader header) {
        int pc = header.integer.parse(buffer, header).asInt();
        int line = header.integer.parse(buffer, header).asInt();
        return new LAbsLineInfo(pc, line);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LAbsLineInfo object) throws IOException {
        header.integer.write(out, header, new BInteger(object.pc));
        header.integer.write(out, header, new BInteger(object.line));
    }
}