package com.androlua;

import com.luajava.JavaFunction;
import com.luajava.LuaState;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaPrint extends JavaFunction {
    private LuaState b;
    private LuaContext c;
    private StringBuilder d;

    public LuaPrint(LuaContext luaContext, LuaState luaState) {
        super(luaState);
        this.d = new StringBuilder();
        this.b = luaState;
        this.c = luaContext;
    }

    @Override // com.luajava.JavaFunction
    public int execute() {
        if (this.b.getTop() < 2) {
            this.c.sendMsg(BuildConfig.FLAVOR);
            return 0;
        }
        for (int i = 2; i <= this.b.getTop(); i++) {
            String strLtoString = null;
            String strTypeName = this.b.typeName(this.b.type(i));
            if (strTypeName.equals("userdata")) {
                Object javaObject = this.b.toJavaObject(i);
                if (javaObject != null) {
                    strLtoString = javaObject.toString();
                }
            } else {
                strLtoString = strTypeName.equals("boolean") ? this.b.toBoolean(i) ? "true" : "false" : this.b.LtoString(i);
            }
            if (strLtoString != null) {
                strTypeName = strLtoString;
            }
            this.d.append("\t");
            this.d.append(strTypeName);
            this.d.append("\t");
        }
        this.c.sendMsg(this.d.toString().substring(1, this.d.length() - 1));
        this.d.setLength(0);
        return 0;
    }
}