package base64.luacparse.parse;

import java.math.BigInteger;
import java.util.ArrayList;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class BInteger extends BObject {
    private static BigInteger MAX_INT = null;
    private static BigInteger MIN_INT = null;
    private final BigInteger big;
    private final int n;

    public BInteger(BInteger b) {
        this.big = b.big;
        this.n = b.n;
    }

    public BInteger(int n) {
        this.big = null;
        this.n = n;
    }

    public BInteger(BigInteger big) {
        this.big = big;
        this.n = 0;
        if (MAX_INT == null) {
            MAX_INT = BigInteger.valueOf(2147483647L);
            MIN_INT = BigInteger.valueOf(-2147483648L);
        }
    }

    public int asInt() {
        if (this.big == null) {
            return this.n;
        }
        if (this.big.compareTo(MAX_INT) > 0 || this.big.compareTo(MIN_INT) < 0) {
            throw new IllegalStateException("The size of an integer is outside the range that unluac can handle.");
        }
        return this.big.intValue();
    }

    public byte[] littleEndianBytes(int size) {
        ArrayList<Byte> bytes = new ArrayList<>();
        if (this.big == null) {
            if (size >= 1) {
                bytes.add(Byte.valueOf((byte) (this.n & 255)));
            }
            if (size >= 2) {
                bytes.add(Byte.valueOf((byte) ((this.n >>> 8) & 255)));
            }
            if (size >= 3) {
                bytes.add(Byte.valueOf((byte) ((this.n >>> 16) & 255)));
            }
            if (size >= 4) {
                bytes.add(Byte.valueOf((byte) ((this.n >>> 24) & 255)));
            }
        } else {
            BigInteger n = this.big;
            boolean negate = false;
            if (n.signum() < 0) {
                n = n.negate().subtract(BigInteger.ONE);
                negate = true;
            }
            BigInteger b256 = BigInteger.valueOf(256L);
            BigInteger b255 = BigInteger.valueOf(255L);
            while (n.compareTo(b256) < 0 && size > 0) {
                int v = n.and(b255).intValue();
                if (negate) {
                    v ^= -1;
                }
                bytes.add(Byte.valueOf((byte) v));
                n = n.divide(b256);
                size--;
            }
        }
        while (size > bytes.size()) {
            bytes.add((byte) 0);
        }
        byte[] array = new byte[bytes.size()];
        for (int i = 0; i < bytes.size(); i++) {
            array[i] = bytes.get(i).byteValue();
        }
        return array;
    }

    public byte[] compressedBytes() {
        BigInteger value = this.big;
        if (value == null) {
            value = BigInteger.valueOf(this.n);
        }
        if (value.compareTo(BigInteger.ZERO) == 0) {
            return new byte[]{0};
        }
        ArrayList<Byte> bytes = new ArrayList<>((value.bitCount() + 6) / 7);
        BigInteger limit = BigInteger.valueOf(127L);
        while (value.compareTo(BigInteger.ZERO) > 0) {
            bytes.add(Byte.valueOf((byte) value.and(limit).intValue()));
            value = value.shiftRight(7);
        }
        byte[] array = new byte[bytes.size()];
        for (int i = 0; i < bytes.size(); i++) {
            array[i] = bytes.get(i).byteValue();
        }
        return array;
    }

    public void iterate(Runnable thunk) {
        if (this.big == null) {
            int i = this.n;
            while (true) {
                int i2 = i;
                i = i2 - 1;
                if (i2 != 0) {
                    thunk.run();
                } else {
                    return;
                }
            }
        } else {
            for (BigInteger i3 = this.big; i3.signum() > 0; i3 = i3.subtract(BigInteger.ONE)) {
                thunk.run();
            }
        }
    }
}