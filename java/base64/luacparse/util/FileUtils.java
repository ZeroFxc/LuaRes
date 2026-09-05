package base64.luacparse.util;

import base64.DecTool;
import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.Charset;
import java.nio.charset.CharsetEncoder;
import java.nio.charset.CoderResult;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class FileUtils {
    public static InputStream createSmartTextFileReader(File file) throws IOException {
        BufferedInputStream input = new BufferedInputStream(new FileInputStream(file));
        byte[] header = new byte[2];
        int header_length = 0;
        input.mark(header.length);
        do {
            int n = input.read(header, header_length, header.length - header_length);
            if (n == -1) {
                break;
            }
            header_length += n;
        } while (header_length < header.length);
        if (header.length >= 2 && header[0] == -1 && header[1] == -2) {
            return readerToUTF8Stream(new InputStreamReader(input, "UTF-16LE"));
        }
        if (header.length >= 2 && header[0] == -2 && header[1] == -1) {
            return readerToUTF8Stream(new InputStreamReader(input, "UTF-16BE"));
        }
        input.reset();
        return input;
    }

    public static InputStream readerToUTF8Stream(final Reader r) {
        final CharsetEncoder encoder = Charset.forName(DecTool.Base64.DEFAULT_ENCODING).newEncoder();
        final CharBuffer chars = CharBuffer.allocate(2);
        final ByteBuffer buffer = ByteBuffer.allocate(8);
        buffer.limit(0);
        return new InputStream() { // from class: base64.luacparse.util.FileUtils.1
            @Override // java.io.InputStream
            public int read() throws IOException {
                int result;
                if (buffer.position() < buffer.limit()) {
                    return buffer.get() & 255;
                }
                int result2 = r.read();
                if (result2 > 127) {
                    char c = (char) result2;
                    chars.position(0);
                    chars.limit(1);
                    chars.put(c);
                    if (Character.isSurrogate(c) && (result = r.read()) >= 0) {
                        chars.limit(2);
                        chars.put((char) result);
                    }
                    chars.position(0);
                    buffer.limit(buffer.capacity());
                    buffer.position(0);
                    encoder.reset();
                    CoderResult coderResult = encoder.encode(chars, buffer, true);
                    if (coderResult.isError() || coderResult.isOverflow()) {
                        throw new IllegalStateException(coderResult.toString());
                    }
                    buffer.limit(buffer.position());
                    buffer.position(0);
                    return read();
                }
                return result2;
            }
        };
    }

    private FileUtils() {
    }
}