package com.nwdxlgzs.luac53support;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public enum OPCode {
    UNKNOWN(-1, -1, -1, OpArgMask.UNKNOWN, OpArgMask.UNKNOWN, OpMode.UNKNOWN),
    OP_MOVE(0, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iABC),
    OP_LOADK(1, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgN, OpMode.iABx),
    OP_LOADKX(2, 0, 1, OpArgMask.OpArgN, OpArgMask.OpArgN, OpMode.iABx),
    OP_LOADBOOL(3, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_LOADNIL(4, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_GETUPVAL(5, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_GETTABUP(6, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgK, OpMode.iABC),
    OP_GETTABLE(7, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgK, OpMode.iABC),
    OP_SETTABUP(8, 0, 0, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_SETUPVAL(9, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_SETTABLE(10, 0, 0, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_NEWTABLE(11, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_SELF(12, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgK, OpMode.iABC),
    OP_ADD(13, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_SUB(14, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_MUL(15, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_MOD(16, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_POW(17, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_DIV(18, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_IDIV(19, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_BAND(20, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_BOR(21, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_BXOR(22, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_SHL(23, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_SHR(24, 0, 1, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_UNM(25, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iABC),
    OP_BNOT(26, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iABC),
    OP_NOT(27, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iABC),
    OP_LEN(28, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iABC),
    OP_CONCAT(29, 0, 1, OpArgMask.OpArgR, OpArgMask.OpArgR, OpMode.iABC),
    OP_JMP(30, 0, 0, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iAsBx),
    OP_EQ(31, 1, 0, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_LT(32, 1, 0, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_LE(33, 1, 0, OpArgMask.OpArgK, OpArgMask.OpArgK, OpMode.iABC),
    OP_TEST(34, 1, 0, OpArgMask.OpArgR, OpArgMask.OpArgU, OpMode.iABC),
    OP_TESTSET(35, 1, 1, OpArgMask.OpArgR, OpArgMask.OpArgU, OpMode.iABC),
    OP_CALL(36, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_TAILCALL(37, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_RETURN(38, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_FORLOOP(39, 1, 0, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iAsBx),
    OP_FORPREP(40, 1, 0, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iAsBx),
    OP_TFORCALL(41, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_TFORLOOP(42, 1, 0, OpArgMask.OpArgR, OpArgMask.OpArgN, OpMode.iAsBx),
    OP_SETLIST(43, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iABC),
    OP_CLOSURE(44, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABx),
    OP_VARARG(45, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_EXTRAARG(46, 0, 0, OpArgMask.OpArgU, OpArgMask.OpArgU, OpMode.iAx),
    OP_TBC(47, 0, 0, OpArgMask.OpArgN, OpArgMask.OpArgN, OpMode.iABC),
    OP_NEWARRAY(48, 0, 1, OpArgMask.OpArgU, OpArgMask.OpArgN, OpMode.iABC),
    OP_TFOREACH(49, 0, 0, OpArgMask.OpArgN, OpArgMask.OpArgU, OpMode.iABC);

    private int A;
    private OpArgMask B;
    private OpArgMask C;
    private OpMode Mode;
    private int T;
    private int op;

    public static OPCode valueOf(String str) {
        for (OPCode oPCode : values()) {
            if (oPCode.name().equals(str)) {
                return oPCode;
            }
        }
        throw new IllegalArgumentException();
    }

    OPCode(int i, int i2, int i3, OpArgMask opArgMask, OpArgMask opArgMask2, OpMode opMode) {
        this.op = i;
        this.T = i2;
        this.A = i3;
        this.B = opArgMask;
        this.C = opArgMask2;
        this.Mode = opMode;
    }

    public int getOP() {
        return this.op;
    }

    public int getT() {
        return this.T;
    }

    public int getA() {
        return this.A;
    }

    public OpArgMask getB() {
        return this.B;
    }

    public OpArgMask getC() {
        return this.C;
    }

    public OpMode getMode() {
        return this.Mode;
    }

    public static OPCode fromValue(int i) {
        for (OPCode oPCode : values()) {
            if (oPCode.getOP() == i) {
                return oPCode;
            }
        }
        return UNKNOWN;
    }

    public enum OpArgMask {
        OpArgN(0),
        OpArgU(1),
        OpArgR(2),
        OpArgK(3),
        UNKNOWN(-1);

        public int value;

        public static OpArgMask valueOf(String str) {
            for (OpArgMask opArgMask : values()) {
                if (opArgMask.name().equals(str)) {
                    return opArgMask;
                }
            }
            throw new IllegalArgumentException();
        }

        OpArgMask(int i) {
            this.value = i;
        }

        public int getValue() {
            return this.value;
        }

        public static OpArgMask fromValue(int i) {
            for (OpArgMask opArgMask : values()) {
                if (opArgMask.getValue() == i) {
                    return opArgMask;
                }
            }
            return UNKNOWN;
        }
    }

    public enum OpMode {
        iABC(0),
        iABx(1),
        iAsBx(2),
        iAx(3),
        UNKNOWN(-1);

        public int value;

        public static OpMode valueOf(String str) {
            for (OpMode opMode : values()) {
                if (opMode.name().equals(str)) {
                    return opMode;
                }
            }
            throw new IllegalArgumentException();
        }

        OpMode(int i) {
            this.value = i;
        }

        public int getValue() {
            return this.value;
        }

        public static OpMode fromValue(int i) {
            for (OpMode opMode : values()) {
                if (opMode.getValue() == i) {
                    return opMode;
                }
            }
            return UNKNOWN;
        }
    }
}