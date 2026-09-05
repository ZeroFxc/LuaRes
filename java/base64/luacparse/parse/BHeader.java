package base64.luacparse.parse;

import base64.luacparse.Configuration;
import base64.luacparse.Version;
import base64.luacparse.assemble.Tokenizer;
import base64.luacparse.decompile.CodeExtract;
import base64.luacparse.decompile.Op;
import base64.luacparse.decompile.OpcodeMap;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class BHeader {
    private static final byte[] signature = {27, 76, 117, 97};
    public final LAbsLineInfoType abslineinfo;
    public final LBooleanType bool;
    public final Configuration config;
    public final LConstantType constant;
    public final boolean debug;
    public final CodeExtract extractor;
    public final LFunctionType function;
    public final BIntegerType integer;
    public final LNumberType lfloat;
    public final LHeader lheader;
    public final LHeaderType lheader_type;
    public final LNumberType linteger;
    public final LLocalType local;
    public final LFunction main;
    public final LNumberType number;
    public final OpcodeMap opmap;
    public final BIntegerType sizeT;
    public final LStringType string;
    public final LUpvalueType upvalue;
    public final Version version;

    public BHeader(Version version, LHeader lheader) {
        this(version, lheader, null);
    }

    public BHeader(Version version, LHeader lheader, LFunction main) {
        this.debug = false;
        this.config = null;
        this.version = version;
        this.lheader = lheader;
        this.lheader_type = version.getLHeaderType();
        this.integer = lheader.integer;
        this.sizeT = lheader.sizeT;
        this.bool = lheader.bool;
        this.number = lheader.number;
        this.linteger = lheader.linteger;
        this.lfloat = lheader.lfloat;
        this.string = lheader.string;
        this.constant = lheader.constant;
        this.abslineinfo = lheader.abslineinfo;
        this.local = lheader.local;
        this.upvalue = lheader.upvalue;
        this.function = lheader.function;
        this.extractor = lheader.extractor;
        this.opmap = version.getOpcodeMap();
        this.main = main;
    }

    public BHeader(ByteBuffer buffer, Configuration config) {
        this.debug = false;
        this.config = config;
        for (int i = 0; i < signature.length; i++) {
            if (buffer.get() != signature[i]) {
                throw new IllegalStateException("The input file does not have the signature of a valid Lua file.");
            }
        }
        int versionNumber = buffer.get() & 255;
        int major = versionNumber >> 4;
        int minor = versionNumber & 15;
        this.version = Version.getVersion(major, minor);
        if (this.version == null) {
            throw new IllegalStateException("The input chunk's Lua version is " + major + "." + minor + "; unluac can only handle Lua 5.0 - Lua 5.4.");
        }
        this.lheader_type = this.version.getLHeaderType();
        this.lheader = this.lheader_type.parse(buffer, this);
        this.integer = this.lheader.integer;
        this.sizeT = this.lheader.sizeT;
        this.bool = this.lheader.bool;
        this.number = this.lheader.number;
        this.linteger = this.lheader.linteger;
        this.lfloat = this.lheader.lfloat;
        this.string = this.lheader.string;
        this.constant = this.lheader.constant;
        this.abslineinfo = this.lheader.abslineinfo;
        this.local = this.lheader.local;
        this.upvalue = this.lheader.upvalue;
        this.function = this.lheader.function;
        this.extractor = this.lheader.extractor;
        if (config.opmap != null) {
            try {
                Tokenizer t = new Tokenizer(new FileInputStream(new File(config.opmap)));
                Map<Integer, Op> useropmap = new HashMap<>();
                while (true) {
                    String tok = t.next();
                    if (tok != null) {
                        if (tok.equals(".op")) {
                            String tok2 = t.next();
                            if (tok2 == null) {
                                throw new IllegalStateException("Unexpected end of opmap file.");
                            }
                            try {
                                int opcode = Integer.parseInt(tok2);
                                String tok3 = t.next();
                                if (tok3 == null) {
                                    throw new IllegalStateException("Unexpected end of opmap file.");
                                }
                                Op op = this.version.getOpcodeMap().get(tok3);
                                if (op == null) {
                                    throw new IllegalStateException("Unknown op name \"" + tok3 + "\" in opmap file.");
                                }
                                useropmap.put(Integer.valueOf(opcode), op);
                            } catch (NumberFormatException e) {
                                throw new IllegalStateException("Excepted number in opmap file, got \"" + tok2 + "\".");
                            }
                        } else {
                            throw new IllegalStateException("Unexpected token \"" + tok + "\" + in opmap file.");
                        }
                    } else {
                        this.opmap = new OpcodeMap(useropmap);
                        break;
                    }
                }
            } catch (IOException e2) {
                throw new IllegalStateException(e2.getMessage());
            }
        } else {
            this.opmap = this.version.getOpcodeMap();
        }
        int upvalues = versionNumber >= 83 ? buffer.get() & 255 : -1;
        this.main = this.function.parse(buffer, this);
        if (upvalues >= 0 && this.main.numUpvalues != upvalues) {
            throw new IllegalStateException("The main chunk has the wrong number of upvalues: " + this.main.numUpvalues + " (" + upvalues + " expected)");
        }
        if (this.main.numUpvalues >= 1 && versionNumber >= 82 && (this.main.upvalues[0].name == null || this.main.upvalues[0].name.isEmpty())) {
            this.main.upvalues[0].name = "_ENV";
        }
        this.main.setLevel(1);
    }

    public void write(OutputStream out) throws IOException {
        out.write(signature);
        int major = this.version.getVersionMajor();
        int minor = this.version.getVersionMinor();
        int versionNumber = (major << 4) | minor;
        out.write(versionNumber);
        this.version.getLHeaderType().write(out, this, this.lheader);
        if (this.version.useupvaluecountinheader.get().booleanValue()) {
            out.write(this.main.numUpvalues);
        }
        this.function.write(out, this, this.main);
    }
}