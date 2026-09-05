package base64.luacparse.decompile;

import base64.luacparse.Version;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class CodeExtract {
    public final Field A;
    public final Field Ax;
    public final Field B;
    public final Field Bx;
    public final Field C;
    public final Field k;
    public final Field op;
    private final int rk_offset;
    public final Field sBx;
    public final Field sJ;
    public final Field x;

    public static class Field {
        private final int mask;
        private final int offset;
        private final int shift;
        public final int size;

        public Field(int size, int shift) {
            this(size, shift, 0);
        }

        public Field(int size, int shift, int offset) {
            this.size = size;
            this.shift = shift;
            this.mask = CodeExtract.size_to_mask(size);
            this.offset = offset;
        }

        public int extract(int codepoint) {
            return ((codepoint >>> this.shift) & this.mask) - this.offset;
        }

        public boolean check(int x) {
            return ((this.offset + x) & (this.mask ^ (-1))) == 0;
        }

        public int encode(int x) {
            return (this.offset + x) << this.shift;
        }

        public int clear(int codepoint) {
            return ((this.mask << this.shift) ^ (-1)) & codepoint;
        }

        public int max() {
            return this.mask - this.offset;
        }
    }

    /* JADX INFO: renamed from: base64.luacparse.decompile.CodeExtract$1 */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$InstructionFormat = new int[Version.InstructionFormat.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$InstructionFormat[Version.InstructionFormat.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$InstructionFormat[Version.InstructionFormat.LUA51.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$InstructionFormat[Version.InstructionFormat.LUA54.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
        }
    }

    public CodeExtract(Version version, int sizeOp, int sizeA, int sizeB, int sizeC) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$InstructionFormat[version.instructionformat.get().ordinal()]) {
            case OpV.LUA50 /* 1 */:
                this.op = new Field(sizeOp, 0);
                this.A = new Field(sizeA, sizeB + sizeC + sizeOp);
                this.B = new Field(sizeB, sizeB + sizeOp);
                this.C = new Field(sizeC, sizeOp);
                this.k = null;
                this.Ax = null;
                this.sJ = null;
                this.Bx = new Field(sizeB + sizeC, sizeOp);
                this.sBx = new Field(sizeB + sizeC, sizeOp, size_to_mask(sizeB + sizeC) / 2);
                this.x = new Field(32, 0);
                break;
            case OpV.LUA51 /* 2 */:
                this.op = new Field(6, 0);
                this.A = new Field(8, 6);
                this.B = new Field(9, 23);
                this.C = new Field(9, 14);
                this.k = null;
                this.Ax = new Field(26, 6);
                this.sJ = null;
                this.Bx = new Field(18, 14);
                this.sBx = new Field(18, 14, 131071);
                this.x = new Field(32, 0);
                break;
            case 3:
                this.op = new Field(7, 0);
                this.A = new Field(8, 7);
                this.B = new Field(8, 16);
                this.C = new Field(8, 24);
                this.k = new Field(1, 15);
                this.Ax = new Field(25, 7);
                this.sJ = new Field(25, 7, 16777215);
                this.Bx = new Field(17, 15);
                this.sBx = new Field(17, 15, 65535);
                this.x = new Field(32, 0);
                break;
            default:
                throw new IllegalStateException();
        }
        Integer rk_offset = version.rkoffset.get();
        this.rk_offset = rk_offset == null ? -1 : rk_offset.intValue();
    }

    public boolean is_k(int field) {
        return field >= this.rk_offset;
    }

    public int get_k(int field) {
        return field - this.rk_offset;
    }

    public int encode_k(int constant) {
        return this.rk_offset + constant;
    }

    private static int size_to_mask(int size) {
        return (int) ((1 << size) - 1);
    }
}