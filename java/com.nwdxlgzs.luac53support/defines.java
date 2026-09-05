package com.nwdxlgzs.luac53support;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class defines {
    public static final DecInterface NULL_Decoder = new BaseDecoder();
    public static byte[] LUA_SIGNATURE = {(byte) 27, (byte) 76, (byte) 117, (byte) 97};
    public static byte[] LUAC_VERSION = {(byte) 83};
    public static byte[] LUAC_FORMAT = {(byte) 0};
    public static byte[] LUAC_DATA = {(byte) 25, -109, (byte) 13, (byte) 10, (byte) 26, (byte) 10};
    public static byte[] LUAC_INT = {(byte) 120, (byte) 86, (byte) 0, (byte) 0, (byte) 0, (byte) 0, (byte) 0, (byte) 0};
    public static byte[] LUAC_NUM = {(byte) 0, (byte) 0, (byte) 0, (byte) 0, (byte) 0, (byte) 40, (byte) 119, (byte) 64};
    public static int sizeof_int = 4;
    public static int sizeof_size_t = 4;
    public static int sizeof_Instruction = 4;
    public static int sizeof_lua_Integer = 8;
    public static int sizeof_lua_Number = 8;
    public static int SIZE_C = 9;
    public static int SIZE_B = 9;
    public static int SIZE_Bx = SIZE_C + SIZE_B;
    public static int SIZE_A = 8;
    public static int SIZE_Ax = (SIZE_C + SIZE_B) + SIZE_A;
    public static int SIZE_OP = 6;
    public static int POS_OP = 0;
    public static int POS_A = POS_OP + SIZE_OP;
    public static int POS_C = POS_A + SIZE_A;
    public static int POS_B = POS_C + SIZE_C;
    public static int POS_Bx = POS_C;
    public static int POS_Ax = POS_A;
    public static int MAXARG_Bx = (1 << SIZE_Bx) - 1;
    public static int MAXARG_sBx = MAXARG_Bx >> 1;
    public static int MAXARG_Ax = (1 << SIZE_Ax) - 1;
    public static int MAXARG_A = (1 << SIZE_A) - 1;
    public static int MAXARG_B = (1 << SIZE_B) - 1;
    public static int MAXARG_C = (1 << SIZE_C) - 1;
    public static int BITRK = 1 << (SIZE_B - 1);
    public static int MAXINDEXRK = BITRK - 1;
    public static int NO_REG = MAXARG_A;

    public static int MASK1(int i, int i2) {
        return (((-1) << i) ^ (-1)) << i2;
    }

    public static int MASK0(int i, int i2) {
        return MASK1(i, i2) ^ (-1);
    }

    public static int GET_OPCODE(int i) {
        return (i >> POS_OP) & MASK1(SIZE_OP, 0);
    }

    public static int SET_OPCODE(int i, int i2) {
        return (i & MASK0(SIZE_OP, POS_OP)) | ((i2 << POS_OP) & MASK1(SIZE_OP, POS_OP));
    }

    public static int getarg(int i, int i2, int i3) {
        return (i >> i2) & MASK1(i3, 0);
    }

    public static int setarg(int i, int i2, int i3, int i4) {
        return (i & MASK0(i4, i3)) | ((i2 << i3) & MASK1(i4, i3));
    }

    public static int GETARG_A(int i) {
        return getarg(i, POS_A, SIZE_A);
    }

    public static int SETARG_A(int i, int i2) {
        return setarg(i, i2, POS_A, SIZE_A);
    }

    public static int GETARG_B(int i) {
        return getarg(i, POS_B, SIZE_B);
    }

    public static int SETARG_B(int i, int i2) {
        return setarg(i, i2, POS_B, SIZE_B);
    }

    public static int GETARG_C(int i) {
        return getarg(i, POS_C, SIZE_C);
    }

    public static int SETARG_C(int i, int i2) {
        return setarg(i, i2, POS_C, SIZE_C);
    }

    public static int GETARG_Bx(int i) {
        return getarg(i, POS_Bx, SIZE_Bx);
    }

    public static int SETARG_Bx(int i, int i2) {
        return setarg(i, i2, POS_Bx, SIZE_Bx);
    }

    public static int GETARG_sBx(int i) {
        return GETARG_Bx(i) - MAXARG_sBx;
    }

    public static int SETARG_sBx(int i, int i2) {
        return SETARG_Bx(i, i2 + MAXARG_sBx);
    }

    public static int GETARG_Ax(int i) {
        return getarg(i, POS_Ax, SIZE_Ax);
    }

    public static int SETARG_Ax(int i, int i2) {
        return setarg(i, i2, POS_Ax, SIZE_Ax);
    }

    public static int CREATE_ABC(int i, int i2, int i3, int i4) {
        return SET_OPCODE(0, i) | SETARG_A(0, i2) | SETARG_B(0, i3) | SETARG_C(0, i4);
    }

    public static int CREATE_ABx(int i, int i2, int i3) {
        return SET_OPCODE(0, i) | SETARG_A(0, i2) | SETARG_Bx(0, i3);
    }

    public static int CREATE_AsBx(int i, int i2, int i3) {
        return SET_OPCODE(0, i) | SETARG_A(0, i2) | SETARG_sBx(0, i3);
    }

    public static int CREATE_Ax(int i, int i2) {
        return SET_OPCODE(0, i) | SETARG_Ax(0, i2);
    }

    public static int ISK(int i) {
        return i & BITRK;
    }

    public static int INDEXK(long j) {
        return ((int) j) & (BITRK ^ (-1));
    }

    public static int RKASK(int i) {
        return i | BITRK;
    }

    public static void rebindInstructionStructure() {
        SIZE_Bx = SIZE_C + SIZE_B;
        SIZE_Ax = SIZE_C + SIZE_B + SIZE_A;
        POS_A = POS_OP + SIZE_OP;
        POS_C = POS_A + SIZE_A;
        POS_B = POS_C + SIZE_C;
        POS_Bx = POS_C;
        POS_Ax = POS_A;
        MAXARG_Bx = (1 << SIZE_Bx) - 1;
        MAXARG_sBx = MAXARG_Bx >> 1;
        MAXARG_Ax = (1 << SIZE_Ax) - 1;
        MAXARG_A = (1 << SIZE_A) - 1;
        MAXARG_B = (1 << SIZE_B) - 1;
        MAXARG_C = (1 << SIZE_C) - 1;
        BITRK = 1 << (SIZE_B - 1);
        MAXINDEXRK = BITRK - 1;
        NO_REG = MAXARG_A;
    }

    public static byte[] FLT2bytes(double d) {
        byte[] bArr = new byte[sizeof_lua_Number];
        long jDoubleToRawLongBits = Double.doubleToRawLongBits(d);
        for (int i = 0; i < sizeof_lua_Number; i++) {
            bArr[i] = (byte) (jDoubleToRawLongBits & 255);
            jDoubleToRawLongBits >>= 8;
        }
        return bArr;
    }

    public static double bytes2FLT(byte[] bArr) {
        long j = 0;
        for (int i = 0; i < sizeof_lua_Number; i++) {
            j |= (bArr[i] & 255) << (i * 8);
        }
        return Double.longBitsToDouble(j);
    }

    public static byte[] INT2bytes(long j) {
        long j2 = j;
        byte[] bArr = new byte[sizeof_lua_Integer];
        for (int i = 0; i < sizeof_lua_Integer; i++) {
            bArr[i] = (byte) (j2 & 255);
            j2 >>= 8;
        }
        return bArr;
    }

    public static long bytes2INT(byte[] bArr) {
        long j = 0;
        for (int i = 0; i < sizeof_lua_Integer; i++) {
            j |= (bArr[i] & 255) << (i * 8);
        }
        return j;
    }

    public static byte[] int2bytes(long j) {
        long j2 = j;
        byte[] bArr = new byte[sizeof_int];
        for (int i = 0; i < sizeof_int; i++) {
            bArr[i] = (byte) (j2 & 255);
            j2 >>= 8;
        }
        return bArr;
    }

    public static long bytes2int(byte[] bArr) {
        long j = 0;
        for (int i = 0; i < sizeof_int; i++) {
            j |= (bArr[i] & 255) << (i * 8);
        }
        return j;
    }

    public static byte[] long2bytes(long j) {
        long j2 = j;
        byte[] bArr = new byte[8];
        for (int i = 0; i < 8; i++) {
            bArr[i] = (byte) (j2 & 255);
            j2 >>= 8;
        }
        return bArr;
    }

    public static long bytes2long(byte[] bArr) {
        long j = 0;
        for (int i = 0; i < 8; i++) {
            j |= (bArr[i] & 255) << (i * 8);
        }
        return j;
    }

    public static byte[] Instruction2bytes(int i) {
        if (sizeof_Instruction != 4) {
            return long2bytes(i);
        }
        return int2bytes(i);
    }

    public static long bytes2Instruction(byte[] bArr) {
        if (sizeof_Instruction != 4) {
            return bytes2long(bArr);
        }
        return bytes2int(bArr);
    }
}