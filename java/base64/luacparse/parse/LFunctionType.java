package base64.luacparse.parse;

import base64.luacparse.Version;
import base64.luacparse.assemble.Directive;
import base64.luacparse.decompile.OpV;
import base64.luacparse.parse.LHeader;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.List;
import java.util.Objects;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LFunctionType extends BObjectType<LFunction> {
    public abstract List<Directive> get_directives();

    protected abstract void parse_main(ByteBuffer byteBuffer, BHeader bHeader, LFunctionParseState lFunctionParseState);

    /* JADX INFO: renamed from: base64.luacparse.parse.LFunctionType$1, reason: invalid class name */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType = new int[Version.FunctionType.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[Version.FunctionType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[Version.FunctionType.LUA51.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[Version.FunctionType.LUA52.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[Version.FunctionType.LUA53.ordinal()] = 4;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[Version.FunctionType.LUA54.ordinal()] = 5;
            } catch (NoSuchFieldError e5) {
            }
        }
    }

    public static LFunctionType get(Version.FunctionType type) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$FunctionType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return new LFunctionType50();
            case OpV.LUA51 /* 2 */:
                return new LFunctionType51();
            case 3:
                return new LFunctionType52();
            case OpV.LUA52 /* 4 */:
                return new LFunctionType53();
            case 5:
                return new LFunctionType54();
            default:
                throw new IllegalStateException();
        }
    }

    protected static class LFunctionParseState {
        BList<LAbsLineInfo> abslineinfo;
        int[] code;
        BList<LObject> constants;
        BList<LFunction> functions;
        int lenParameter;
        int lenUpvalues;
        int length;
        int lineBegin;
        int lineEnd;
        BList<BInteger> lines;
        BList<LLocal> locals;
        int maximumStackSize;
        public LString name;
        LUpvalue[] upvalues;
        int vararg;

        protected LFunctionParseState() {
        }
    }

    @Override // base64.luacparse.parse.BObjectType
    public LFunction parse(ByteBuffer buffer, BHeader header) {
        Objects.requireNonNull(header);
        Objects.requireNonNull(header);
        LFunctionParseState s = new LFunctionParseState();
        parse_main(buffer, header, s);
        int[] lines = new int[s.lines.length.asInt()];
        for (int i = 0; i < lines.length; i++) {
            lines[i] = ((BInteger) s.lines.get(i)).asInt();
        }
        LAbsLineInfo[] abslineinfo = null;
        if (s.abslineinfo != null) {
            abslineinfo = (LAbsLineInfo[]) s.abslineinfo.asArray(new LAbsLineInfo[s.abslineinfo.length.asInt()]);
        }
        LFunction lfunc = new LFunction(header, s.name, s.lineBegin, s.lineEnd, s.code, lines, abslineinfo, (LLocal[]) s.locals.asArray(new LLocal[s.locals.length.asInt()]), (LObject[]) s.constants.asArray(new LObject[s.constants.length.asInt()]), s.upvalues, (LFunction[]) s.functions.asArray(new LFunction[s.functions.length.asInt()]), s.maximumStackSize, s.lenUpvalues, s.lenParameter, s.vararg);
        for (LFunction child : lfunc.functions) {
            child.parent = lfunc;
        }
        if (s.lines.length.asInt() == 0 && s.locals.length.asInt() == 0) {
            lfunc.stripped = true;
        }
        return lfunc;
    }

    protected void parse_code(ByteBuffer buffer, BHeader header, LFunctionParseState s) {
        Objects.requireNonNull(header);
        s.length = header.integer.parse(buffer, header).asInt();
        s.code = new int[s.length];
        for (int i = 0; i < s.length; i++) {
            s.code[i] = buffer.getInt();
            Objects.requireNonNull(header);
        }
    }

    protected void write_code(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.integer.write(out, header, new BInteger(object.code.length));
        for (int i = 0; i < object.code.length; i++) {
            int codepoint = object.code[i];
            if (header.lheader.endianness == LHeader.LEndianness.LITTLE) {
                out.write((byte) (codepoint & 255));
                out.write((byte) ((codepoint >> 8) & 255));
                out.write((byte) ((codepoint >> 16) & 255));
                out.write((byte) ((codepoint >> 24) & 255));
            } else {
                out.write((byte) ((codepoint >> 24) & 255));
                out.write((byte) ((codepoint >> 16) & 255));
                out.write((byte) ((codepoint >> 8) & 255));
                out.write((byte) (codepoint & 255));
            }
        }
    }

    protected void parse_constants(ByteBuffer buffer, BHeader header, LFunctionParseState s) {
        Objects.requireNonNull(header);
        s.constants = header.constant.parseList(buffer, header);
        Objects.requireNonNull(header);
        s.functions = header.function.parseList(buffer, header);
    }

    protected void write_constants(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.constant.writeList(out, header, object.constants);
        header.function.writeList(out, header, object.functions);
    }

    protected void create_upvalues(ByteBuffer buffer, BHeader header, LFunctionParseState s) {
        s.upvalues = new LUpvalue[s.lenUpvalues];
        for (int i = 0; i < s.lenUpvalues; i++) {
            s.upvalues[i] = new LUpvalue();
        }
    }

    protected void parse_upvalues(ByteBuffer buffer, BHeader header, LFunctionParseState s) {
        BList<LUpvalue> upvalues = header.upvalue.parseList(buffer, header);
        s.lenUpvalues = upvalues.length.asInt();
        s.upvalues = (LUpvalue[]) upvalues.asArray(new LUpvalue[s.lenUpvalues]);
    }

    protected void write_upvalues(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.upvalue.writeList(out, header, object.upvalues);
    }

    protected void parse_debug(ByteBuffer buffer, BHeader header, LFunctionParseState s) {
        Objects.requireNonNull(header);
        s.lines = header.integer.parseList(buffer, header);
        Objects.requireNonNull(header);
        s.locals = header.local.parseList(buffer, header);
        Objects.requireNonNull(header);
        BList<LString> upvalueNames = header.string.parseList(buffer, header);
        for (int i = 0; i < upvalueNames.length.asInt(); i++) {
            s.upvalues[i].bname = (LString) upvalueNames.get(i);
            s.upvalues[i].name = s.upvalues[i].bname.deref();
        }
    }

    protected void write_debug(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.integer.write(out, header, new BInteger(object.lines.length));
        for (int i = 0; i < object.lines.length; i++) {
            header.integer.write(out, header, new BInteger(object.lines[i]));
        }
        header.local.writeList(out, header, object.locals);
        int upvalueNameLength = 0;
        for (LUpvalue upvalue : object.upvalues) {
            if (upvalue.bname == null || upvalue.bname == LString.NULL) {
                break;
            }
            upvalueNameLength++;
        }
        header.integer.write(out, header, new BInteger(upvalueNameLength));
        for (int i2 = 0; i2 < upvalueNameLength; i2++) {
            header.string.write(out, header, object.upvalues[i2].bname);
        }
    }
}