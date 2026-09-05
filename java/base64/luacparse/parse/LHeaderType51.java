package base64.luacparse.parse;

import base64.luacparse.assemble.Directive;
import base64.luacparse.parse.LHeaderType;
import base64.luacparse.parse.LNumberType;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;

/* JADX INFO: compiled from: LHeaderType.java */
/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
class LHeaderType51 extends LHeaderType {
    LHeaderType51() {
    }

    @Override // base64.luacparse.parse.LHeaderType
    protected void parse_main(ByteBuffer buffer, BHeader header, LHeaderType.LHeaderParseState s) {
        parse_format(buffer, header, s);
        parse_endianness(buffer, header, s);
        parse_int_size(buffer, header, s);
        parse_size_t_size(buffer, header, s);
        parse_instruction_size(buffer, header, s);
        parse_number_size(buffer, header, s);
        parse_number_integrality(buffer, header, s);
        s.number = new LNumberType(s.lNumberSize, s.lNumberIntegrality, LNumberType.NumberMode.MODE_NUMBER);
    }

    @Override // base64.luacparse.parse.LHeaderType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.FORMAT, Directive.ENDIANNESS, Directive.INT_SIZE, Directive.SIZE_T_SIZE, Directive.INSTRUCTION_SIZE, Directive.NUMBER_FORMAT);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LHeader object) throws IOException {
        write_format(out, header, object);
        write_endianness(out, header, object);
        write_int_size(out, header, object);
        write_size_t_size(out, header, object);
        write_instruction_size(out, header, object);
        write_number_size(out, header, object);
        write_number_integrality(out, header, object);
    }
}