package base64.luacparse;

import base64.luacparse.decompile.Op;
import base64.luacparse.decompile.OpV;
import base64.luacparse.decompile.OpcodeMap;
import base64.luacparse.parse.LConstantType;
import base64.luacparse.parse.LFunctionType;
import base64.luacparse.parse.LHeaderType;
import base64.luacparse.parse.LStringType;
import base64.luacparse.parse.LUpvalueType;
import java.util.HashSet;
import java.util.Set;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class Version {
    public final Setting<Boolean> allowpreceedingsemicolon;
    public final Setting<Boolean> closeinscope;
    public final Setting<CloseSemantics> closesemantics;
    private final Op defaultop;
    public final Setting<String> environmenttable;
    public final Setting<Boolean> extendedrepeatscope;
    public final Setting<Op> fortarget;
    public final Setting<InstructionFormat> instructionformat;
    private final LConstantType lconstanttype;
    private final LFunctionType lfunctiontype;
    private final LHeaderType lheadertype;
    private final LStringType lstringtype;
    private final LUpvalueType lupvaluetype;
    private final int major;
    private final int minor;
    private final String name;
    private final OpcodeMap opcodemap;
    public final Setting<Integer> outerblockscopeadjustment;
    private final Set<String> reservedWords;
    public final Setting<Integer> rkoffset;
    public final Setting<Op> tfortarget;
    public final Setting<UpvalueDeclarationType> upvaluedeclarationtype;
    public final Setting<Boolean> usegoto;
    public final Setting<Boolean> useifbreakrewrite;
    public final Setting<Boolean> usenestinglongstrings;
    public final Setting<Boolean> useupvaluecountinheader;
    public final Setting<VarArgType> varargtype;
    public final Setting<WhileFormat> whileformat;

    public enum CloseSemantics {
        DEFAULT,
        JUMP,
        LUA54
    }

    public enum ConstantType {
        LUA50,
        LUA53,
        LUA54
    }

    public enum FunctionType {
        LUA50,
        LUA51,
        LUA52,
        LUA53,
        LUA54
    }

    public enum HeaderType {
        LUA50,
        LUA51,
        LUA52,
        LUA53,
        LUA54
    }

    public enum InstructionFormat {
        LUA50,
        LUA51,
        LUA54
    }

    public enum OpcodeMapType {
        LUA50,
        LUA51,
        LUA52,
        LUA53,
        LUA54
    }

    public enum StringType {
        LUA50,
        LUA53,
        LUA54
    }

    public enum UpvalueDeclarationType {
        INLINE,
        HEADER
    }

    public enum UpvalueType {
        LUA50,
        LUA54
    }

    public enum VarArgType {
        ARG,
        HYBRID,
        ELLIPSIS
    }

    public enum WhileFormat {
        TOP_CONDITION,
        BOTTOM_CONDITION
    }

    public static Version getVersion(int major, int minor) {
        return new Version(major, minor);
    }

    public static class Setting<T> {
        private final T value;

        public Setting(T value) {
            this.value = value;
        }

        public T get() {
            return this.value;
        }
    }

    private Version(int major, int minor) {
        HeaderType headertype;
        StringType stringtype;
        ConstantType constanttype;
        UpvalueType upvaluetype;
        FunctionType functiontype;
        OpcodeMapType opcodemap;
        this.major = major;
        this.minor = minor;
        this.name = major + "." + minor;
        if (major == 5 && minor >= 0 && minor <= 4) {
            switch (minor) {
                case 0:
                    this.varargtype = new Setting<>(VarArgType.ARG);
                    this.useupvaluecountinheader = new Setting<>(false);
                    headertype = HeaderType.LUA50;
                    stringtype = StringType.LUA50;
                    constanttype = ConstantType.LUA50;
                    upvaluetype = UpvalueType.LUA50;
                    functiontype = FunctionType.LUA50;
                    opcodemap = OpcodeMapType.LUA50;
                    this.defaultop = Op.DEFAULT;
                    this.instructionformat = new Setting<>(InstructionFormat.LUA50);
                    this.outerblockscopeadjustment = new Setting<>(-1);
                    this.extendedrepeatscope = new Setting<>(true);
                    this.closeinscope = new Setting<>(true);
                    this.closesemantics = new Setting<>(CloseSemantics.DEFAULT);
                    this.upvaluedeclarationtype = new Setting<>(UpvalueDeclarationType.INLINE);
                    this.fortarget = new Setting<>(Op.FORLOOP);
                    this.tfortarget = new Setting<>(null);
                    this.whileformat = new Setting<>(WhileFormat.BOTTOM_CONDITION);
                    this.allowpreceedingsemicolon = new Setting<>(false);
                    this.usenestinglongstrings = new Setting<>(true);
                    this.environmenttable = new Setting<>(null);
                    this.useifbreakrewrite = new Setting<>(false);
                    this.usegoto = new Setting<>(false);
                    this.rkoffset = new Setting<>(250);
                    break;
                case OpV.LUA50 /* 1 */:
                    this.varargtype = new Setting<>(VarArgType.HYBRID);
                    this.useupvaluecountinheader = new Setting<>(false);
                    headertype = HeaderType.LUA51;
                    stringtype = StringType.LUA50;
                    constanttype = ConstantType.LUA50;
                    upvaluetype = UpvalueType.LUA50;
                    functiontype = FunctionType.LUA51;
                    opcodemap = OpcodeMapType.LUA51;
                    this.defaultop = Op.DEFAULT;
                    this.instructionformat = new Setting<>(InstructionFormat.LUA51);
                    this.outerblockscopeadjustment = new Setting<>(-1);
                    this.extendedrepeatscope = new Setting<>(false);
                    this.closeinscope = new Setting<>(true);
                    this.closesemantics = new Setting<>(CloseSemantics.DEFAULT);
                    this.upvaluedeclarationtype = new Setting<>(UpvalueDeclarationType.INLINE);
                    this.fortarget = new Setting<>(null);
                    this.tfortarget = new Setting<>(Op.TFORLOOP);
                    this.whileformat = new Setting<>(WhileFormat.TOP_CONDITION);
                    this.allowpreceedingsemicolon = new Setting<>(false);
                    this.usenestinglongstrings = new Setting<>(false);
                    this.environmenttable = new Setting<>(null);
                    this.useifbreakrewrite = new Setting<>(false);
                    this.usegoto = new Setting<>(false);
                    this.rkoffset = new Setting<>(256);
                    break;
                case OpV.LUA51 /* 2 */:
                    this.varargtype = new Setting<>(VarArgType.ELLIPSIS);
                    this.useupvaluecountinheader = new Setting<>(false);
                    headertype = HeaderType.LUA52;
                    stringtype = StringType.LUA50;
                    constanttype = ConstantType.LUA50;
                    upvaluetype = UpvalueType.LUA50;
                    functiontype = FunctionType.LUA52;
                    opcodemap = OpcodeMapType.LUA52;
                    this.defaultop = Op.DEFAULT;
                    this.instructionformat = new Setting<>(InstructionFormat.LUA51);
                    this.outerblockscopeadjustment = new Setting<>(0);
                    this.extendedrepeatscope = new Setting<>(false);
                    this.closeinscope = new Setting<>(null);
                    this.closesemantics = new Setting<>(CloseSemantics.JUMP);
                    this.upvaluedeclarationtype = new Setting<>(UpvalueDeclarationType.HEADER);
                    this.fortarget = new Setting<>(null);
                    this.tfortarget = new Setting<>(Op.TFORCALL);
                    this.whileformat = new Setting<>(WhileFormat.TOP_CONDITION);
                    this.allowpreceedingsemicolon = new Setting<>(true);
                    this.usenestinglongstrings = new Setting<>(false);
                    this.environmenttable = new Setting<>("_ENV");
                    this.useifbreakrewrite = new Setting<>(true);
                    this.usegoto = new Setting<>(true);
                    this.rkoffset = new Setting<>(256);
                    break;
                case 3:
                    this.varargtype = new Setting<>(VarArgType.ELLIPSIS);
                    this.useupvaluecountinheader = new Setting<>(true);
                    headertype = HeaderType.LUA53;
                    stringtype = StringType.LUA53;
                    constanttype = ConstantType.LUA53;
                    upvaluetype = UpvalueType.LUA50;
                    functiontype = FunctionType.LUA53;
                    opcodemap = OpcodeMapType.LUA53;
                    this.defaultop = Op.DEFAULT;
                    this.instructionformat = new Setting<>(InstructionFormat.LUA51);
                    this.outerblockscopeadjustment = new Setting<>(0);
                    this.extendedrepeatscope = new Setting<>(false);
                    this.closeinscope = new Setting<>(null);
                    this.closesemantics = new Setting<>(CloseSemantics.JUMP);
                    this.upvaluedeclarationtype = new Setting<>(UpvalueDeclarationType.HEADER);
                    this.fortarget = new Setting<>(null);
                    this.tfortarget = new Setting<>(Op.TFORCALL);
                    this.whileformat = new Setting<>(WhileFormat.TOP_CONDITION);
                    this.allowpreceedingsemicolon = new Setting<>(true);
                    this.usenestinglongstrings = new Setting<>(false);
                    this.environmenttable = new Setting<>("_ENV");
                    this.useifbreakrewrite = new Setting<>(true);
                    this.usegoto = new Setting<>(true);
                    this.rkoffset = new Setting<>(256);
                    break;
                case OpV.LUA52 /* 4 */:
                    this.varargtype = new Setting<>(VarArgType.ELLIPSIS);
                    this.useupvaluecountinheader = new Setting<>(true);
                    headertype = HeaderType.LUA54;
                    stringtype = StringType.LUA54;
                    constanttype = ConstantType.LUA54;
                    upvaluetype = UpvalueType.LUA54;
                    functiontype = FunctionType.LUA54;
                    opcodemap = OpcodeMapType.LUA54;
                    this.defaultop = Op.DEFAULT54;
                    this.instructionformat = new Setting<>(InstructionFormat.LUA54);
                    this.outerblockscopeadjustment = new Setting<>(0);
                    this.extendedrepeatscope = new Setting<>(false);
                    this.closeinscope = new Setting<>(false);
                    this.closesemantics = new Setting<>(CloseSemantics.LUA54);
                    this.upvaluedeclarationtype = new Setting<>(UpvalueDeclarationType.HEADER);
                    this.fortarget = new Setting<>(null);
                    this.tfortarget = new Setting<>(null);
                    this.whileformat = new Setting<>(WhileFormat.TOP_CONDITION);
                    this.allowpreceedingsemicolon = new Setting<>(true);
                    this.usenestinglongstrings = new Setting<>(false);
                    this.environmenttable = new Setting<>("_ENV");
                    this.useifbreakrewrite = new Setting<>(true);
                    this.usegoto = new Setting<>(true);
                    this.rkoffset = new Setting<>(null);
                    break;
                default:
                    throw new IllegalStateException();
            }
            this.reservedWords = new HashSet();
            this.reservedWords.add("and");
            this.reservedWords.add("break");
            this.reservedWords.add("do");
            this.reservedWords.add("else");
            this.reservedWords.add("elseif");
            this.reservedWords.add("end");
            this.reservedWords.add("false");
            this.reservedWords.add("for");
            this.reservedWords.add("function");
            this.reservedWords.add("if");
            this.reservedWords.add("in");
            this.reservedWords.add("local");
            this.reservedWords.add("nil");
            this.reservedWords.add("not");
            this.reservedWords.add("or");
            this.reservedWords.add("repeat");
            this.reservedWords.add("return");
            this.reservedWords.add("then");
            this.reservedWords.add("true");
            this.reservedWords.add("until");
            this.reservedWords.add("while");
            if (this.usegoto.get().booleanValue()) {
                this.reservedWords.add("goto");
            }
            this.lheadertype = LHeaderType.get(headertype);
            this.lstringtype = LStringType.get(stringtype);
            this.lconstanttype = LConstantType.get(constanttype);
            this.lupvaluetype = LUpvalueType.get(upvaluetype);
            this.lfunctiontype = LFunctionType.get(functiontype);
            this.opcodemap = new OpcodeMap(opcodemap);
            return;
        }
        throw new IllegalStateException();
    }

    public int getVersionMajor() {
        return this.major;
    }

    public int getVersionMinor() {
        return this.minor;
    }

    public String getName() {
        return this.name;
    }

    public boolean isEnvironmentTable(String name) {
        String env = this.environmenttable.get();
        if (env != null) {
            return name.equals(env);
        }
        return false;
    }

    public boolean isReserved(String name) {
        return this.reservedWords.contains(name);
    }

    public LHeaderType getLHeaderType() {
        return this.lheadertype;
    }

    public LStringType getLStringType() {
        return this.lstringtype;
    }

    public LConstantType getLConstantType() {
        return this.lconstanttype;
    }

    public LUpvalueType getLUpvalueType() {
        return this.lupvaluetype;
    }

    public LFunctionType getLFunctionType() {
        return this.lfunctiontype;
    }

    public OpcodeMap getOpcodeMap() {
        return this.opcodemap;
    }

    public Op getDefaultOp() {
        return this.defaultop;
    }
}