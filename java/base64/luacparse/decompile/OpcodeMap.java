package base64.luacparse.decompile;

import base64.luacparse.Version;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class OpcodeMap {
    private Map<String, Op> lookup;
    private Op[] map;

    public OpcodeMap(Map<Integer, Op> useropmap) {
        int max = -1;
        Iterator<Integer> it = useropmap.keySet().iterator();
        while (it.hasNext()) {
            int opcode = it.next().intValue();
            max = Math.max(opcode, max);
        }
        this.map = new Op[max + 1];
        for (Map.Entry<Integer, Op> entry : useropmap.entrySet()) {
            this.map[entry.getKey().intValue()] = entry.getValue();
        }
        setup_lookup(false);
    }

    /* JADX INFO: renamed from: base64.luacparse.decompile.OpcodeMap$1, reason: invalid class name */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType = new int[Version.OpcodeMapType.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[Version.OpcodeMapType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[Version.OpcodeMapType.LUA51.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[Version.OpcodeMapType.LUA52.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[Version.OpcodeMapType.LUA53.ordinal()] = 4;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[Version.OpcodeMapType.LUA54.ordinal()] = 5;
            } catch (NoSuchFieldError e5) {
            }
        }
    }

    public OpcodeMap(Version.OpcodeMapType type) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$OpcodeMapType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                this.map = new Op[35];
                this.map[0] = Op.MOVE;
                this.map[1] = Op.LOADK;
                this.map[2] = Op.LOADBOOL;
                this.map[3] = Op.LOADNIL;
                this.map[4] = Op.GETUPVAL;
                this.map[5] = Op.GETGLOBAL;
                this.map[6] = Op.GETTABLE;
                this.map[7] = Op.SETGLOBAL;
                this.map[8] = Op.SETUPVAL;
                this.map[9] = Op.SETTABLE;
                this.map[10] = Op.NEWTABLE50;
                this.map[11] = Op.SELF;
                this.map[12] = Op.ADD;
                this.map[13] = Op.SUB;
                this.map[14] = Op.MUL;
                this.map[15] = Op.DIV;
                this.map[16] = Op.POW;
                this.map[17] = Op.UNM;
                this.map[18] = Op.NOT;
                this.map[19] = Op.CONCAT;
                this.map[20] = Op.JMP;
                this.map[21] = Op.EQ;
                this.map[22] = Op.LT;
                this.map[23] = Op.LE;
                this.map[24] = Op.TEST50;
                this.map[25] = Op.CALL;
                this.map[26] = Op.TAILCALL;
                this.map[27] = Op.RETURN;
                this.map[28] = Op.FORLOOP;
                this.map[29] = Op.TFORLOOP;
                this.map[30] = Op.TFORPREP;
                this.map[31] = Op.SETLIST50;
                this.map[32] = Op.SETLISTO;
                this.map[33] = Op.CLOSE;
                this.map[34] = Op.CLOSURE;
                break;
            case OpV.LUA51 /* 2 */:
                this.map = new Op[38];
                this.map[0] = Op.MOVE;
                this.map[1] = Op.LOADK;
                this.map[2] = Op.LOADBOOL;
                this.map[3] = Op.LOADNIL;
                this.map[4] = Op.GETUPVAL;
                this.map[5] = Op.GETGLOBAL;
                this.map[6] = Op.GETTABLE;
                this.map[7] = Op.SETGLOBAL;
                this.map[8] = Op.SETUPVAL;
                this.map[9] = Op.SETTABLE;
                this.map[10] = Op.NEWTABLE;
                this.map[11] = Op.SELF;
                this.map[12] = Op.ADD;
                this.map[13] = Op.SUB;
                this.map[14] = Op.MUL;
                this.map[15] = Op.DIV;
                this.map[16] = Op.MOD;
                this.map[17] = Op.POW;
                this.map[18] = Op.UNM;
                this.map[19] = Op.NOT;
                this.map[20] = Op.LEN;
                this.map[21] = Op.CONCAT;
                this.map[22] = Op.JMP;
                this.map[23] = Op.EQ;
                this.map[24] = Op.LT;
                this.map[25] = Op.LE;
                this.map[26] = Op.TEST;
                this.map[27] = Op.TESTSET;
                this.map[28] = Op.CALL;
                this.map[29] = Op.TAILCALL;
                this.map[30] = Op.RETURN;
                this.map[31] = Op.FORLOOP;
                this.map[32] = Op.FORPREP;
                this.map[33] = Op.TFORLOOP;
                this.map[34] = Op.SETLIST;
                this.map[35] = Op.CLOSE;
                this.map[36] = Op.CLOSURE;
                this.map[37] = Op.VARARG;
                break;
            case 3:
                this.map = new Op[40];
                this.map[0] = Op.MOVE;
                this.map[1] = Op.LOADK;
                this.map[2] = Op.LOADKX;
                this.map[3] = Op.LOADBOOL;
                this.map[4] = Op.LOADNIL52;
                this.map[5] = Op.GETUPVAL;
                this.map[6] = Op.GETTABUP;
                this.map[7] = Op.GETTABLE;
                this.map[8] = Op.SETTABUP;
                this.map[9] = Op.SETUPVAL;
                this.map[10] = Op.SETTABLE;
                this.map[11] = Op.NEWTABLE;
                this.map[12] = Op.SELF;
                this.map[13] = Op.ADD;
                this.map[14] = Op.SUB;
                this.map[15] = Op.MUL;
                this.map[16] = Op.DIV;
                this.map[17] = Op.MOD;
                this.map[18] = Op.POW;
                this.map[19] = Op.UNM;
                this.map[20] = Op.NOT;
                this.map[21] = Op.LEN;
                this.map[22] = Op.CONCAT;
                this.map[23] = Op.JMP52;
                this.map[24] = Op.EQ;
                this.map[25] = Op.LT;
                this.map[26] = Op.LE;
                this.map[27] = Op.TEST;
                this.map[28] = Op.TESTSET;
                this.map[29] = Op.CALL;
                this.map[30] = Op.TAILCALL;
                this.map[31] = Op.RETURN;
                this.map[32] = Op.FORLOOP;
                this.map[33] = Op.FORPREP;
                this.map[34] = Op.TFORCALL;
                this.map[35] = Op.TFORLOOP52;
                this.map[36] = Op.SETLIST52;
                this.map[37] = Op.CLOSURE;
                this.map[38] = Op.VARARG;
                this.map[39] = Op.EXTRAARG;
                break;
            case OpV.LUA52 /* 4 */:
                this.map = new Op[47];
                this.map[0] = Op.MOVE;
                this.map[1] = Op.LOADK;
                this.map[2] = Op.LOADKX;
                this.map[3] = Op.LOADBOOL;
                this.map[4] = Op.LOADNIL52;
                this.map[5] = Op.GETUPVAL;
                this.map[6] = Op.GETTABUP;
                this.map[7] = Op.GETTABLE;
                this.map[8] = Op.SETTABUP;
                this.map[9] = Op.SETUPVAL;
                this.map[10] = Op.SETTABLE;
                this.map[11] = Op.NEWTABLE;
                this.map[12] = Op.SELF;
                this.map[13] = Op.ADD;
                this.map[14] = Op.SUB;
                this.map[15] = Op.MUL;
                this.map[16] = Op.MOD;
                this.map[17] = Op.POW;
                this.map[18] = Op.DIV;
                this.map[19] = Op.IDIV;
                this.map[20] = Op.BAND;
                this.map[21] = Op.BOR;
                this.map[22] = Op.BXOR;
                this.map[23] = Op.SHL;
                this.map[24] = Op.SHR;
                this.map[25] = Op.UNM;
                this.map[26] = Op.BNOT;
                this.map[27] = Op.NOT;
                this.map[28] = Op.LEN;
                this.map[29] = Op.CONCAT;
                this.map[30] = Op.JMP52;
                this.map[31] = Op.EQ;
                this.map[32] = Op.LT;
                this.map[33] = Op.LE;
                this.map[34] = Op.TEST;
                this.map[35] = Op.TESTSET;
                this.map[36] = Op.CALL;
                this.map[37] = Op.TAILCALL;
                this.map[38] = Op.RETURN;
                this.map[39] = Op.FORLOOP;
                this.map[40] = Op.FORPREP;
                this.map[41] = Op.TFORCALL;
                this.map[42] = Op.TFORLOOP52;
                this.map[43] = Op.SETLIST52;
                this.map[44] = Op.CLOSURE;
                this.map[45] = Op.VARARG;
                this.map[46] = Op.EXTRAARG;
                break;
            case 5:
                this.map = new Op[83];
                this.map[0] = Op.MOVE;
                this.map[1] = Op.LOADI;
                this.map[2] = Op.LOADF;
                this.map[3] = Op.LOADK;
                this.map[4] = Op.LOADKX;
                this.map[5] = Op.LOADFALSE;
                this.map[6] = Op.LFALSESKIP;
                this.map[7] = Op.LOADTRUE;
                this.map[8] = Op.LOADNIL52;
                this.map[9] = Op.GETUPVAL;
                this.map[10] = Op.SETUPVAL;
                this.map[11] = Op.GETTABUP54;
                this.map[12] = Op.GETTABLE54;
                this.map[13] = Op.GETI;
                this.map[14] = Op.GETFIELD;
                this.map[15] = Op.SETTABUP54;
                this.map[16] = Op.SETTABLE54;
                this.map[17] = Op.SETI;
                this.map[18] = Op.SETFIELD;
                this.map[19] = Op.NEWTABLE54;
                this.map[20] = Op.SELF54;
                this.map[21] = Op.ADDI;
                this.map[22] = Op.ADDK;
                this.map[23] = Op.SUBK;
                this.map[24] = Op.MULK;
                this.map[25] = Op.MODK;
                this.map[26] = Op.POWK;
                this.map[27] = Op.DIVK;
                this.map[28] = Op.IDIVK;
                this.map[29] = Op.BANDK;
                this.map[30] = Op.BORK;
                this.map[31] = Op.BXORK;
                this.map[32] = Op.SHRI;
                this.map[33] = Op.SHLI;
                this.map[34] = Op.ADD54;
                this.map[35] = Op.SUB54;
                this.map[36] = Op.MUL54;
                this.map[37] = Op.MOD54;
                this.map[38] = Op.POW54;
                this.map[39] = Op.DIV54;
                this.map[40] = Op.IDIV54;
                this.map[41] = Op.BAND54;
                this.map[42] = Op.BOR54;
                this.map[43] = Op.BXOR54;
                this.map[44] = Op.SHL54;
                this.map[45] = Op.SHR54;
                this.map[46] = Op.MMBIN;
                this.map[47] = Op.MMBINI;
                this.map[48] = Op.MMBINK;
                this.map[49] = Op.UNM;
                this.map[50] = Op.BNOT;
                this.map[51] = Op.NOT;
                this.map[52] = Op.LEN;
                this.map[53] = Op.CONCAT54;
                this.map[54] = Op.CLOSE;
                this.map[55] = Op.TBC;
                this.map[56] = Op.JMP54;
                this.map[57] = Op.EQ54;
                this.map[58] = Op.LT54;
                this.map[59] = Op.LE54;
                this.map[60] = Op.EQK;
                this.map[61] = Op.EQI;
                this.map[62] = Op.LTI;
                this.map[63] = Op.LEI;
                this.map[64] = Op.GTI;
                this.map[65] = Op.GEI;
                this.map[66] = Op.TEST54;
                this.map[67] = Op.TESTSET54;
                this.map[68] = Op.CALL;
                this.map[69] = Op.TAILCALL54;
                this.map[70] = Op.RETURN54;
                this.map[71] = Op.RETURN0;
                this.map[72] = Op.RETURN1;
                this.map[73] = Op.FORLOOP54;
                this.map[74] = Op.FORPREP54;
                this.map[75] = Op.TFORPREP54;
                this.map[76] = Op.TFORCALL54;
                this.map[77] = Op.TFORLOOP54;
                this.map[78] = Op.SETLIST54;
                this.map[79] = Op.CLOSURE;
                this.map[80] = Op.VARARG54;
                this.map[81] = Op.VARARGPREP;
                this.map[82] = Op.EXTRAARG;
                break;
            default:
                throw new IllegalStateException();
        }
        setup_lookup(true);
    }

    public Op get(int opNumber) {
        if (opNumber < 0 || opNumber >= this.map.length) {
            return null;
        }
        return this.map[opNumber];
    }

    public Op get(String name) {
        return this.lookup.get(name);
    }

    public int size() {
        return this.map.length;
    }

    private void setup_lookup(boolean validate) {
        this.lookup = new HashMap();
        for (int i = 0; i < this.map.length; i++) {
            if (this.map[i] != null) {
                String name = this.map[i].name;
                if (!this.lookup.containsKey(name)) {
                    this.lookup.put(name, this.map[i]);
                } else if (validate) {
                    throw new IllegalStateException(name);
                }
            } else if (validate) {
                throw new IllegalStateException();
            }
        }
    }
}