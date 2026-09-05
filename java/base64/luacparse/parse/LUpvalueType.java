package base64.luacparse.parse;

import base64.luacparse.Version;
import base64.luacparse.decompile.OpV;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LUpvalueType extends BObjectType<LUpvalue> {

    /* JADX INFO: renamed from: base64.luacparse.parse.LUpvalueType$1 */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$UpvalueType = new int[Version.UpvalueType.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$UpvalueType[Version.UpvalueType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$UpvalueType[Version.UpvalueType.LUA54.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
        }
    }

    public static LUpvalueType get(Version.UpvalueType type) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$UpvalueType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return new LUpvalueType50();
            case OpV.LUA51 /* 2 */:
                return new LUpvalueType54();
            default:
                throw new IllegalStateException();
        }
    }
}