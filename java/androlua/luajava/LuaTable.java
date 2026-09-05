package com.luajava;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaTable<K, V> extends LuaObject implements Map<K, V> {

    public class LuaEntry<K, V> implements Map.Entry<K, V> {

        /* JADX INFO: renamed from: a, reason: collision with root package name */
        private K f1194a;

        /* JADX INFO: renamed from: b, reason: collision with root package name */
        private V f1195b;

        public LuaEntry(K k, V v) {
            this.f1194a = k;
            this.f1195b = v;
        }

        @Override // java.util.Map.Entry
        public K getKey() {
            return this.f1194a;
        }

        @Override // java.util.Map.Entry
        public V getValue() {
            return this.f1195b;
        }

        @Override // java.util.Map.Entry
        public V setValue(V v) {
            V v2 = this.f1195b;
            this.f1195b = v;
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
        this.f1187b.pushNil();
        while (this.f1187b.next(-2) != 0) {
            this.f1187b.pop(1);
            this.f1187b.pushValue(-1);
            this.f1187b.pushNil();
            this.f1187b.setTable(-4);
        }
        this.f1187b.pop(1);
    }

    @Override // java.util.Map
    public boolean containsKey(Object obj) {
        push();
        try {
            this.f1187b.pushObjectValue(obj);
            boolean z = this.f1187b.getTable(-2) != 0;
            this.f1187b.pop(1);
            this.f1187b.pop(1);
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
        this.f1187b.pushNil();
        while (this.f1187b.next(-2) != 0) {
            try {
                hashSet.add(new LuaEntry(this.f1187b.toJavaObject(-2), this.f1187b.toJavaObject(-1)));
            } catch (LuaException unused) {
            }
            this.f1187b.pop(1);
        }
        this.f1187b.pop(1);
        return hashSet;
    }

    @Override // java.util.Map
    public V get(Object obj) {
        push();
        V v = null;
        try {
            this.f1187b.pushObjectValue(obj);
            this.f1187b.getTable(-2);
            v = (V) this.f1187b.toJavaObject(-1);
            this.f1187b.pop(1);
        } catch (LuaException unused) {
        }
        this.f1187b.pop(1);
        return v;
    }

    @Override // java.util.Map
    public boolean isEmpty() {
        push();
        this.f1187b.pushNil();
        boolean z = this.f1187b.next(-2) == 0;
        if (z) {
            this.f1187b.pop(1);
        } else {
            this.f1187b.pop(3);
        }
        return z;
    }

    public boolean isList() {
        push();
        if (this.f1187b.rawLen(-1) != 0) {
            pop();
            return true;
        }
        this.f1187b.pushNil();
        boolean z = this.f1187b.next(-2) == 0;
        if (z) {
            this.f1187b.pop(1);
        } else {
            this.f1187b.pop(3);
        }
        return z;
    }

    @Override // java.util.Map
    public Set<K> keySet() {
        HashSet hashSet = new HashSet();
        push();
        this.f1187b.pushNil();
        while (this.f1187b.next(-2) != 0) {
            try {
                hashSet.add(this.f1187b.toJavaObject(-2));
            } catch (LuaException unused) {
            }
            this.f1187b.pop(1);
        }
        this.f1187b.pop(1);
        return hashSet;
    }

    public int length() {
        push();
        int iRawLen = this.f1187b.rawLen(-1);
        pop();
        return iRawLen;
    }

    @Override // java.util.Map
    public V put(K k, V v) {
        push();
        try {
            this.f1187b.pushObjectValue(k);
            this.f1187b.pushObjectValue(v);
            this.f1187b.setTable(-3);
        } catch (LuaException unused) {
        }
        this.f1187b.pop(1);
        return null;
    }

    @Override // java.util.Map
    public void putAll(Map map) {
    }

    @Override // java.util.Map
    public V remove(Object obj) {
        push();
        try {
            this.f1187b.pushObjectValue(obj);
            this.f1187b.setTable(-2);
        } catch (LuaException unused) {
        }
        this.f1187b.pop(1);
        return null;
    }

    @Override // java.util.Map
    public int size() {
        push();
        this.f1187b.pushNil();
        int i = 0;
        while (this.f1187b.next(-2) != 0) {
            i++;
            this.f1187b.pop(1);
        }
        this.f1187b.pop(1);
        return i;
    }

    @Override // java.util.Map
    public Collection<V> values() {
        ArrayList arrayList = new ArrayList();
        push();
        this.f1187b.pushNil();
        while (this.f1187b.next(-2) != 0) {
            try {
                arrayList.add(this.f1187b.toJavaObject(-1));
            } catch (LuaException unused) {
            }
            this.f1187b.pop(1);
        }
        this.f1187b.pop(1);
        return arrayList;
    }
}