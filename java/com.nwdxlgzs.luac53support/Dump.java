package com.nwdxlgzs.luac53support;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Dump extends defines {
    private DecInterface decInterface;
    private Proto proto;
    private ByteArrayOutputStream stream;

    public Dump(Proto proto, DecInterface decInterface) {
        this.proto = proto;
        if (decInterface != null) {
            this.decInterface = decInterface;
        } else {
            this.decInterface = defines.NULL_Decoder;
        }
    }

    private void writeHeader() throws IOException {
        writeLiteral(defines.LUA_SIGNATURE);
        writeByte(defines.LUAC_VERSION[0]);
        writeByte(defines.LUAC_FORMAT[0]);
        writeLiteral(defines.LUAC_DATA);
        writeByte((byte) defines.sizeof_int);
        writeByte((byte) defines.sizeof_size_t);
        writeByte((byte) defines.sizeof_Instruction);
        writeByte((byte) defines.sizeof_lua_Integer);
        writeByte((byte) defines.sizeof_lua_Number);
        writeLiteral(defines.LUAC_INT);
        writeLiteral(defines.LUAC_NUM);
    }

    private void writeCode(Proto proto) throws IOException {
        writeInt(proto.sizecode);
        for (int i = 0; i < proto.sizecode; i++) {
            writeInstruction(proto.code.get(i));
        }
    }

    private void writeConstants(Proto proto) throws IOException {
        writeInt(proto.sizek);
        for (int i = 0; i < proto.sizek; i++) {
            TValue tValue = proto.k.get(i);
            writeByte((byte) tValue.tt_);
            switch (proto.k.get(i).tt_) {
                case TValue.LUA_TBOOLEAN /* 1 */:
                    writeByte((byte) (tValue.getBoolean() ? 1 : 0));
                    break;
                case 3:
                    writeNumber(tValue.getFLT());
                    break;
                case 4:
                case TValue.LUA_TLNGSTR /* 20 */:
                    writeString(tValue);
                    break;
                case TValue.LUA_TNUMINT /* 19 */:
                    writeInteger(tValue.getINT());
                    break;
            }
        }
    }

    private void writeProtos(Proto proto) throws IOException {
        writeInt(proto.sizep);
        for (int i = 0; i < proto.sizep; i++) {
            writeFunction(proto.p.get(i));
        }
    }

    private void writeUpvalues(Proto proto) throws IOException {
        writeInt(proto.sizeupvalues);
        for (int i = 0; i < proto.sizeupvalues; i++) {
            Upvaldesc upvaldesc = proto.upvalues.get(i);
            writeByte(upvaldesc.instack);
            writeByte(upvaldesc.idx);
        }
    }

    private void writeDebug(Proto proto) throws IOException {
        if (this.decInterface.requireStrip() || proto.sizelineinfo == 0 || proto.sizelocvars == 0) {
            writeInt(0);
            writeInt(0);
            writeInt(0);
            return;
        }
        writeInt(proto.sizelineinfo);
        for (int i = 0; i < proto.sizelineinfo; i++) {
            writeInt(proto.lineinfo.get(i).intValue());
        }
        writeInt(proto.sizelocvars);
        for (int i2 = 0; i2 < proto.sizelocvars; i2++) {
            LocVar locVar = proto.locvars.get(i2);
            writeString(locVar.varname);
            writeInt(locVar.startpc);
            writeInt(locVar.endpc);
        }
        writeInt(proto.sizeupvalues);
        for (int i3 = 0; i3 < proto.sizeupvalues; i3++) {
            writeString(proto.upvalues.get(i3).name);
        }
    }

    private void writeFunction(Proto proto) throws IOException {
        if (this.decInterface.requireStrip() || proto.sizelineinfo == 0 || proto.sizelocvars == 0) {
            writeString(TValue.NIL);
        } else {
            writeString(proto.source);
        }
        writeInt(proto.linedefined);
        writeInt(proto.lastlinedefined);
        writeByte(proto.numparams);
        writeByte(proto.is_vararg);
        writeByte(proto.maxstacksize);
        writeCode(proto);
        writeConstants(proto);
        writeUpvalues(proto);
        writeProtos(proto);
        writeDebug(proto);
    }

    public void dump() throws IOException {
        this.stream = new ByteArrayOutputStream();
        writeHeader();
        writeByte((byte) (this.proto.sizeupvalues & 255));
        writeFunction(this.proto);
    }

    private void writeByte(byte b) {
        this.stream.write(b);
    }

    private void writeLiteral(String str) throws IOException {
        writeLiteral(str.getBytes());
    }

    private void writeLiteral(byte[] bArr) throws IOException {
        this.stream.write(bArr);
    }

    private void writeInt(int i) throws IOException {
        this.stream.write(defines.int2bytes(i));
    }

    private void writeNumber(double d) throws IOException {
        this.stream.write(defines.FLT2bytes(d));
    }

    private void writeInteger(long j) throws IOException {
        this.stream.write(defines.INT2bytes(j));
    }

    private void writeString(TValue tValue) throws IOException {
        if (tValue == TValue.NIL || tValue.tt_ == 0) {
            writeByte((byte) 0);
            return;
        }
        byte[] stringBytes = tValue.getStringBytes();
        int length = stringBytes.length + 1;
        if (length < 255) {
            writeByte((byte) length);
        } else {
            writeByte((byte) -1);
            writeInt(length);
        }
        writeLiteral(stringBytes);
    }

    private void writeInstruction(Instruction instruction) throws IOException {
        this.stream.write(defines.Instruction2bytes(instruction.value));
    }

    public byte[] getBytes() {
        if (this.stream == null) {
            try {
                dump();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return this.stream.toByteArray();
    }
}