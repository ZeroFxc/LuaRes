package com.nwdxlgzs.luac53support;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class TValue {
    public static final int LUAI_MAXSHORTLEN = 40;
    public static final int LUA_TBOOLEAN = 1;
    public static final int LUA_TLNGSTR = 20;
    public static final int LUA_TNIL = 0;
    public static final int LUA_TNUMBER = 3;
    public static final int LUA_TNUMFLT = 3;
    public static final int LUA_TNUMINT = 19;
    public static final int LUA_TSHRSTR = 4;
    public static final int LUA_TSTRING = 4;
    public int tt_;
    public Object value_;
    public static final TValue NIL = createNil();
    public static final TValue TRUE = createBoolean(true);
    public static final TValue FALSE = createBoolean(false);
    public static final TValue EMPTY_STRING = createString("");

    public void getNil() {
        if (this.tt_ != 0) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TNIL");
        }
    }

    public boolean getBoolean() {
        if (this.tt_ != 1) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TBOOLEAN");
        }
        return ((Boolean) this.value_).booleanValue();
    }

    public String getString() {
        if (this.tt_ != 4 && this.tt_ != 20) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TSHRSTR\u6216LUA_TLNGSTR");
        }
        return new String((byte[]) this.value_);
    }

    public byte[] getStringBytes() {
        if (this.tt_ != 4 && this.tt_ != 20) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TSHRSTR\u6216LUA_TLNGSTR");
        }
        return (byte[]) this.value_;
    }

    public double getFLT() {
        if (this.tt_ != 3) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TNUMFLT");
        }
        return ((Double) this.value_).doubleValue();
    }

    public long getINT() {
        if (this.tt_ != 19) {
            throw new RuntimeException("TValue\u4e0d\u662fLUA_TNUMINT");
        }
        return ((Long) this.value_).longValue();
    }

    public static TValue createNil() {
        TValue tValue = new TValue();
        tValue.tt_ = 0;
        return tValue;
    }

    public static TValue createBoolean(boolean z) {
        TValue tValue = new TValue();
        tValue.tt_ = 1;
        tValue.value_ = new Boolean(z);
        return tValue;
    }

    public static TValue createNumber(double d) {
        TValue tValue = new TValue();
        tValue.tt_ = 3;
        tValue.value_ = new Double(d);
        return tValue;
    }

    public static TValue createInteger(long j) {
        TValue tValue = new TValue();
        tValue.tt_ = 19;
        tValue.value_ = new Long(j);
        return tValue;
    }

    public static TValue createString(String str) {
        return createString(str.getBytes());
    }

    public static TValue createString(byte[] bArr) {
        TValue tValue = new TValue();
        tValue.value_ = bArr;
        tValue.tt_ = bArr.length <= 40 ? 4 : 20;
        return tValue;
    }

    public String toString() {
        switch (this.tt_) {
            case LUA_TNIL /* 0 */:
                return "nil";
            case LUA_TBOOLEAN /* 1 */:
                return ((Boolean) this.value_).booleanValue() ? "true" : "false";
            case 3:
                return String.valueOf(((Double) this.value_).doubleValue());
            case 4:
            case LUA_TLNGSTR /* 20 */:
                if (this.value_ == null) {
                    return "null";
                }
                return new String((byte[]) this.value_);
            case LUA_TNUMINT /* 19 */:
                return String.valueOf(((Long) this.value_).longValue());
            default:
                return "unknown type";
        }
    }
}