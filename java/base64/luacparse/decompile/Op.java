package base64.luacparse.decompile;

import base64.luacparse.Version;
import base64.luacparse.decompile.CodeExtract;
import base64.luacparse.decompile.OperandFormat;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public enum Op {
    MOVE("move", 31, OperandFormat.AR, OperandFormat.BR),
    LOADK("loadk", 31, OperandFormat.AR, OperandFormat.BxK),
    LOADBOOL("loadbool", 15, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    LOADNIL("loadnil", 3, OperandFormat.AR, OperandFormat.BR),
    GETUPVAL("getupval", 31, OperandFormat.AR, OperandFormat.BU),
    GETGLOBAL("getglobal", 3, OperandFormat.AR, OperandFormat.BxK),
    GETTABLE("gettable", 15, OperandFormat.AR, OperandFormat.BR, OperandFormat.CRK),
    SETGLOBAL("setglobal", 3, OperandFormat.AR, OperandFormat.BxK),
    SETUPVAL("setupval", 31, OperandFormat.AR, OperandFormat.BU),
    SETTABLE("settable", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    NEWTABLE("newtable", 14, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    SELF("self", 15, OperandFormat.AR, OperandFormat.BR, OperandFormat.CRK),
    ADD("add", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    SUB("sub", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    MUL("mul", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    DIV("div", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    MOD("mod", 14, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    POW("pow", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    UNM("unm", 15, OperandFormat.AR, OperandFormat.BR),
    NOT("not", 15, OperandFormat.AR, OperandFormat.BR),
    LEN("len", 14, OperandFormat.AR, OperandFormat.BR),
    CONCAT("concat", 15, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    JMP("jmp", 3, OperandFormat.sBxJ),
    EQ("eq", 15, OperandFormat.A, OperandFormat.BRK, OperandFormat.CRK),
    LT("lt", 15, OperandFormat.A, OperandFormat.BRK, OperandFormat.CRK),
    LE("le", 15, OperandFormat.A, OperandFormat.BRK, OperandFormat.CRK),
    TEST("test", 14, OperandFormat.AR, OperandFormat.C),
    TESTSET("testset", 14, OperandFormat.AR, OperandFormat.BR, OperandFormat.C),
    CALL("call", 31, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    TAILCALL("tailcall", 15, OperandFormat.AR, OperandFormat.B),
    RETURN("return", 15, OperandFormat.AR, OperandFormat.B),
    FORLOOP("forloop", 15, OperandFormat.AR, OperandFormat.sBxJ),
    FORPREP("forprep", 14, OperandFormat.AR, OperandFormat.sBxJ),
    TFORLOOP("tforloop", 3, OperandFormat.AR, OperandFormat.C),
    SETLIST("setlist", 2, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    CLOSE("close", 19, OperandFormat.AR),
    CLOSURE("closure", 31, OperandFormat.AR, OperandFormat.BxF),
    VARARG("vararg", 14, OperandFormat.AR, OperandFormat.B),
    JMP52("jmp", 12, OperandFormat.A, OperandFormat.sBxJ),
    LOADNIL52("loadnil", 28, OperandFormat.AR, OperandFormat.B),
    LOADKX("loadkx", 28, OperandFormat.AR),
    GETTABUP("gettabup", 12, OperandFormat.AR, OperandFormat.BU, OperandFormat.CRK),
    SETTABUP("settabup", 12, OperandFormat.AU, OperandFormat.BRK, OperandFormat.CRK),
    SETLIST52("setlist", 12, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    TFORCALL("tforcall", 12, OperandFormat.AR, OperandFormat.C),
    TFORLOOP52("tforloop", 12, OperandFormat.AR, OperandFormat.sBxJ),
    EXTRAARG("extraarg", 28, OperandFormat.Ax),
    NEWTABLE50("newtable", 1, OperandFormat.AR, OperandFormat.B, OperandFormat.C),
    SETLIST50("setlist", 1, OperandFormat.AR, OperandFormat.Bx),
    SETLISTO("setlisto", 1, OperandFormat.AR, OperandFormat.Bx),
    TFORPREP("tforprep", 1, OperandFormat.AR, OperandFormat.sBxJ),
    TEST50("test", 1, OperandFormat.AR, OperandFormat.BR, OperandFormat.C),
    IDIV("idiv", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    BAND("band", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    BOR("bor", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    BXOR("bxor", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    SHL("shl", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    SHR("shr", 8, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    BNOT("bnot", 24, OperandFormat.AR, OperandFormat.BR),
    LOADI("loadi", 16, OperandFormat.AR, OperandFormat.sBxI),
    LOADF("loadf", 16, OperandFormat.AR, OperandFormat.sBxF),
    LOADFALSE("loadfalse", 16, OperandFormat.AR),
    LFALSESKIP("lfalseskip", 16, OperandFormat.AR),
    LOADTRUE("loadtrue", 16, OperandFormat.AR),
    GETTABUP54("gettabup", 16, OperandFormat.AR, OperandFormat.BU, OperandFormat.CKS),
    GETTABLE54("gettable", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    GETI("geti", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CI),
    GETFIELD("getfield", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CKS),
    SETTABUP54("settabup", 16, OperandFormat.AU, OperandFormat.BK, OperandFormat.CRK54),
    SETTABLE54("settable", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CRK54),
    SETI("seti", 16, OperandFormat.AR, OperandFormat.BI, OperandFormat.CRK54),
    SETFIELD("setfield", 16, OperandFormat.AR, OperandFormat.BKS, OperandFormat.CRK54),
    NEWTABLE54("newtable", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    SELF54("self", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CRK54),
    ADDI("addi", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CsI),
    ADDK("addk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    SUBK("subk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    MULK("mulk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    MODK("modk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    POWK("powk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    DIVK("divk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    IDIVK("idivk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CK),
    BANDK("bandk", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CKI),
    BORK("bork", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CKI),
    BXORK("bxork", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CKI),
    SHRI("shri", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CsI),
    SHLI("shli", 16, OperandFormat.AR, OperandFormat.CsI, OperandFormat.BR),
    ADD54("add", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    SUB54("sub", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    MUL54("mul", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    MOD54("mod", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    POW54("pow", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    DIV54("div", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    IDIV54("idiv", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    BAND54("band", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    BOR54("bor", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    BXOR54("bxor", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    SHL54("shl", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    SHR54("shr", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.CR),
    MMBIN("mmbin", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.C),
    MMBINI("mmbini", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.C, OperandFormat.k),
    MMBINK("mmbink", 16, OperandFormat.AR, OperandFormat.BK, OperandFormat.C, OperandFormat.k),
    CONCAT54("concat", 16, OperandFormat.AR, OperandFormat.B),
    TBC("tbc", 16, OperandFormat.AR),
    JMP54("jmp", 16, OperandFormat.sJ),
    EQ54("eq", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.k),
    LT54("lt", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.k),
    LE54("le", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.k),
    EQK("eqk", 16, OperandFormat.AR, OperandFormat.BK, OperandFormat.k),
    EQI("eqi", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.k, OperandFormat.C),
    LTI("lti", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.k, OperandFormat.C),
    LEI("lei", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.k, OperandFormat.C),
    GTI("gti", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.k, OperandFormat.C),
    GEI("gei", 16, OperandFormat.AR, OperandFormat.BsI, OperandFormat.k, OperandFormat.C),
    TEST54("test", 16, OperandFormat.AR, OperandFormat.k),
    TESTSET54("testset", 16, OperandFormat.AR, OperandFormat.BR, OperandFormat.k),
    TAILCALL54("tailcall", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    RETURN54("return", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    RETURN0("return0", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    RETURN1("return1", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    FORLOOP54("forloop", 16, OperandFormat.AR, OperandFormat.BxJn),
    FORPREP54("forprep", 16, OperandFormat.AR, OperandFormat.BxJ),
    TFORPREP54("tforprep", 16, OperandFormat.AR, OperandFormat.BxJ),
    TFORCALL54("tforcall", 16, OperandFormat.AR, OperandFormat.C),
    TFORLOOP54("tforloop", 16, OperandFormat.AR, OperandFormat.BxJn),
    SETLIST54("setlist", 16, OperandFormat.AR, OperandFormat.B, OperandFormat.C, OperandFormat.k),
    VARARG54("vararg", 16, OperandFormat.AR, OperandFormat.C),
    VARARGPREP("varargprep", 16, OperandFormat.A),
    EXTRABYTE("extrabyte", 31, OperandFormat.x),
    DEFAULT("default", 0, OperandFormat.AR, OperandFormat.BRK, OperandFormat.CRK),
    DEFAULT54("default", 0, OperandFormat.AR, OperandFormat.BR, OperandFormat.C, OperandFormat.k);

    public final String name;
    public final OperandFormat[] operands;
    public final int versions;

    Op(String name, int versions) {
        this.name = name;
        this.versions = versions;
        this.operands = new OperandFormat[0];
    }

    Op(String name, int versions, OperandFormat f1) {
        this.name = name;
        this.versions = versions;
        this.operands = new OperandFormat[]{f1};
    }

    Op(String name, int versions, OperandFormat f1, OperandFormat f2) {
        this.name = name;
        this.versions = versions;
        this.operands = new OperandFormat[]{f1, f2};
    }

    Op(String name, int versions, OperandFormat f1, OperandFormat f2, OperandFormat f3) {
        this.name = name;
        this.versions = versions;
        this.operands = new OperandFormat[]{f1, f2, f3};
    }

    Op(String name, int versions, OperandFormat f1, OperandFormat f2, OperandFormat f3, OperandFormat f4) {
        this.name = name;
        this.versions = versions;
        this.operands = new OperandFormat[]{f1, f2, f3, f4};
    }

    public boolean hasExtraByte(int codepoint, CodeExtract ex) {
        return this == SETLIST && ex.C.extract(codepoint) == 0;
    }

    public int jumpField(int codepoint, CodeExtract ex) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[ordinal()]) {
            case OpV.LUA50 /* 1 */:
            case OpV.LUA51 /* 2 */:
                return ex.Bx.extract(codepoint);
            case 3:
            case OpV.LUA52 /* 4 */:
                return -ex.Bx.extract(codepoint);
            case 5:
            case 6:
            case 7:
            case OpV.LUA53 /* 8 */:
            case 9:
            case 10:
                return ex.sBx.extract(codepoint);
            case 11:
                return ex.sJ.extract(codepoint);
            default:
                throw new IllegalStateException();
        }
    }

    public int target(int codepoint, CodeExtract ex) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[ordinal()]) {
            case OpV.LUA50 /* 1 */:
            case OpV.LUA51 /* 2 */:
            case 3:
            case OpV.LUA52 /* 4 */:
            case 5:
            case 6:
            case 7:
            case OpV.LUA53 /* 8 */:
            case 9:
            case 10:
            case 11:
            case 84:
            case 85:
            case 86:
            case 87:
            case 88:
            case 89:
            case 90:
            case 91:
            case 92:
            case 93:
            case 94:
            case 95:
            case 96:
            case 97:
            case 98:
            case 99:
            case 100:
            case 101:
            case 102:
            case 103:
            case 104:
            case 105:
            case 106:
            case 107:
            case 108:
            case 109:
            case 110:
            case 111:
            case 112:
            case 113:
            case 114:
            case 115:
            case 116:
            case 117:
            case 118:
            case 119:
            case 120:
            case 121:
            case 122:
            case 123:
            case 124:
            case 125:
                return -1;
            case 12:
            case 13:
            case 14:
            case 15:
            case OpV.LUA54 /* 16 */:
            case 17:
            case 18:
            case 19:
            case 20:
            case 21:
            case 22:
            case 23:
            case 24:
            case 25:
            case 26:
            case 27:
            case 28:
            case 29:
            case 30:
            case 31:
            case 32:
            case 33:
            case 34:
            case 35:
            case 36:
            case 37:
            case 38:
            case 39:
            case 40:
            case 41:
            case 42:
            case 43:
            case 44:
            case 45:
            case 46:
            case 47:
            case 48:
            case 49:
            case 50:
            case 51:
            case 52:
            case 53:
            case 54:
            case 55:
            case 56:
            case 57:
            case 58:
            case 59:
            case 60:
            case 61:
            case 62:
            case 63:
            case 64:
            case 65:
            case 66:
            case 67:
            case 68:
            case 69:
            case 70:
            case 71:
            case 72:
            case 73:
            case 74:
            case 75:
            case 76:
            case 77:
            case 78:
                return ex.A.extract(codepoint);
            case 79:
            case 80:
            case 81:
                return -1;
            case 82:
                if (ex.A.extract(codepoint) == ex.B.extract(codepoint)) {
                    return ex.A.extract(codepoint);
                }
                return -1;
            case 83:
                if (ex.B.extract(codepoint) == 0) {
                    return ex.A.extract(codepoint);
                }
                return -1;
            case 126:
                int iExtract = ex.A.extract(codepoint);
                int c = ex.C.extract(codepoint);
                if (c != 2) {
                    return -1;
                }
                return iExtract;
            case 127:
                int iExtract2 = ex.A.extract(codepoint);
                int b = ex.B.extract(codepoint);
                if (b != 2) {
                    return -1;
                }
                return iExtract2;
            case 128:
                int iExtract3 = ex.A.extract(codepoint);
                int c2 = ex.C.extract(codepoint);
                if (c2 != 2) {
                    return -1;
                }
                return iExtract3;
            case 129:
                return -1;
            case 130:
            case 131:
                throw new IllegalStateException();
            default:
                throw new IllegalStateException(name());
        }
    }

    private static String fixedOperand(int field) {
        return Integer.toString(field);
    }

    private static String registerOperand(int field) {
        return "r" + field;
    }

    private static String upvalueOperand(int field) {
        return "u" + field;
    }

    private static String constantOperand(int field) {
        return "k" + field;
    }

    private static String functionOperand(int field) {
        return "f" + field;
    }

    public boolean hasJump() {
        for (int i = 0; i < this.operands.length; i++) {
            OperandFormat.Format format = this.operands[i].format;
            if (format == OperandFormat.Format.JUMP || format == OperandFormat.Format.JUMP_NEGATIVE) {
                return true;
            }
        }
        return false;
    }

    public String codePointToString(int codepoint, CodeExtract ex, String label) {
        return toStringHelper(this.name, this.operands, codepoint, ex, label);
    }

    public static String defaultToString(int codepoint, Version version, CodeExtract ex) {
        return toStringHelper(String.format("op%02d", Integer.valueOf(ex.op.extract(codepoint))), version.getDefaultOp().operands, codepoint, ex, null);
    }

    private static String toStringHelper(String name, OperandFormat[] operands, int codepoint, CodeExtract ex, String label) {
        CodeExtract.Field field;
        StringBuilder b = new StringBuilder();
        b.append(name);
        for (int i = 0; i < 10 - name.length(); i++) {
            b.append(' ');
        }
        String[] parameters = new String[operands.length];
        for (int i2 = 0; i2 < operands.length; i2++) {
            switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[operands[i2].field.ordinal()]) {
                case OpV.LUA50 /* 1 */:
                    field = ex.A;
                    break;
                case OpV.LUA51 /* 2 */:
                    field = ex.B;
                    break;
                case 3:
                    field = ex.C;
                    break;
                case OpV.LUA52 /* 4 */:
                    field = ex.k;
                    break;
                case 5:
                    field = ex.Ax;
                    break;
                case 6:
                    field = ex.sJ;
                    break;
                case 7:
                    field = ex.Bx;
                    break;
                case OpV.LUA53 /* 8 */:
                    field = ex.sBx;
                    break;
                case 9:
                    field = ex.x;
                    break;
                default:
                    throw new IllegalStateException();
            }
            int x = field.extract(codepoint);
            switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[operands[i2].format.ordinal()]) {
                case OpV.LUA50 /* 1 */:
                case OpV.LUA51 /* 2 */:
                case 3:
                    parameters[i2] = fixedOperand(x);
                    break;
                case OpV.LUA52 /* 4 */:
                    parameters[i2] = fixedOperand(x - (field.max() / 2));
                    break;
                case 5:
                    parameters[i2] = registerOperand(x);
                    break;
                case 6:
                    parameters[i2] = upvalueOperand(x);
                    break;
                case 7:
                    if (ex.is_k(x)) {
                        parameters[i2] = constantOperand(ex.get_k(x));
                    } else {
                        parameters[i2] = registerOperand(x);
                    }
                    break;
                case OpV.LUA53 /* 8 */:
                    if (ex.k.extract(codepoint) != 0) {
                        parameters[i2] = constantOperand(x);
                    } else {
                        parameters[i2] = registerOperand(x);
                    }
                    break;
                case 9:
                case 10:
                case 11:
                    parameters[i2] = constantOperand(x);
                    break;
                case 12:
                    parameters[i2] = functionOperand(x);
                    break;
                case 13:
                    if (label != null) {
                        parameters[i2] = label;
                    } else {
                        parameters[i2] = fixedOperand(operands[i2].offset + x);
                    }
                    break;
                case 14:
                    if (label != null) {
                        parameters[i2] = label;
                    } else {
                        parameters[i2] = fixedOperand(-x);
                    }
                    break;
                default:
                    throw new IllegalStateException();
            }
        }
        for (String parameter : parameters) {
            b.append(' ');
            for (int i3 = 0; i3 < 5 - parameter.length(); i3++) {
                b.append(' ');
            }
            b.append(parameter);
        }
        return b.toString();
    }

    /* JADX INFO: renamed from: base64.luacparse.decompile.Op$1, reason: invalid class name */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op;
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field;
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format = new int[OperandFormat.Format.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.IMMEDIATE_INTEGER.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.IMMEDIATE_FLOAT.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.RAW.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.IMMEDIATE_SIGNED_INTEGER.ordinal()] = 4;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.REGISTER.ordinal()] = 5;
            } catch (NoSuchFieldError e5) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.UPVALUE.ordinal()] = 6;
            } catch (NoSuchFieldError e6) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.REGISTER_K.ordinal()] = 7;
            } catch (NoSuchFieldError e7) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.REGISTER_K54.ordinal()] = 8;
            } catch (NoSuchFieldError e8) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.CONSTANT.ordinal()] = 9;
            } catch (NoSuchFieldError e9) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.CONSTANT_INTEGER.ordinal()] = 10;
            } catch (NoSuchFieldError e10) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.CONSTANT_STRING.ordinal()] = 11;
            } catch (NoSuchFieldError e11) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.FUNCTION.ordinal()] = 12;
            } catch (NoSuchFieldError e12) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.JUMP.ordinal()] = 13;
            } catch (NoSuchFieldError e13) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Format[OperandFormat.Format.JUMP_NEGATIVE.ordinal()] = 14;
            } catch (NoSuchFieldError e14) {
            }
            $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field = new int[OperandFormat.Field.values().length];
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.A.ordinal()] = 1;
            } catch (NoSuchFieldError e15) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.B.ordinal()] = 2;
            } catch (NoSuchFieldError e16) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.C.ordinal()] = 3;
            } catch (NoSuchFieldError e17) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.k.ordinal()] = 4;
            } catch (NoSuchFieldError e18) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.Ax.ordinal()] = 5;
            } catch (NoSuchFieldError e19) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.sJ.ordinal()] = 6;
            } catch (NoSuchFieldError e20) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.Bx.ordinal()] = 7;
            } catch (NoSuchFieldError e21) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.sBx.ordinal()] = 8;
            } catch (NoSuchFieldError e22) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$OperandFormat$Field[OperandFormat.Field.x.ordinal()] = 9;
            } catch (NoSuchFieldError e23) {
            }
            $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op = new int[Op.values().length];
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.FORPREP54.ordinal()] = 1;
            } catch (NoSuchFieldError e24) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORPREP54.ordinal()] = 2;
            } catch (NoSuchFieldError e25) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.FORLOOP54.ordinal()] = 3;
            } catch (NoSuchFieldError e26) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORLOOP54.ordinal()] = 4;
            } catch (NoSuchFieldError e27) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.JMP.ordinal()] = 5;
            } catch (NoSuchFieldError e28) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.FORLOOP.ordinal()] = 6;
            } catch (NoSuchFieldError e29) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.FORPREP.ordinal()] = 7;
            } catch (NoSuchFieldError e30) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.JMP52.ordinal()] = 8;
            } catch (NoSuchFieldError e31) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORLOOP52.ordinal()] = 9;
            } catch (NoSuchFieldError e32) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORPREP.ordinal()] = 10;
            } catch (NoSuchFieldError e33) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.JMP54.ordinal()] = 11;
            } catch (NoSuchFieldError e34) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MOVE.ordinal()] = 12;
            } catch (NoSuchFieldError e35) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADI.ordinal()] = 13;
            } catch (NoSuchFieldError e36) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADF.ordinal()] = 14;
            } catch (NoSuchFieldError e37) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADK.ordinal()] = 15;
            } catch (NoSuchFieldError e38) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADKX.ordinal()] = 16;
            } catch (NoSuchFieldError e39) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADBOOL.ordinal()] = 17;
            } catch (NoSuchFieldError e40) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADFALSE.ordinal()] = 18;
            } catch (NoSuchFieldError e41) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LFALSESKIP.ordinal()] = 19;
            } catch (NoSuchFieldError e42) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADTRUE.ordinal()] = 20;
            } catch (NoSuchFieldError e43) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETUPVAL.ordinal()] = 21;
            } catch (NoSuchFieldError e44) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETTABUP.ordinal()] = 22;
            } catch (NoSuchFieldError e45) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETTABUP54.ordinal()] = 23;
            } catch (NoSuchFieldError e46) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETGLOBAL.ordinal()] = 24;
            } catch (NoSuchFieldError e47) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETTABLE.ordinal()] = 25;
            } catch (NoSuchFieldError e48) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETTABLE54.ordinal()] = 26;
            } catch (NoSuchFieldError e49) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETI.ordinal()] = 27;
            } catch (NoSuchFieldError e50) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GETFIELD.ordinal()] = 28;
            } catch (NoSuchFieldError e51) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.NEWTABLE50.ordinal()] = 29;
            } catch (NoSuchFieldError e52) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.NEWTABLE.ordinal()] = 30;
            } catch (NoSuchFieldError e53) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.NEWTABLE54.ordinal()] = 31;
            } catch (NoSuchFieldError e54) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.ADD.ordinal()] = 32;
            } catch (NoSuchFieldError e55) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SUB.ordinal()] = 33;
            } catch (NoSuchFieldError e56) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MUL.ordinal()] = 34;
            } catch (NoSuchFieldError e57) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.DIV.ordinal()] = 35;
            } catch (NoSuchFieldError e58) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.IDIV.ordinal()] = 36;
            } catch (NoSuchFieldError e59) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MOD.ordinal()] = 37;
            } catch (NoSuchFieldError e60) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.POW.ordinal()] = 38;
            } catch (NoSuchFieldError e61) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BAND.ordinal()] = 39;
            } catch (NoSuchFieldError e62) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BOR.ordinal()] = 40;
            } catch (NoSuchFieldError e63) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BXOR.ordinal()] = 41;
            } catch (NoSuchFieldError e64) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHL.ordinal()] = 42;
            } catch (NoSuchFieldError e65) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHR.ordinal()] = 43;
            } catch (NoSuchFieldError e66) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.ADD54.ordinal()] = 44;
            } catch (NoSuchFieldError e67) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SUB54.ordinal()] = 45;
            } catch (NoSuchFieldError e68) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MUL54.ordinal()] = 46;
            } catch (NoSuchFieldError e69) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.DIV54.ordinal()] = 47;
            } catch (NoSuchFieldError e70) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.IDIV54.ordinal()] = 48;
            } catch (NoSuchFieldError e71) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MOD54.ordinal()] = 49;
            } catch (NoSuchFieldError e72) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.POW54.ordinal()] = 50;
            } catch (NoSuchFieldError e73) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BAND54.ordinal()] = 51;
            } catch (NoSuchFieldError e74) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BOR54.ordinal()] = 52;
            } catch (NoSuchFieldError e75) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BXOR54.ordinal()] = 53;
            } catch (NoSuchFieldError e76) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHL54.ordinal()] = 54;
            } catch (NoSuchFieldError e77) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHR54.ordinal()] = 55;
            } catch (NoSuchFieldError e78) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.ADDK.ordinal()] = 56;
            } catch (NoSuchFieldError e79) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SUBK.ordinal()] = 57;
            } catch (NoSuchFieldError e80) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MULK.ordinal()] = 58;
            } catch (NoSuchFieldError e81) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.DIVK.ordinal()] = 59;
            } catch (NoSuchFieldError e82) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.IDIVK.ordinal()] = 60;
            } catch (NoSuchFieldError e83) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MODK.ordinal()] = 61;
            } catch (NoSuchFieldError e84) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.POWK.ordinal()] = 62;
            } catch (NoSuchFieldError e85) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BANDK.ordinal()] = 63;
            } catch (NoSuchFieldError e86) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BORK.ordinal()] = 64;
            } catch (NoSuchFieldError e87) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BXORK.ordinal()] = 65;
            } catch (NoSuchFieldError e88) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.ADDI.ordinal()] = 66;
            } catch (NoSuchFieldError e89) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHLI.ordinal()] = 67;
            } catch (NoSuchFieldError e90) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SHRI.ordinal()] = 68;
            } catch (NoSuchFieldError e91) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.UNM.ordinal()] = 69;
            } catch (NoSuchFieldError e92) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.NOT.ordinal()] = 70;
            } catch (NoSuchFieldError e93) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LEN.ordinal()] = 71;
            } catch (NoSuchFieldError e94) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.BNOT.ordinal()] = 72;
            } catch (NoSuchFieldError e95) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.CONCAT.ordinal()] = 73;
            } catch (NoSuchFieldError e96) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.CONCAT54.ordinal()] = 74;
            } catch (NoSuchFieldError e97) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.CLOSURE.ordinal()] = 75;
            } catch (NoSuchFieldError e98) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TEST50.ordinal()] = 76;
            } catch (NoSuchFieldError e99) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TESTSET.ordinal()] = 77;
            } catch (NoSuchFieldError e100) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TESTSET54.ordinal()] = 78;
            } catch (NoSuchFieldError e101) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MMBIN.ordinal()] = 79;
            } catch (NoSuchFieldError e102) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MMBINI.ordinal()] = 80;
            } catch (NoSuchFieldError e103) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.MMBINK.ordinal()] = 81;
            } catch (NoSuchFieldError e104) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADNIL.ordinal()] = 82;
            } catch (NoSuchFieldError e105) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LOADNIL52.ordinal()] = 83;
            } catch (NoSuchFieldError e106) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETGLOBAL.ordinal()] = 84;
            } catch (NoSuchFieldError e107) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETUPVAL.ordinal()] = 85;
            } catch (NoSuchFieldError e108) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETTABUP.ordinal()] = 86;
            } catch (NoSuchFieldError e109) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETTABUP54.ordinal()] = 87;
            } catch (NoSuchFieldError e110) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETTABLE.ordinal()] = 88;
            } catch (NoSuchFieldError e111) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETTABLE54.ordinal()] = 89;
            } catch (NoSuchFieldError e112) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETI.ordinal()] = 90;
            } catch (NoSuchFieldError e113) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETFIELD.ordinal()] = 91;
            } catch (NoSuchFieldError e114) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TAILCALL.ordinal()] = 92;
            } catch (NoSuchFieldError e115) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TAILCALL54.ordinal()] = 93;
            } catch (NoSuchFieldError e116) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.RETURN.ordinal()] = 94;
            } catch (NoSuchFieldError e117) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.RETURN54.ordinal()] = 95;
            } catch (NoSuchFieldError e118) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.RETURN0.ordinal()] = 96;
            } catch (NoSuchFieldError e119) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.RETURN1.ordinal()] = 97;
            } catch (NoSuchFieldError e120) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORCALL.ordinal()] = 98;
            } catch (NoSuchFieldError e121) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORCALL54.ordinal()] = 99;
            } catch (NoSuchFieldError e122) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TFORLOOP.ordinal()] = 100;
            } catch (NoSuchFieldError e123) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TBC.ordinal()] = 101;
            } catch (NoSuchFieldError e124) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.CLOSE.ordinal()] = 102;
            } catch (NoSuchFieldError e125) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EXTRAARG.ordinal()] = 103;
            } catch (NoSuchFieldError e126) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SELF.ordinal()] = 104;
            } catch (NoSuchFieldError e127) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SELF54.ordinal()] = 105;
            } catch (NoSuchFieldError e128) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EQ.ordinal()] = 106;
            } catch (NoSuchFieldError e129) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LT.ordinal()] = 107;
            } catch (NoSuchFieldError e130) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LE.ordinal()] = 108;
            } catch (NoSuchFieldError e131) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EQ54.ordinal()] = 109;
            } catch (NoSuchFieldError e132) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LT54.ordinal()] = 110;
            } catch (NoSuchFieldError e133) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LE54.ordinal()] = 111;
            } catch (NoSuchFieldError e134) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EQK.ordinal()] = 112;
            } catch (NoSuchFieldError e135) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EQI.ordinal()] = 113;
            } catch (NoSuchFieldError e136) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LTI.ordinal()] = 114;
            } catch (NoSuchFieldError e137) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.LEI.ordinal()] = 115;
            } catch (NoSuchFieldError e138) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GTI.ordinal()] = 116;
            } catch (NoSuchFieldError e139) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.GEI.ordinal()] = 117;
            } catch (NoSuchFieldError e140) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TEST.ordinal()] = 118;
            } catch (NoSuchFieldError e141) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.TEST54.ordinal()] = 119;
            } catch (NoSuchFieldError e142) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETLIST50.ordinal()] = 120;
            } catch (NoSuchFieldError e143) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETLISTO.ordinal()] = 121;
            } catch (NoSuchFieldError e144) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETLIST.ordinal()] = 122;
            } catch (NoSuchFieldError e145) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETLIST52.ordinal()] = 123;
            } catch (NoSuchFieldError e146) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.SETLIST54.ordinal()] = 124;
            } catch (NoSuchFieldError e147) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.VARARGPREP.ordinal()] = 125;
            } catch (NoSuchFieldError e148) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.CALL.ordinal()] = 126;
            } catch (NoSuchFieldError e149) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.VARARG.ordinal()] = 127;
            } catch (NoSuchFieldError e150) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.VARARG54.ordinal()] = 128;
            } catch (NoSuchFieldError e151) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.EXTRABYTE.ordinal()] = 129;
            } catch (NoSuchFieldError e152) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.DEFAULT.ordinal()] = 130;
            } catch (NoSuchFieldError e153) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$decompile$Op[Op.DEFAULT54.ordinal()] = 131;
            } catch (NoSuchFieldError e154) {
            }
        }
    }
}