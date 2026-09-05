package base64.luacparse.parse;

import base64.luacparse.parse.BObject;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public abstract class BObjectType<T extends BObject> {
    public abstract T parse(ByteBuffer byteBuffer, BHeader bHeader);

    public abstract void write(OutputStream outputStream, BHeader bHeader, T t) throws IOException;

    public final BList<T> parseList(ByteBuffer buffer, BHeader header) {
        BInteger length = header.integer.parse(buffer, header);
        List<T> values = new ArrayList<>();
        length.iterate(new Runnable() { // from class: base64.luacparse.parse.BObjectType.1
            final /* synthetic */ ByteBuffer val$buffer;
            final /* synthetic */ BHeader val$header;
            final /* synthetic */ List val$values;

            AnonymousClass1(List values2, ByteBuffer buffer2, BHeader header2) {
                list = values2;
                byteBuffer = buffer2;
                bHeader = header2;
            }

            @Override // java.lang.Runnable
            public void run() {
                list.add(BObjectType.this.parse(byteBuffer, bHeader));
            }
        });
        return new BList<>(length, values2);
    }

    /* JADX INFO: renamed from: base64.luacparse.parse.BObjectType$1 */
    class AnonymousClass1 implements Runnable {
        final /* synthetic */ ByteBuffer val$buffer;
        final /* synthetic */ BHeader val$header;
        final /* synthetic */ List val$values;

        AnonymousClass1(List values2, ByteBuffer buffer2, BHeader header2) {
            list = values2;
            byteBuffer = buffer2;
            bHeader = header2;
        }

        @Override // java.lang.Runnable
        public void run() {
            list.add(BObjectType.this.parse(byteBuffer, bHeader));
        }
    }

    public final void writeList(OutputStream out, BHeader header, T[] array) throws IOException {
        header.integer.write(out, header, new BInteger(array.length));
        for (T object : array) {
            write(out, header, object);
        }
    }

    public final void writeList(OutputStream out, BHeader header, BList<T> blist) throws IOException {
        header.integer.write(out, header, blist.length);
        Iterator<T> it = blist.iterator();
        while (it.hasNext()) {
            write(out, header, it.next());
        }
    }
}