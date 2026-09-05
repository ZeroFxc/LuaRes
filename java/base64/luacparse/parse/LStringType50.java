package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: compiled from: LStringType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LStringType50 extends LStringType {
    LStringType50() {
    }

    @Override // base64.luacparse.parse.BObjectType
    public LString parse(final ByteBuffer buffer, BHeader header) {
        BInteger sizeT = header.sizeT.parse(buffer, header);
        final StringBuilder b = this.b.get();
        b.setLength(0);
        sizeT.iterate(new Runnable() { // from class: base64.luacparse.parse.LStringType50.1
            @Override // java.lang.Runnable
            public void run() {
                b.append((char) (buffer.get() & 255));
            }
        });
        if (b.length() == 0) {
            return LString.NULL;
        }
        char last = b.charAt(b.length() - 1);
        if (last != 0) {
            throw new IllegalStateException("String value does not have a null terminator");
        }
        b.delete(b.length() - 1, b.length());
        String s = b.toString();
        Objects.requireNonNull(header);
        return new LString(s);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LString string) throws IOException {
        int len = string.value.length();
        if (string == LString.NULL) {
            header.sizeT.write(out, header, header.sizeT.create(0));
            return;
        }
        header.sizeT.write(out, header, header.sizeT.create(len + 1));
        for (int i = 0; i < len; i++) {
            out.write(string.value.charAt(i));
        }
        out.write(0);
    }
}