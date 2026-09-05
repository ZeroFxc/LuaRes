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
class LHeaderType50 extends LHeaderType {
    private static final double TEST_NUMBER = 3.1415926535897933E7d;

    LHeaderType50() {
    }

    @Override // base64.luacparse.parse.LHeaderType
    protected void parse_main(ByteBuffer buffer, BHeader header, LHeaderType.LHeaderParseState s) {
        s.format = 0;
        parse_endianness(buffer, header, s);
        parse_int_size(buffer, header, s);
        parse_size_t_size(buffer, header, s);
        parse_instruction_size(buffer, header, s);
        parse_extractor(buffer, header, s);
        parse_number_size(buffer, header, s);
        LNumberType lfloat = new LNumberType(s.lNumberSize, false, LNumberType.NumberMode.MODE_NUMBER);
        LNumberType linteger = new LNumberType(s.lNumberSize, true, LNumberType.NumberMode.MODE_NUMBER);
        buffer.mark();
        double floatcheck = lfloat.parse(buffer, header).value();
        buffer.reset();
        double intcheck = linteger.parse(buffer, header).value();
        if (floatcheck == lfloat.convert(TEST_NUMBER)) {
            s.number = lfloat;
        } else {
            if (intcheck == linteger.convert(TEST_NUMBER)) {
                s.number = linteger;
                return;
            }
            throw new IllegalStateException("The input chunk is using an unrecognized number format: " + intcheck);
        }
    }

    @Override // base64.luacparse.parse.LHeaderType
    public List<Directive> get_directives() {
        return Arrays.asList(Directive.ENDIANNESS, Directive.INT_SIZE, Directive.SIZE_T_SIZE, Directive.INSTRUCTION_SIZE, Directive.SIZE_OP, Directive.SIZE_A, Directive.SIZE_B, Directive.SIZE_C, Directive.NUMBER_FORMAT);
    }

    @Override // base64.luacparse.parse.BObjectType
    public void write(OutputStream out, BHeader header, LHeader object) throws IOException {
        write_endianness(out, header, object);
        write_int_size(out, header, object);
        write_size_t_size(out, header, object);
        write_instruction_size(out, header, object);
        write_extractor(out, header, object);
        write_number_size(out, header, object);
        object.number.write(out, header, object.number.create(TEST_NUMBER));
    }
}