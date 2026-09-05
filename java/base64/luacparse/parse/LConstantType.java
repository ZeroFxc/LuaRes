package base64.luacparse.parse;

import base64.luacparse.Version;
import base64.luacparse.decompile.OpV;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class LConstantType extends BObjectType<LObject> {

    /* JADX INFO: renamed from: base64.luacparse.parse.LConstantType$1 */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$ConstantType = new int[Version.ConstantType.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$ConstantType[Version.ConstantType.LUA50.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$ConstantType[Version.ConstantType.LUA53.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$ConstantType[Version.ConstantType.LUA54.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
        }
    }

    public static LConstantType get(Version.ConstantType type) {
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$luacparse$Version$ConstantType[type.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return new LConstantType50();
            case OpV.LUA51 /* 2 */:
                return new LConstantType53();
            case 3:
                return new LConstantType54();
            default:
                throw new IllegalStateException();
        }
    }
}