package com.luajava;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaTable<K, V> extends LuaObject implements Map<K, V> {

    public class LuaEntry<K, V> implements Map.Entry<K, V> {
        private K b;
        private V c;

        public LuaEntry(K k, V v) {
            this.b = k;
            this.c = v;
        }

        @Override // java.util.Map.Entry
        public K getKey() {
            return this.b;
        }

        @Override // java.util.Map.Entry
        public V getValue() {
            return this.c;
        }

        @Override // java.util.Map.Entry
        public V setValue(V v) {
            V v2 = this.c;
            this.c = v;
            return v2;
        }
    }

    public LuaTable(LuaState luaState) {
        super(luaState);
        luaState.newTable();
        a(-1);
    }

    protected LuaTable(LuaState luaState, int i) {
        super(luaState, i);
    }

    @Override // java.util.Map
    public void clear() {
        push();
        this.b.pushNil();
        while (this.b.next(-2) != 0) {
            this.b.pop(1);
            this.b.pushValue(-1);
            this.b.pushNil();
            this.b.setTable(-4);
        }
        this.b.pop(1);
    }

    @Override // java.util.Map
    public boolean containsKey(Object obj) {
        push();
        try {
            this.b.pushObjectValue(obj);
            boolean z = this.b.getTable(-2) != 0;
            this.b.pop(1);
            this.b.pop(1);
            return z;
        } catch (LuaException unused) {
            return false;
        }
    }

    @Override // java.util.Map
    public boolean containsValue(Object obj) {
        return false;
    }

    @Override // java.util.Map
    public Set<Map.Entry<K, V>> entrySet() {
        HashSet hashSet = new HashSet();
        push();
        this.b.pushNil();
        while (this.b.next(-2) != 0) {
            try {
                hashSet.add(new LuaEntry(this.b.toJavaObject(-2), this.b.toJavaObject(-1)));
            } catch (LuaException unused) {
            }
            this.b.pop(1);
        }
        this.b.pop(1);
        return hashSet;
    }

    @Override // java.util.Map
    public V get(Object obj) {
        V v;
        push();
        try {
            this.b.pushObjectValue(obj);
            this.b.getTable(-2);
            v = (V) this.b.toJavaObject(-1);
            try {
                this.b.pop(1);
            } catch (LuaException unused) {
            }
        } catch (LuaException unused2) {
            v = null;
        }
        this.b.pop(1);
        return v;
    }

    @Override // java.util.Map
    public boolean isEmpty() {
        push();
        this.b.pushNil();
        boolean z = this.b.next(-2) == 0;
        if (z) {
            this.b.pop(1);
            return z;
        }
        this.b.pop(3);
        return z;
    }

    public boolean isList() {
        push();
        if (this.b.rawLen(-1) != 0) {
            pop();
            return true;
        }
        this.b.pushNil();
        boolean z = this.b.next(-2) == 0;
        if (z) {
            this.b.pop(1);
            return z;
        }
        this.b.pop(3);
        return z;
    }

    @Override // java.util.Map
    public Set<K> keySet() {
        HashSet hashSet = new HashSet();
        push();
        this.b.pushNil();
        while (this.b.next(-2) != 0) {
            try {
                hashSet.add(this.b.toJavaObject(-2));
            } catch (LuaException unused) {
            }
            this.b.pop(1);
        }
        this.b.pop(1);
        return hashSet;
    }

    public int length() {
        push();
        int iRawLen = this.b.rawLen(-1);
        pop();
        return iRawLen;
    }

    @Override // java.util.Map
    public V put(K k, V v) {
        push();
        try {
            this.b.pushObjectValue(k);
            this.b.pushObjectValue(v);
            this.b.setTable(-3);
        } catch (LuaException unused) {
        }
        this.b.pop(1);
        return null;
    }

    @Override // java.util.Map
    public void putAll(Map map) {
    }

    @Override // java.util.Map
    public V remove(Object obj) {
        push();
        try {
            this.b.pushObjectValue(obj);
            this.b.setTable(-2);
        } catch (LuaException unused) {
        }
        this.b.pop(1);
        return null;
    }

    @Override // java.util.Map
    public int size() {
        push();
        this.b.pushNil();
        int i = 0;
        while (this.b.next(-2) != 0) {
            i++;
            this.b.pop(1);
        }
        this.b.pop(1);
        return i;
    }

    @Override // java.util.Map
    public Collection<V> values() {
        ArrayList arrayList = new ArrayList();
        push();
        this.b.pushNil();
        while (this.b.next(-2) != 0) {
            try {
                arrayList.add(this.b.toJavaObject(-1));
            } catch (LuaException unused) {
            }
            this.b.pop(1);
        }
        this.b.pop(1);
        return arrayList;
    }
}