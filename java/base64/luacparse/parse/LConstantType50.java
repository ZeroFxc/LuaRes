package base64.luacparse.parse;

import base64.luacparse.decompile.OpV;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: compiled from: LConstantType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LConstantType50 extends LConstantType {
    LConstantType50() {
    }

    @Override // base64.luacparse.parse.BObjectType
    public LObject parse(ByteBuffer buffer, BHeader header) {
        int type = buffer.get() & 255;
        Objects.requireNonNull(header);
        switch (type) {
            case 0:
                return LNil.NIL;
            case OpV.LUA50 /* 1 */:
                return header.bool.parse(buffer, header);
            case OpV.LUA51 /* 2 */:
            default:
                throw new IllegalStateException();
            case 3:
                return header.number.parse(buffer, header);
            case OpV.LUA52 /* 4 */:
                return header.string.parse(buffer, header);
        }
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LObject object) throws IOException {
        if (object instanceof LNil) {
            out.write(0);
            return;
        }
        if (object instanceof LBoolean) {
            out.write(1);
            header.bool.write(out, header, (LBoolean) object);
        } else if (object instanceof LNumber) {
            out.write(3);
            header.number.write(out, header, (LNumber) object);
        } else {
            if (object instanceof LString) {
                out.write(4);
                header.string.write(out, header, (LString) object);
                return;
            }
            throw new IllegalStateException();
        }
    }
}