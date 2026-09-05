package base64.luacparse.parse;

import base64.luacparse.assemble.Directive;
import base64.luacparse.parse.LHeaderType;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;

/* JADX INFO: compiled from: LHeaderType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LHeaderType53 extends LHeaderType {
    LHeaderType53() {
    }

    @Override // base64.luacparse.parse.LHeaderType
    protected void parse_main(ByteBuffer buffer, BHeader header, LHeaderType.LHeaderParseState s) {
        parse_format(buffer, header, s);
        parse_tail(buffer, header, s);
        parse_int_size(buffer, header, s);
        parse_size_t_size(buffer, header, s);
        parse_instruction_size(buffer, header, s);
        parse_integer_size(buffer, header, s);
        parse_float_size(buffer, header, s);
        parse_number_format_53(buffer, header, s);
    }

    @Override // base64.luacparse.parse.LHeaderType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.FORMAT, Directive.INT_SIZE, Directive.SIZE_T_SIZE, Directive.INSTRUCTION_SIZE, Directive.INTEGER_FORMAT, Directive.FLOAT_FORMAT, Directive.ENDIANNESS);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LHeader object) throws IOException {
        write_format(out, header, object);
        write_tail(out, header, object);
        write_int_size(out, header, object);
        write_size_t_size(out, header, object);
        write_instruction_size(out, header, object);
        out.write(header.linteger.size);
        out.write(header.lfloat.size);
        header.linteger.write(out, header, header.linteger.create(22136.0d));
        header.lfloat.write(out, header, header.lfloat.create(370.5d));
    }
}