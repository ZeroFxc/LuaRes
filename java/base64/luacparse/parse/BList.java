package base64.luacparse.parse;

import base64.luacparse.parse.BObject;
import java.util.Iterator;
import java.util.List;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class BList<T extends BObject> extends BObject {
    public final BInteger length;
    private final List<T> values;

    public BList(BInteger length, List<T> values) {
        this.length = length;
        this.values = values;
    }

    public T get(int index) {
        return this.values.get(index);
    }

    public Iterator<T> iterator() {
        return this.values.iterator();
    }

    public T[] asArray(final T[] array) {
        this.length.iterate(new Runnable() { // from class: base64.luacparse.parse.BList.1
            private int i = 0;

            @Override // java.lang.Runnable
            public void run() {
                array[this.i] = (BObject) BList.this.values.get(this.i);
                this.i++;
            }
        });
        return array;
    }
}