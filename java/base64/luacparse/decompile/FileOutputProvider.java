package base64.luacparse.decompile;

import java.io.FileOutputStream;
import java.io.IOException;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class FileOutputProvider implements OutputProvider {
    private final String eol = System.lineSeparator();
    private final FileOutputStream out;

    public FileOutputProvider(FileOutputStream out) {
        this.out = out;
    }

    @Override // base64.luacparse.decompile.OutputProvider
    public void print(String s) {
        for (int i = 0; i < s.length(); i++) {
            int c = s.charAt(i);
            if (c < 0 || c > 255) {
                throw new IllegalStateException();
            }
            print((byte) c);
        }
    }

    @Override // base64.luacparse.decompile.OutputProvider
    public void print(byte b) {
        try {
            this.out.write(b);
        } catch (IOException e) {
            throw new RuntimeException(e.getMessage());
        }
    }

    @Override // base64.luacparse.decompile.OutputProvider
    public void println() {
        print(this.eol);
    }
}