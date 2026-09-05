package base64.luacparse.parse;

import base64.luacparse.decompile.OpV;
import base64.luacparse.parse.LHeader;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.util.Objects;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LNumberType extends BObjectType<LNumber> {
    public final boolean integral;
    public final NumberMode mode;
    public final int size;

    public enum NumberMode {
        MODE_NUMBER,
        MODE_FLOAT,
        MODE_INTEGER
    }

    public LNumberType(int size, boolean integral, NumberMode mode) {
        this.size = size;
        this.integral = integral;
        this.mode = mode;
        if (size != 4 && size != 8) {
            throw new IllegalStateException("The input chunk has an unsupported Lua number size: " + size);
        }
    }

    public double convert(double number) {
        if (this.integral) {
            switch (this.size) {
                case OpV.LUA52 /* 4 */:
                    return (int) number;
                case OpV.LUA53 /* 8 */:
                    return (long) number;
            }
        }
        switch (this.size) {
            case OpV.LUA52 /* 4 */:
                return (float) number;
            case OpV.LUA53 /* 8 */:
                return number;
        }
        throw new IllegalStateException("The input chunk has an unsupported Lua number format");
    }

    @Override // base64.luacparse.parse.BObjectType
    public LNumber parse(ByteBuffer buffer, BHeader header) {
        LNumber value = null;
        if (this.integral) {
            switch (this.size) {
                case OpV.LUA52 /* 4 */:
                    value = new LIntNumber(buffer.getInt());
                    break;
                case OpV.LUA53 /* 8 */:
                    value = new LLongNumber(buffer.getLong());
                    break;
            }
        } else {
            switch (this.size) {
                case OpV.LUA52 /* 4 */:
                    value = new LFloatNumber(buffer.getFloat(), this.mode);
                    break;
                case OpV.LUA53 /* 8 */:
                    value = new LDoubleNumber(buffer.getDouble(), this.mode);
                    break;
            }
        }
        if (value == null) {
            throw new IllegalStateException("The input chunk has an unsupported Lua number format");
        }
        Objects.requireNonNull(header);
        return value;
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LNumber n) throws IOException {
        long bits = n.bits();
        if (header.lheader.endianness == LHeader.LEndianness.LITTLE) {
            for (int i = 0; i < this.size; i++) {
                out.write((byte) (bits & 255));
                bits >>>= 8;
            }
            return;
        }
        for (int i2 = this.size - 1; i2 >= 0; i2--) {
            out.write((byte) ((bits >> (i2 * 8)) & 255));
        }
    }

    public LNumber create(double x) {
        if (this.integral) {
            switch (this.size) {
                case OpV.LUA52 /* 4 */:
                    return new LIntNumber((int) x);
                case OpV.LUA53 /* 8 */:
                    return new LLongNumber((long) x);
                default:
                    throw new IllegalStateException();
            }
        }
        switch (this.size) {
            case OpV.LUA52 /* 4 */:
                return new LFloatNumber((float) x, this.mode);
            case OpV.LUA53 /* 8 */:
                return new LDoubleNumber(x, this.mode);
            default:
                throw new IllegalStateException();
        }
    }

    public LNumber create(BigInteger x) {
        if (this.integral) {
            switch (this.size) {
                case OpV.LUA52 /* 4 */:
                    if (x.compareTo(BigInteger.valueOf(2147483647L)) > 0) {
                        throw new RuntimeException("intValueExact error!");
                    }
                    return new LIntNumber(x.intValue());
                case OpV.LUA53 /* 8 */:
                    if (x.compareTo(BigInteger.valueOf(Long.MAX_VALUE)) > 0) {
                        throw new RuntimeException("intValueExact error!");
                    }
                    return new LLongNumber(x.longValue());
                default:
                    throw new IllegalStateException();
            }
        }
        switch (this.size) {
            case OpV.LUA52 /* 4 */:
                return new LFloatNumber(x.floatValue(), this.mode);
            case OpV.LUA53 /* 8 */:
                return new LDoubleNumber(x.doubleValue(), this.mode);
            default:
                throw new IllegalStateException();
        }
    }
}