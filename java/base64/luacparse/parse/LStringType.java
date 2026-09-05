package base64.luacparse.parse;

import base64.luacparse.Version;
import base64.luacparse.decompile.OpV;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LStringType extends BObjectType<LString> {
    protected ThreadLocal<StringBuilder> b = new ThreadLocal<StringBuilder>() { // from class: base64.luacparse.parse.LStringType.1
        AnonymousClass1() {
        }

        @Override // java.lang.ThreadLocal
        protected StringBuilder initialValue() {
            return new StringBuilder();
        }
    };

    /* JADX INFO: renamed from: base64.luacparse.parse.LStringType$2 */
    static /* synthetic */ class AnonymousClass2 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$StringType = new int[Version.StringType.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$StringType[Version.StringType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$StringType[Version.StringType.LUA53.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$StringType[Version.StringType.LUA54.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
        }
    }

    public static LStringType get(Version.StringType type) {
        switch (AnonymousClass2.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$StringType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return new LStringType50();
            case OpV.LUA51 /* 2 */:
                return new LStringType53();
            case 3:
                return new LStringType54();
            default:
                throw new IllegalStateException();
        }
    }

    /* JADX INFO: renamed from: base64.luacparse.parse.LStringType$1 */
    class AnonymousClass1 extends ThreadLocal<StringBuilder> {
        AnonymousClass1() {
        }

        @Override // java.lang.ThreadLocal
        protected StringBuilder initialValue() {
            return new StringBuilder();
        }
    }
}