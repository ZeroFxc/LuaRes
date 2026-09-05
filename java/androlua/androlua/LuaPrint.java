package com.androlua;

import com.luajava.JavaFunction;
import com.luajava.LuaState;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class LuaPrint extends JavaFunction {

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private LuaState f823b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private LuaContext f824c;
    private StringBuilder d;

    public LuaPrint(LuaContext luaContext, LuaState luaState) {
        super(luaState);
        this.d = new StringBuilder();
        this.f823b = luaState;
        this.f824c = luaContext;
    }

    @Override // com.luajava.JavaFunction
    public int execute() {
        if (this.f823b.getTop() < 2) {
            this.f824c.sendMsg(BuildConfig.FLAVOR);
            return 0;
        }
        for (int i = 2; i <= this.f823b.getTop(); i++) {
            String strLtoString = null;
            String strTypeName = this.f823b.typeName(this.f823b.type(i));
            if (strTypeName.equals("userdata")) {
                Object javaObject = this.f823b.toJavaObject(i);
                if (javaObject != null) {
                    strLtoString = javaObject.toString();
                }
            } else {
                strLtoString = strTypeName.equals("boolean") ? this.f823b.toBoolean(i) ? "true" : "false" : this.f823b.LtoString(i);
            }
            if (strLtoString != null) {
                strTypeName = strLtoString;
            }
            this.d.append("\t");
            this.d.append(strTypeName);
            this.d.append("\t");
        }
        this.f824c.sendMsg(this.d.toString().substring(1, this.d.length() - 1));
        this.d.setLength(0);
        return 0;
    }
}