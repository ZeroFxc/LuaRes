package base64.luacparse.parse;

import base64.luacparse.assemble.Directive;
import base64.luacparse.parse.LFunctionType;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;

/* JADX INFO: compiled from: LFunctionType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LFunctionType54 extends LFunctionType {
    LFunctionType54() {
    }

    @Override // base64.luacparse.parse.LFunctionType
    protected void parse_debug(ByteBuffer buffer, BHeader header, LFunctionType.LFunctionParseState s) {
        s.lines = new BIntegerType50(1).parseList(buffer, header);
        s.abslineinfo = header.abslineinfo.parseList(buffer, header);
        s.locals = header.local.parseList(buffer, header);
        BList<LString> upvalueNames = header.string.parseList(buffer, header);
        for (int i = 0; i < upvalueNames.length.asInt(); i++) {
            s.upvalues[i].bname = (LString) upvalueNames.get(i);
            s.upvalues[i].name = s.upvalues[i].bname.deref();
        }
    }

    @Override // base64.luacparse.parse.LFunctionType
    protected void write_debug(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.integer.write(out, header, new BInteger(object.lines.length));
        for (int i = 0; i < object.lines.length; i++) {
            out.write(object.lines[i]);
        }
        header.abslineinfo.writeList(out, header, object.abslineinfo);
        header.local.writeList(out, header, object.locals);
        int upvalueNameLength = 0;
        for (LUpvalue upvalue : object.upvalues) {
            if (upvalue.bname == null) {
                break;
            }
            upvalueNameLength++;
        }
        header.integer.write(out, header, new BInteger(upvalueNameLength));
        for (int i2 = 0; i2 < upvalueNameLength; i2++) {
            header.string.write(out, header, object.upvalues[i2].bname);
        }
    }

    @Override // base64.luacparse.parse.LFunctionType
    protected void parse_main(ByteBuffer buffer, BHeader header, LFunctionType.LFunctionParseState s) {
        s.name = header.string.parse(buffer, header);
        s.lineBegin = header.integer.parse(buffer, header).asInt();
        s.lineEnd = header.integer.parse(buffer, header).asInt();
        s.lenParameter = buffer.get() & 255;
        s.vararg = buffer.get() & 255;
        s.maximumStackSize = buffer.get() & 255;
        parse_code(buffer, header, s);
        s.constants = header.constant.parseList(buffer, header);
        parse_upvalues(buffer, header, s);
        s.functions = header.function.parseList(buffer, header);
        parse_debug(buffer, header, s);
    }

    @Override // base64.luacparse.parse.LFunctionType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.SOURCE, Directive.LINEDEFINED, Directive.LASTLINEDEFINED, Directive.NUMPARAMS, Directive.IS_VARARG, Directive.MAXSTACKSIZE);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.string.write(out, header, object.name);
        header.integer.write(out, header, new BInteger(object.linedefined));
        header.integer.write(out, header, new BInteger(object.lastlinedefined));
        out.write(object.numParams);
        out.write(object.vararg);
        out.write(object.maximumStackSize);
        write_code(out, header, object);
        header.constant.writeList(out, header, object.constants);
        write_upvalues(out, header, object);
        header.function.writeList(out, header, object.functions);
        write_debug(out, header, object);
    }
}