package base64.luacparse.parse;

import java.nio.ByteBuffer;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class LSourceLines {
    public static LSourceLines parse(ByteBuffer buffer) {
        int number = buffer.getInt();
        while (true) {
            int number2 = number;
            number = number2 - 1;
            if (number2 > 0) {
                buffer.getInt();
            } else {
                return null;
            }
        }
    }
}