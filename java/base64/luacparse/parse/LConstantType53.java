package base64.luacparse.parse;

import base64.luacparse.decompile.OpV;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: compiled from: LConstantType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LConstantType53 extends LConstantType {
    LConstantType53() {
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
            case 3:
                return header.lfloat.parse(buffer, header);
            case OpV.LUA52 /* 4 */:
                return header.string.parse(buffer, header);
            case 19:
                return header.linteger.parse(buffer, header);
            case 20:
                LString s = header.string.parse(buffer, header);
                s.islong = true;
                return s;
            default:
                throw new IllegalStateException();
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
            return;
        }
        if (object instanceof LNumber) {
            LNumber n = (LNumber) object;
            if (!n.integralType()) {
                out.write(3);
                header.lfloat.write(out, header, (LNumber) object);
                return;
            } else {
                out.write(19);
                header.linteger.write(out, header, (LNumber) object);
                return;
            }
        }
        if (object instanceof LString) {
            LString s = (LString) object;
            out.write(s.islong ? 20 : 4);
            header.string.write(out, header, s);
            return;
        }
        throw new IllegalStateException();
    }
}