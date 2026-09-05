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
class LFunctionType50 extends LFunctionType {
    LFunctionType50() {
    }

    @Override // base64.luacparse.parse.LFunctionType
    protected void parse_main(ByteBuffer buffer, BHeader header, LFunctionType.LFunctionParseState s) {
        s.name = header.string.parse(buffer, header);
        s.lineBegin = header.integer.parse(buffer, header).asInt();
        s.lineEnd = 0;
        s.lenUpvalues = buffer.get() & 255;
        create_upvalues(buffer, header, s);
        s.lenParameter = buffer.get() & 255;
        s.vararg = buffer.get() & 255;
        s.maximumStackSize = buffer.get() & 255;
        parse_debug(buffer, header, s);
        parse_constants(buffer, header, s);
        parse_code(buffer, header, s);
    }

    @Override // base64.luacparse.parse.LFunctionType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.SOURCE, Directive.LINEDEFINED, Directive.NUMPARAMS, Directive.IS_VARARG, Directive.MAXSTACKSIZE);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LFunction object) throws IOException {
        header.string.write(out, header, object.name);
        header.integer.write(out, header, new BInteger(object.linedefined));
        out.write(object.numUpvalues);
        out.write(object.numParams);
        out.write(object.vararg);
        out.write(object.maximumStackSize);
        write_debug(out, header, object);
        write_constants(out, header, object);
        write_code(out, header, object);
    }
}