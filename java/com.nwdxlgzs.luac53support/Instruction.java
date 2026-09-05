package com.nwdxlgzs.luac53support;

import com.nwdxlgzs.luac53support.OPCode;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Instruction {
    public int A;
    public int Ax;
    public int B;
    public int Bx;
    public int C;
    public OPCode opName;
    public int opcode;
    public int sBx;
    public int value;

    public Instruction(int i) {
        this.value = i;
        this.opcode = defines.GET_OPCODE(i);
        this.opName = OPCode.fromValue(this.opcode);
        OPCode.OpMode mode = this.opName.getMode();
        if (mode == OPCode.OpMode.iABC) {
            this.A = defines.GETARG_A(i);
            this.B = defines.GETARG_B(i);
            this.C = defines.GETARG_C(i);
            return;
        }
        if (mode == OPCode.OpMode.iABx) {
            this.A = defines.GETARG_A(i);
            this.Bx = defines.GETARG_Bx(i);
            return;
        }
        if (mode == OPCode.OpMode.iAsBx) {
            this.A = defines.GETARG_A(i);
            this.sBx = defines.GETARG_sBx(i);
        } else {
            if (mode == OPCode.OpMode.iAx) {
                this.Ax = defines.GETARG_Ax(i);
                return;
            }
            this.A = defines.GETARG_A(i);
            this.B = defines.GETARG_B(i);
            this.C = defines.GETARG_C(i);
            this.Bx = defines.GETARG_Bx(i);
            this.sBx = defines.GETARG_sBx(i);
            this.Ax = defines.GETARG_Ax(i);
        }
    }

    public String toString() {
        OPCode.OpMode mode = this.opName.getMode();
        if (mode == OPCode.OpMode.iABC) {
            return new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Instruction{").append("\r\n").toString()).append("value=").toString()).append(this.value).toString()).append("\r\n").toString()).append(", opcode=").toString()).append(this.opcode).toString()).append("\r\n").toString()).append(", opName=").toString()).append(this.opName).toString()).append("\r\n").toString()).append(", A=").toString()).append(this.A).toString()).append("\r\n").toString()).append(", B=").toString()).append(this.B).toString()).append("\r\n").toString()).append(", C=").toString()).append(this.C).toString()).append("\r\n").toString()).append('}').toString();
        }
        if (mode == OPCode.OpMode.iABx) {
            return new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Instruction{").append("\r\n").toString()).append("value=").toString()).append(this.value).toString()).append("\r\n").toString()).append(", opcode=").toString()).append(this.opcode).toString()).append("\r\n").toString()).append(", opName=").toString()).append(this.opName).toString()).append("\r\n").toString()).append(", A=").toString()).append(this.A).toString()).append("\r\n").toString()).append(", Bx=").toString()).append(this.Bx).toString()).append("\r\n").toString()).append('}').toString();
        }
        if (mode == OPCode.OpMode.iAsBx) {
            return new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Instruction{").append("\r\n").toString()).append("value=").toString()).append(this.value).toString()).append("\r\n").toString()).append(", opcode=").toString()).append(this.opcode).toString()).append("\r\n").toString()).append(", opName=").toString()).append(this.opName).toString()).append("\r\n").toString()).append(", A=").toString()).append(this.A).toString()).append("\r\n").toString()).append(", sBx=").toString()).append(this.sBx).toString()).append("\r\n").toString()).append('}').toString();
        }
        return mode == OPCode.OpMode.iAx ? new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Instruction{").append("\r\n").toString()).append("value=").toString()).append(this.value).toString()).append("\r\n").toString()).append(", opcode=").toString()).append(this.opcode).toString()).append("\r\n").toString()).append(", opName=").toString()).append(this.opName).toString()).append("\r\n").toString()).append(", Ax=").toString()).append(this.Ax).toString()).append("\r\n").toString()).append('}').toString() : new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("Instruction{").append("\r\n").toString()).append("value=").toString()).append(this.value).toString()).append("\r\n").toString()).append(", opcode=").toString()).append(this.opcode).toString()).append("\r\n").toString()).append(", opName=").toString()).append(this.opName).toString()).append("\r\n").toString()).append(", A=").toString()).append(this.A).toString()).append("\r\n").toString()).append(", B=").toString()).append(this.B).toString()).append("\r\n").toString()).append(", C=").toString()).append(this.C).toString()).append("\r\n").toString()).append(", Bx=").toString()).append(this.Bx).toString()).append("\r\n").toString()).append(", sBx=").toString()).append(this.sBx).toString()).append("\r\n").toString()).append(", Ax=").toString()).append(this.Ax).toString()).append("\r\n").toString()).append('}').toString();
    }
}