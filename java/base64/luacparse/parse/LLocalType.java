package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LLocalType extends BObjectType<LLocal> {
    @Override // base64.luacparse.parse.BObjectType
    public LLocal parse(ByteBuffer buffer, BHeader header) {
        LString name = header.string.parse(buffer, header);
        BInteger start = header.integer.parse(buffer, header);
        BInteger end = header.integer.parse(buffer, header);
        Objects.requireNonNull(header);
        return new LLocal(name, start, end);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LLocal object) throws IOException {
        header.string.write(out, header, object.name);
        header.integer.write(out, header, new BInteger(object.start));
        header.integer.write(out, header, new BInteger(object.end));
    }
}