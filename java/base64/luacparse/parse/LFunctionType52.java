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
class LFunctionType52 extends LFunctionType {
    LFunctionType52() {
    }

    @Override // base64.luacparse.parse.LFunctionType
    protected void parse_main(ByteBuffer buffer, BHeader header, LFunctionType.LFunctionParseState s) {
        s.lineBegin = header.integer.parse(buffer, header).asInt();
        s.lineEnd = header.integer.parse(buffer, header).asInt();
        s.lenParameter = buffer.get() & 255;
        s.vararg = buffer.get() & 255;
        s.maximumStackSize = buffer.get() & 255;
        parse_code(buffer, header, s);
        parse_constants(buffer, header, s);
        parse_upvalues(buffer, header, s);
        s.name = header.string.parse(buffer, header);
        parse_debug(buffer, header, s);
    }

    @Override // base64.luacparse.parse.LFunctionType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.LINEDEFINED, Directive.LASTLINEDEFINED, Directive.NUMPARAMS, Directive.IS_VARARG, Directive.MAXSTACKSIZE, Directive.SOURCE);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.integer.write(out, header, new BInteger(object.linedefined));
        header.integer.write(out, header, new BInteger(object.lastlinedefined));
        out.write(object.numParams);
        out.write(object.vararg);
        out.write(object.maximumStackSize);
        write_code(out, header, object);
        write_constants(out, header, object);
        write_upvalues(out, header, object);
        header.string.write(out, header, object.name);
        write_debug(out, header, object);
    }
}