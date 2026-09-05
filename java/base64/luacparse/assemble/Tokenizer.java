package base64.luacparse.assemble;

import java.io.IOException;
import java.io.InputStream;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class Tokenizer {
    private StringBuilder b = new StringBuilder();
    private InputStream in;

    public Tokenizer(InputStream in) {
        this.in = in;
    }

    public String next() throws IOException {
        this.b.setLength(0);
        boolean inToken = false;
        boolean inString = false;
        boolean inComment = false;
        boolean isLPrefix = false;
        boolean inEscape = false;
        while (true) {
            int code = this.in.read();
            if (code == -1) {
                break;
            }
            char c = (char) code;
            if (inString) {
                if (c == '\\' && !inEscape) {
                    inEscape = true;
                    this.b.append(c);
                } else {
                    if (c == '\"' && !inEscape) {
                        this.b.append(c);
                        break;
                    }
                    inEscape = false;
                    this.b.append(c);
                }
            } else if (inComment) {
                if (c == '\n' || c == '\r') {
                    inComment = false;
                    if (inToken) {
                        break;
                    }
                }
            } else if (c == ';') {
                inComment = true;
            } else if (Character.isWhitespace(c)) {
                if (inToken) {
                    break;
                }
            } else {
                if ((!inToken || isLPrefix) && c == '\"') {
                    inString = true;
                } else if (!inToken && c == 'L') {
                    isLPrefix = true;
                } else {
                    isLPrefix = false;
                }
                inToken = true;
                this.b.append(c);
            }
        }
        if (this.b.length() == 0) {
            return null;
        }
        return this.b.toString();
    }
}