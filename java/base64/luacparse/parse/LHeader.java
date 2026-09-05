package base64.luacparse.parse;

import base64.luacparse.decompile.CodeExtract;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LHeader extends BObject {
    public final LAbsLineInfoType abslineinfo;
    public final LBooleanType bool;
    public final LConstantType constant;
    public final LEndianness endianness;
    public final CodeExtract extractor;
    public final int format;
    public final LFunctionType function;
    public final BIntegerType integer;
    public final LNumberType lfloat;
    public final LNumberType linteger;
    public final LLocalType local;
    public final LNumberType number;
    public final BIntegerType sizeT;
    public final LStringType string;
    public final LUpvalueType upvalue;

    public enum LEndianness {
        BIG,
        LITTLE
    }

    public LHeader(int format, LEndianness endianness, BIntegerType integer, BIntegerType sizeT, LBooleanType bool, LNumberType number, LNumberType linteger, LNumberType lfloat, LStringType string, LConstantType constant, LAbsLineInfoType abslineinfo, LLocalType local, LUpvalueType upvalue, LFunctionType function, CodeExtract extractor) {
        this.format = format;
        this.endianness = endianness;
        this.integer = integer;
        this.sizeT = sizeT;
        this.bool = bool;
        this.number = number;
        this.linteger = linteger;
        this.lfloat = lfloat;
        this.string = string;
        this.constant = constant;
        this.abslineinfo = abslineinfo;
        this.local = local;
        this.upvalue = upvalue;
        this.function = function;
        this.extractor = extractor;
    }
}