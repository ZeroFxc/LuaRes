package base64.luacparse.parse;

import base64.luacparse.util.StringUtils;
import java.lang.reflect.Method;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LString extends LObject {
    public static final LString NULL = new LString("");
    public static Method decryptMethod;
    public boolean islong;
    public final String value;

    public LString(String value) {
        this(value, false);
    }

    public LString(String value, boolean islong) {
        if (decryptMethod != null) {
            try {
                char[] chars = value.toCharArray();
                byte[] bytes = new byte[chars.length];
                for (int i = 0; i < chars.length; i++) {
                    bytes[i] = (byte) chars[i];
                }
                byte[] bytes2 = (byte[]) decryptMethod.invoke(null, bytes);
                char[] chars2 = new char[bytes2.length];
                for (int i2 = 0; i2 < bytes2.length; i2++) {
                    chars2[i2] = (char) bytes2[i2];
                }
                value = new String(chars2);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        this.value = value;
        this.islong = islong;
    }

    @Override // base64.luacparse.parse.LObject
    public String deref() {
        return this.value;
    }

    @Override // base64.luacparse.parse.LObject
    public String toPrintString() {
        if (this == NULL) {
            return "null";
        }
        String prefix = "";
        if (this.islong) {
            prefix = "L";
        }
        return prefix + StringUtils.toPrintString(this.value);
    }

    @Override // base64.luacparse.parse.LObject
    public boolean equals(Object o) {
        if (this == NULL || o == NULL) {
            return this == o;
        }
        if (!(o instanceof LString)) {
            return false;
        }
        LString os = (LString) o;
        return os.value.equals(this.value) && os.islong == this.islong;
    }
}