package base64.luacparse.parse;

import base64.luacparse.decompile.OpV;
import base64.luacparse.parse.LHeader;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Objects;

/* JADX INFO: compiled from: BIntegerType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class BIntegerType50 extends BIntegerType {
    public final int intSize;

    public BIntegerType50(int intSize) {
        this.intSize = intSize;
    }

    protected BInteger raw_parse(ByteBuffer buffer, BHeader header) {
        switch (this.intSize) {
            case 0:
                BInteger value = new BInteger(0);
                return value;
            case OpV.LUA50 /* 1 */:
                BInteger value2 = new BInteger(buffer.get());
                return value2;
            case OpV.LUA51 /* 2 */:
                BInteger value3 = new BInteger(buffer.getShort());
                return value3;
            case 3:
            default:
                byte[] bytes = new byte[this.intSize];
                int start = 0;
                int delta = 1;
                if (buffer.order() == ByteOrder.LITTLE_ENDIAN) {
                    start = this.intSize - 1;
                    delta = -1;
                }
                for (int i = start; i >= 0 && i < this.intSize; i += delta) {
                    bytes[i] = buffer.get();
                }
                BInteger value4 = new BInteger(new BigInteger(bytes));
                return value4;
            case OpV.LUA52 /* 4 */:
                BInteger value5 = new BInteger(buffer.getInt());
                return value5;
        }
    }

    protected void raw_write(OutputStream out, BHeader header, BInteger object) throws IOException {
        byte[] bytes = object.littleEndianBytes(this.intSize);
        if (header.lheader.endianness == LHeader.LEndianness.LITTLE) {
            for (byte b : bytes) {
                out.write(b);
            }
            return;
        }
        for (int i = bytes.length - 1; i >= 0; i--) {
            out.write(bytes[i]);
        }
    }

    @Override // base64.luacparse.parse.BObjectType
    public BInteger parse(ByteBuffer buffer, BHeader header) {
        BInteger value = raw_parse(buffer, header);
        Objects.requireNonNull(header);
        return value;
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, BInteger object) throws IOException {
        raw_write(out, header, object);
    }

    @Override // base64.luacparse.parse.BIntegerType
    public int getSize() {
        return this.intSize;
    }
}