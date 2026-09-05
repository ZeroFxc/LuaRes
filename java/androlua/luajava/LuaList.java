package com.luajava;

import java.util.Collection;
import java.util.Iterator;
import java.util.List;
import java.util.ListIterator;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaList extends LuaObject implements List {
    public LuaList(LuaState luaState) {
        super(luaState);
        luaState.newTable();
        a(-1);
    }

    @Override // java.util.List
    public void add(int i, Object obj) {
    }

    @Override // java.util.List, java.util.Collection
    public boolean add(Object obj) {
        push();
        int iRawLen = this.f1187b.rawLen(-1);
        try {
            this.f1187b.pushObjectValue(obj);
            this.f1187b.setI(-2, iRawLen + 1);
            pop();
            return true;
        } catch (LuaException unused) {
            pop();
            return false;
        }
    }

    @Override // java.util.List
    public boolean addAll(int i, Collection collection) {
        return false;
    }

    @Override // java.util.List, java.util.Collection
    public boolean addAll(Collection collection) {
        return false;
    }

    @Override // java.util.List, java.util.Collection
    public void clear() {
    }

    @Override // java.util.List, java.util.Collection
    public boolean contains(Object obj) {
        return false;
    }

    @Override // java.util.List, java.util.Collection
    public boolean containsAll(Collection collection) {
        return false;
    }

    @Override // java.util.List
    public Object get(int i) {
        return null;
    }

    @Override // java.util.List
    public int indexOf(Object obj) {
        return 0;
    }

    @Override // java.util.List, java.util.Collection
    public boolean isEmpty() {
        push();
        int iRawLen = this.f1187b.rawLen(-1);
        this.f1187b.pop(1);
        return iRawLen == 0;
    }

    @Override // java.util.List, java.util.Collection, java.lang.Iterable
    public Iterator iterator() {
        return null;
    }

    @Override // java.util.List
    public int lastIndexOf(Object obj) {
        return 0;
    }

    @Override // java.util.List
    public ListIterator listIterator() {
        return null;
    }

    @Override // java.util.List
    public ListIterator listIterator(int i) {
        return null;
    }

    @Override // java.util.List
    public Object remove(int i) {
        return null;
    }

    @Override // java.util.List, java.util.Collection
    public boolean remove(Object obj) {
        return false;
    }

    @Override // java.util.List, java.util.Collection
    public boolean removeAll(Collection collection) {
        return false;
    }

    @Override // java.util.List, java.util.Collection
    public boolean retainAll(Collection collection) {
        return false;
    }

    @Override // java.util.List
    public Object set(int i, Object obj) {
        return null;
    }

    @Override // java.util.List, java.util.Collection
    public int size() {
        push();
        int iRawLen = this.f1187b.rawLen(-1);
        this.f1187b.pop(1);
        return iRawLen;
    }

    @Override // java.util.List
    public List subList(int i, int i2) {
        return null;
    }

    @Override // java.util.List, java.util.Collection
    public Object[] toArray() {
        return null;
    }

    @Override // java.util.List, java.util.Collection
    public Object[] toArray(Object[] objArr) {
        return null;
    }
}