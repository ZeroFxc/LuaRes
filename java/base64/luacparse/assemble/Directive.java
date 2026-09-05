package base64.luacparse.assemble;

import base64.luacparse.decompile.OpV;
import base64.luacparse.decompile.Output;
import base64.luacparse.parse.BHeader;
import base64.luacparse.parse.LFunction;
import base64.luacparse.parse.LHeader;
import java.util.HashMap;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public enum Directive {
    FORMAT(".format", DirectiveType.HEADER, 1),
    ENDIANNESS(".endianness", DirectiveType.HEADER, 1),
    INT_SIZE(".int_size", DirectiveType.HEADER, 1),
    SIZE_T_SIZE(".size_t_size", DirectiveType.HEADER, 1),
    INSTRUCTION_SIZE(".instruction_size", DirectiveType.HEADER, 1),
    SIZE_OP(".size_op", DirectiveType.HEADER, 1),
    SIZE_A(".size_a", DirectiveType.HEADER, 1),
    SIZE_B(".size_b", DirectiveType.HEADER, 1),
    SIZE_C(".size_c", DirectiveType.HEADER, 1),
    NUMBER_FORMAT(".number_format", DirectiveType.HEADER, 2),
    INTEGER_FORMAT(".integer_format", DirectiveType.HEADER, 1),
    FLOAT_FORMAT(".float_format", DirectiveType.HEADER, 1),
    OP(".op", DirectiveType.HEADER, 2),
    FUNCTION(".function", DirectiveType.NEWFUNCTION, 1),
    SOURCE(".source", DirectiveType.FUNCTION, 1),
    LINEDEFINED(".linedefined", DirectiveType.FUNCTION, 1),
    LASTLINEDEFINED(".lastlinedefined", DirectiveType.FUNCTION, 1),
    NUMPARAMS(".numparams", DirectiveType.FUNCTION, 1),
    IS_VARARG(".is_vararg", DirectiveType.FUNCTION, 1),
    MAXSTACKSIZE(".maxstacksize", DirectiveType.FUNCTION, 1),
    LABEL(".label", DirectiveType.FUNCTION, 1),
    CONSTANT(".constant", DirectiveType.FUNCTION, 2),
    LINE(".line", DirectiveType.FUNCTION, 1),
    ABSLINEINFO(".abslineinfo", DirectiveType.FUNCTION, 2),
    LOCAL(".local", DirectiveType.FUNCTION, 3),
    UPVALUE(".upvalue", DirectiveType.FUNCTION, 2);

    static Map<String, Directive> lookup = new HashMap();
    public final String token;
    public final DirectiveType type;

    static {
        for (Directive d : values()) {
            lookup.put(d.token, d);
        }
    }

    Directive(String token, DirectiveType type, int argcount) {
        this.token = token;
        this.type = type;
    }

    /* JADX INFO: renamed from: base64.luacparse.assemble.Directive$1 */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive = new int[Directive.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.FORMAT.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.ENDIANNESS.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.INT_SIZE.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SIZE_T_SIZE.ordinal()] = 4;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.INSTRUCTION_SIZE.ordinal()] = 5;
            } catch (NoSuchFieldError e5) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SIZE_OP.ordinal()] = 6;
            } catch (NoSuchFieldError e6) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SIZE_A.ordinal()] = 7;
            } catch (NoSuchFieldError e7) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SIZE_B.ordinal()] = 8;
            } catch (NoSuchFieldError e8) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SIZE_C.ordinal()] = 9;
            } catch (NoSuchFieldError e9) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.NUMBER_FORMAT.ordinal()] = 10;
            } catch (NoSuchFieldError e10) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.INTEGER_FORMAT.ordinal()] = 11;
            } catch (NoSuchFieldError e11) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.FLOAT_FORMAT.ordinal()] = 12;
            } catch (NoSuchFieldError e12) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.SOURCE.ordinal()] = 13;
            } catch (NoSuchFieldError e13) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.LINEDEFINED.ordinal()] = 14;
            } catch (NoSuchFieldError e14) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.LASTLINEDEFINED.ordinal()] = 15;
            } catch (NoSuchFieldError e15) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.NUMPARAMS.ordinal()] = 16;
            } catch (NoSuchFieldError e16) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.IS_VARARG.ordinal()] = 17;
            } catch (NoSuchFieldError e17) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[Directive.MAXSTACKSIZE.ordinal()] = 18;
            } catch (NoSuchFieldError e18) {
            }
        }
    }

    public void disassemble(Output out, BHeader chunk, LHeader header) {
        out.print(this.token + "\t");
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[ordinal()]) {
            case OpV.LUA50 /* 1 */:
                out.println(String.valueOf(header.format));
                return;
            case OpV.LUA51 /* 2 */:
                out.println(header.endianness.toString());
                return;
            case 3:
                out.println(String.valueOf(header.integer.getSize()));
                return;
            case OpV.LUA52 /* 4 */:
                out.println(String.valueOf(header.sizeT.getSize()));
                return;
            case 5:
                out.println("4");
                return;
            case 6:
                out.println(String.valueOf(header.extractor.op.size));
                return;
            case 7:
                out.println(String.valueOf(header.extractor.A.size));
                return;
            case OpV.LUA53 /* 8 */:
                out.println(String.valueOf(header.extractor.B.size));
                return;
            case 9:
                out.println(String.valueOf(header.extractor.C.size));
                return;
            case 10:
                out.println((header.number.integral ? "integer" : "float") + "\t" + header.number.size);
                return;
            case 11:
                out.println(String.valueOf(header.linteger.size));
                return;
            case 12:
                out.println(String.valueOf(header.lfloat.size));
                return;
            default:
                throw new IllegalStateException();
        }
    }

    public void disassemble(Output out, BHeader chunk, LFunction function) {
        out.print(this.token + "\t");
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$assemble$Directive[ordinal()]) {
            case 13:
                out.println(function.name.toPrintString());
                return;
            case 14:
                out.println(String.valueOf(function.linedefined));
                return;
            case 15:
                out.println(String.valueOf(function.lastlinedefined));
                return;
            case OpV.LUA54 /* 16 */:
                out.println(String.valueOf(function.numParams));
                return;
            case 17:
                out.println(String.valueOf(function.vararg));
                return;
            case 18:
                out.println(String.valueOf(function.maximumStackSize));
                return;
            default:
                throw new IllegalStateException();
        }
    }
}