package base64.luacparse.util;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class StringUtils {
    public static String toPrintString(String s) {
        if (s == null) {
            return "null";
        }
        StringBuilder b = new StringBuilder();
        b.append('\"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\"') {
                b.append("\\\"");
            } else if (c != '\\') {
                if (c >= ' ' && c <= '~') {
                    b.append(c);
                } else if (c == '\n') {
                    b.append("\\n");
                } else if (c == '\t') {
                    b.append("\\t");
                } else if (c == '\r') {
                    b.append("\\r");
                } else if (c == '\b') {
                    b.append("\\b");
                } else if (c != '\f') {
                    if (c != 11) {
                        if (c == 7) {
                            b.append("\\a");
                        } else {
                            b.append(String.format("\\x%02x", Integer.valueOf(c)));
                        }
                    } else {
                        b.append("\\v");
                    }
                } else {
                    b.append("\\f");
                }
            } else {
                b.append("\\\\");
            }
        }
        b.append('\"');
        return b.toString();
    }

    public static String fromPrintString(String s) {
        if (s.equals("null")) {
            return null;
        }
        if (s.charAt(0) != '\"') {
            throw new IllegalStateException("Bad string " + s);
        }
        if (s.charAt(s.length() - 1) != '\"') {
            throw new IllegalStateException("Bad string " + s);
        }
        StringBuilder b = new StringBuilder();
        int i = 1;
        while (i < s.length() - 1) {
            int i2 = i + 1;
            char c = s.charAt(i);
            if (c == '\\') {
                if (i2 >= s.length() - 1) {
                    return null;
                }
                i = i2 + 1;
                char c2 = s.charAt(i2);
                if (c2 == '\"') {
                    b.append('\"');
                } else if (c2 == '\\') {
                    b.append('\\');
                } else if (c2 == 'n') {
                    b.append('\n');
                } else if (c2 == 't') {
                    b.append('\t');
                } else if (c2 == 'r') {
                    b.append('\r');
                } else if (c2 == 'b') {
                    b.append('\b');
                } else if (c2 == 'f') {
                    b.append('\f');
                } else if (c2 == 'v') {
                    b.append((char) 11);
                } else if (c2 == 'a') {
                    b.append((char) 7);
                } else {
                    if (c2 != 'x' || i + 1 >= s.length() - 1) {
                        return null;
                    }
                    String digits = s.substring(i, i + 2);
                    i += 2;
                    b.append((char) Integer.parseInt(digits, 16));
                }
            } else {
                b.append(c);
                i = i2;
            }
        }
        return b.toString();
    }

    private StringUtils() {
    }
}