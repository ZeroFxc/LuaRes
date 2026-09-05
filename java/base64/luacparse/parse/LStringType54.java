package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: compiled from: LStringType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LStringType54 extends LStringType {
    LStringType54() {
    }

    @Override // base64.luacparse.parse.BObjectType
    public LString parse(final ByteBuffer buffer, BHeader header) {
        BInteger sizeT = header.sizeT.parse(buffer, header);
        final StringBuilder b = this.b.get();
        b.setLength(0);
        sizeT.iterate(new Runnable() { // from class: base64.luacparse.parse.LStringType54.1
            boolean first = true;

            @Override // java.lang.Runnable
            public void run() {
                if (!this.first) {
                    b.append((char) (buffer.get() & 255));
                } else {
                    this.first = false;
                }
            }
        });
        String s = b.toString();
        Objects.requireNonNull(header);
        return new LString(s);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LString string) throws IOException {
        header.sizeT.write(out, header, header.sizeT.create(string.value.length() + 1));
        for (int i = 0; i < string.value.length(); i++) {
            out.write(string.value.charAt(i));
        }
    }
}