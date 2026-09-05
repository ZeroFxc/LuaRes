package com.nwdxlgzs.luac53support;

import java.util.ArrayList;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Proto {
    public byte is_vararg;
    public int lastlinedefined;
    public int linedefined;
    public byte maxstacksize;
    public byte numparams;
    public int sizecode;
    public int sizek;
    public int sizelineinfo;
    public int sizelocvars;
    public int sizep;
    public int sizeupvalues;
    public TValue source;
    public ArrayList<TValue> k = new ArrayList<>();
    public ArrayList<Instruction> code = new ArrayList<>();
    public ArrayList<Proto> p = new ArrayList<>();
    public ArrayList<Integer> lineinfo = new ArrayList<>();
    public ArrayList<LocVar> locvars = new ArrayList<>();
    public ArrayList<Upvaldesc> upvalues = new ArrayList<>();

    public String toString() {
        return new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Proto{").append("\r\n").toString()).append("numparams=").toString()).append((int) this.numparams).toString()).append("\r\n").toString()).append(", is_vararg=").toString()).append((int) this.is_vararg).toString()).append("\r\n").toString()).append(", maxstacksize=").toString()).append((int) this.maxstacksize).toString()).append("\r\n").toString()).append(", sizeupvalues=").toString()).append(this.sizeupvalues).toString()).append("\r\n").toString()).append(", sizek=").toString()).append(this.sizek).toString()).append("\r\n").toString()).append(", sizecode=").toString()).append(this.sizecode).toString()).append("\r\n").toString()).append(", sizelineinfo=").toString()).append(this.sizelineinfo).toString()).append("\r\n").toString()).append(", sizep=").toString()).append(this.sizep).toString()).append("\r\n").toString()).append(", sizelocvars=").toString()).append(this.sizelocvars).toString()).append("\r\n").toString()).append(", linedefined=").toString()).append(this.linedefined).toString()).append("\r\n").toString()).append(", lastlinedefined=").toString()).append(this.lastlinedefined).toString()).append("\r\n").toString()).append(", k=").toString()).append(this.k).toString()).append("\r\n").toString()).append(", code=").toString()).append(this.code).toString()).append("\r\n").toString()).append(", p=").toString()).append(this.p).toString()).append("\r\n").toString()).append(", lineinfo=").toString()).append(this.lineinfo).toString()).append("\r\n").toString()).append(", locvars=").toString()).append(this.locvars).toString()).append("\r\n").toString()).append(", upvalues=").toString()).append(this.upvalues).toString()).append("\r\n").toString()).append(", source=").toString()).append(this.source).toString()).append("\r\n").toString()).append('}').toString();
    }
}