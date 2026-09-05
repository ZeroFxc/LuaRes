package base64.luacparse.parse;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;

/* JADX INFO: compiled from: BIntegerType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class BIntegerType54 extends BIntegerType {
    @Override // base64.luacparse.parse.BObjectType
    public BInteger parse(ByteBuffer buffer, BHeader header) {
        byte b;
        long x = 0;
        do {
            b = buffer.get();
            x = (x << 7) | ((long) (b & 127));
        } while ((b & 128) == 0);
        return (-2147483648L > x || x > 2147483647L) ? new BInteger(BigInteger.valueOf(x)) : new BInteger((int) x);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, BInteger object) throws IOException {
        byte[] bytes = object.compressedBytes();
        for (int i = bytes.length - 1; i >= 1; i--) {
            out.write(bytes[i]);
        }
        out.write(bytes[0] | 128);
    }
}