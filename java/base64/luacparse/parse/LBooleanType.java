package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LBooleanType extends BObjectType<LBoolean> {
    @Override // base64.luacparse.parse.BObjectType
    public LBoolean parse(ByteBuffer buffer, BHeader header) {
        int value = buffer.get();
        if ((value & (-2)) != 0) {
            throw new IllegalStateException();
        }
        LBoolean bool = value == 0 ? LBoolean.LFALSE : LBoolean.LTRUE;
        Objects.requireNonNull(header);
        return bool;
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LBoolean object) throws IOException {
        int value = object.value() ? 1 : 0;
        out.write(value);
    }
}