package base64.luacparse.util;

import java.util.ArrayList;
import java.util.Collections;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class Stack<T> {
    private final ArrayList<T> data = new ArrayList<>();

    public boolean isEmpty() {
        return this.data.isEmpty();
    }

    public T peek() {
        return this.data.get(this.data.size() - 1);
    }

    public T peek(int i) {
        return this.data.get((this.data.size() - 1) - i);
    }

    public T pop() {
        return this.data.remove(this.data.size() - 1);
    }

    public void push(T item) {
        if (this.data.size() > 65536) {
            throw new IndexOutOfBoundsException("Trying to push more than 65536 items!");
        }
        this.data.add(item);
    }

    public int size() {
        return this.data.size();
    }

    public void reverse() {
        Collections.reverse(this.data);
    }
}