package base64.luacparse.parse;

import base64.luacparse.Version;
import base64.luacparse.assemble.Directive;
import base64.luacparse.decompile.CodeExtract;
import base64.luacparse.decompile.OpV;
import base64.luacparse.parse.LHeader;
import base64.luacparse.parse.LNumberType;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LHeaderType extends BObjectType<LHeader> {
    protected static final double TEST_FLOAT = 370.5d;
    protected static final int TEST_INTEGER = 22136;
    public static final LHeaderType TYPE50 = new LHeaderType50();
    public static final LHeaderType TYPE51 = new LHeaderType51();
    public static final LHeaderType TYPE52 = new LHeaderType52();
    public static final LHeaderType TYPE53 = new LHeaderType53();
    public static final LHeaderType TYPE54 = new LHeaderType54();
    private static final byte[] luacTail = {25, -109, 13, 10, 26, 10};

    public abstract List<Directive> get_directives();

    protected abstract void parse_main(ByteBuffer byteBuffer, BHeader bHeader, LHeaderParseState lHeaderParseState);

    public static LHeaderType get(Version.HeaderType type) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return TYPE50;
            case OpV.LUA51 /* 2 */:
                return TYPE51;
            case 3:
                return TYPE52;
            case OpV.LUA52 /* 4 */:
                return TYPE53;
            case 5:
                return TYPE54;
            default:
                throw new IllegalStateException();
        }
    }

    protected static class LHeaderParseState {
        LHeader.LEndianness endianness;
        int format;
        BIntegerType integer;
        int lFloatSize;
        int lIntegerSize;
        boolean lNumberIntegrality;
        int lNumberSize;
        LNumberType lfloat;
        LNumberType linteger;
        LNumberType number;
        int sizeA;
        int sizeB;
        int sizeC;
        int sizeOp;
        BIntegerType sizeT;

        protected LHeaderParseState() {
        }
    }

    @Override // base64.luacparse.parse.BObjectType
    public LHeader parse(ByteBuffer buffer, BHeader header) {
        Version version = header.version;
        LHeaderParseState s = new LHeaderParseState();
        parse_main(buffer, header, s);
        LBooleanType bool = new LBooleanType();
        LStringType string = version.getLStringType();
        LConstantType constant = version.getLConstantType();
        LAbsLineInfoType abslineinfo = new LAbsLineInfoType();
        LLocalType local = new LLocalType();
        LUpvalueType upvalue = version.getLUpvalueType();
        LFunctionType function = version.getLFunctionType();
        CodeExtract extract = new CodeExtract(header.version, s.sizeOp, s.sizeA, s.sizeB, s.sizeC);
        return new LHeader(s.format, s.endianness, s.integer, s.sizeT, bool, s.number, s.linteger, s.lfloat, string, constant, abslineinfo, local, upvalue, function, extract);
    }

    protected void parse_format(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int format = buffer.get() & 255;
        if (format != 0) {
            throw new IllegalStateException("The input chunk reports a non-standard lua format: " + format);
        }
        s.format = format;
        Objects.requireNonNull(header);
    }

    protected void write_format(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(object.format);
    }

    protected void parse_endianness(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int endianness = buffer.get() & 255;
        switch (endianness) {
            case 0:
                s.endianness = LHeader.LEndianness.BIG;
                buffer.order(ByteOrder.BIG_ENDIAN);
                break;
            case OpV.LUA50 /* 1 */:
                s.endianness = LHeader.LEndianness.LITTLE;
                buffer.order(ByteOrder.LITTLE_ENDIAN);
                break;
            default:
                throw new IllegalStateException("The input chunk reports an invalid endianness: " + endianness);
        }
        Objects.requireNonNull(header);
    }

    /* JADX INFO: renamed from: base64.luacparse.parse.LHeaderType$1, reason: invalid class name */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType;
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$parse$LHeader$LEndianness = new int[LHeader.LEndianness.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$parse$LHeader$LEndianness[LHeader.LEndianness.BIG.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$parse$LHeader$LEndianness[LHeader.LEndianness.LITTLE.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType = new int[Version.HeaderType.values().length];
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[Version.HeaderType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[Version.HeaderType.LUA51.ordinal()] = 2;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[Version.HeaderType.LUA52.ordinal()] = 3;
            } catch (NoSuchFieldError e5) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[Version.HeaderType.LUA53.ordinal()] = 4;
            } catch (NoSuchFieldError e6) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$HeaderType[Version.HeaderType.LUA54.ordinal()] = 5;
            } catch (NoSuchFieldError e7) {
            }
        }
    }

    protected void write_endianness(OutputStream out, BHeader header, LHeader object) throws IOException {
        int value;
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$parse$LHeader$LEndianness[object.endianness.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                value = 0;
                break;
            case OpV.LUA51 /* 2 */:
                value = 1;
                break;
            default:
                throw new IllegalStateException();
        }
        out.write(value);
    }

    protected void parse_int_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int intSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        s.integer = new BIntegerType50(intSize);
    }

    protected void write_int_size(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(object.integer.getSize());
    }

    protected void parse_size_t_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int sizeTSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        s.sizeT = new BIntegerType50(sizeTSize);
    }

    protected void write_size_t_size(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(object.sizeT.getSize());
    }

    protected void parse_instruction_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int instructionSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        if (instructionSize != 4) {
            throw new IllegalStateException("The input chunk reports an unsupported instruction size: " + instructionSize + " bytes");
        }
    }

    protected void write_instruction_size(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(4);
    }

    protected void parse_number_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int lNumberSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        s.lNumberSize = lNumberSize;
    }

    protected void write_number_size(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(object.number.size);
    }

    protected void parse_number_integrality(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int lNumberIntegralityCode = buffer.get() & 255;
        Objects.requireNonNull(header);
        if (lNumberIntegralityCode > 1) {
            throw new IllegalStateException("The input chunk reports an invalid code for lua number integrality: " + lNumberIntegralityCode);
        }
        s.lNumberIntegrality = lNumberIntegralityCode == 1;
    }

    protected void write_number_integrality(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write((byte) (object.number.integral ? 1 : 0));
    }

    protected void parse_integer_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int lIntegerSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        if (lIntegerSize < 2) {
            throw new IllegalStateException("The input chunk reports an integer size that is too small: " + lIntegerSize);
        }
        s.lIntegerSize = lIntegerSize;
    }

    protected void parse_float_size(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        int lFloatSize = buffer.get() & 255;
        Objects.requireNonNull(header);
        s.lFloatSize = lFloatSize;
    }

    protected void parse_number_format_53(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        byte[] endianness = new byte[s.lIntegerSize];
        buffer.get(endianness);
        if (endianness[0] != 120 || endianness[1] != 86) {
            if (endianness[s.lIntegerSize - 1] == 120 && endianness[s.lIntegerSize - 2] == 86) {
                s.endianness = LHeader.LEndianness.BIG;
                buffer.order(ByteOrder.BIG_ENDIAN);
            } else {
                throw new IllegalStateException("The input chunk reports an invalid endianness: " + Arrays.toString(endianness));
            }
        } else {
            s.endianness = LHeader.LEndianness.LITTLE;
            buffer.order(ByteOrder.LITTLE_ENDIAN);
        }
        s.linteger = new LNumberType(s.lIntegerSize, true, LNumberType.NumberMode.MODE_INTEGER);
        s.lfloat = new LNumberType(s.lFloatSize, false, LNumberType.NumberMode.MODE_FLOAT);
        double floatcheck = s.lfloat.parse(buffer, header).value();
        if (floatcheck != s.lfloat.convert(TEST_FLOAT)) {
            throw new IllegalStateException("The input chunk is using an unrecognized floating point format: " + floatcheck);
        }
    }

    protected void parse_extractor(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        s.sizeOp = buffer.get() & 255;
        s.sizeA = buffer.get() & 255;
        s.sizeB = buffer.get() & 255;
        s.sizeC = buffer.get() & 255;
        Objects.requireNonNull(header);
    }

    protected void write_extractor(OutputStream out, BHeader header, LHeader object) throws IOException {
        out.write(object.extractor.op.size);
        out.write(object.extractor.A.size);
        out.write(object.extractor.B.size);
        out.write(object.extractor.C.size);
    }

    protected void parse_tail(ByteBuffer buffer, BHeader header, LHeaderParseState s) {
        for (int i = 0; i < luacTail.length; i++) {
            if (buffer.get() != luacTail[i]) {
                throw new IllegalStateException("The input file does not have the header tail of a valid Lua file (it may be corrupted).");
            }
        }
    }

    protected void write_tail(OutputStream out, BHeader header, LHeader object) throws IOException {
        for (int i = 0; i < luacTail.length; i++) {
            out.write(luacTail[i]);
        }
    }
}