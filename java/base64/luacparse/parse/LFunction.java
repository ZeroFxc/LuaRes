package base64.luacparse.parse;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LFunction extends BObject {
    public LAbsLineInfo[] abslineinfo;
    public int[] code;
    public LObject[] constants;
    public LFunction[] functions;
    public BHeader header;
    public int lastlinedefined;
    public int level;
    public int linedefined;
    public int[] lines;
    public LLocal[] locals;
    public int maximumStackSize;
    public LString name;
    public int numParams;
    public int numUpvalues;
    public LFunction parent;
    public boolean stripped = false;
    public LUpvalue[] upvalues;
    public int vararg;

    public LFunction(BHeader header, LString name, int linedefined, int lastlinedefined, int[] code, int[] lines, LAbsLineInfo[] abslineinfo, LLocal[] locals, LObject[] constants, LUpvalue[] upvalues, LFunction[] functions, int maximumStackSize, int numUpValues, int numParams, int vararg) {
        this.header = header;
        this.name = name;
        this.linedefined = linedefined;
        this.lastlinedefined = lastlinedefined;
        this.code = code;
        this.lines = lines;
        this.abslineinfo = abslineinfo;
        this.locals = locals;
        this.constants = constants;
        this.upvalues = upvalues;
        this.functions = functions;
        this.maximumStackSize = maximumStackSize;
        this.numUpvalues = numUpValues;
        this.numParams = numParams;
        this.vararg = vararg;
    }

    public void setLevel(int level) {
        this.level = level;
        for (LFunction f : this.functions) {
            f.setLevel(level + 1);
        }
    }
}