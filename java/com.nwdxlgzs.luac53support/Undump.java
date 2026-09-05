package com.nwdxlgzs.luac53support;

import java.util.Collections;

/* loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class Undump extends defines {
    private byte[] data;
    private DecInterface decInterface;
    private int pos;

    public Undump(byte[] bArr, DecInterface decInterface) {
        this.data = bArr;
        if (decInterface != null) {
            this.decInterface = decInterface;
        } else {
            this.decInterface = defines.NULL_Decoder;
        }
    }

    private byte[] readBlock(int i) {
        if (this.pos + i > this.data.length) {
            throw new RuntimeException(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("\u8bfb\u53d6\u6570\u636e\u6ea2\u51fa\uff01\u4f01\u56fe\u4ece").append(this.pos).toString()).append("\u8bfb\u53d6\u957f\u5ea6\u4e3a").toString()).append(i).toString()).append("\u7684\u6570\u636e\uff08\u5df2\u7ecf\u6ea2\u51fa\uff09\uff0c\u4f46\u662f\u6570\u636e\u957f\u5ea6\u4e3a").toString()).append(this.data.length).toString());
        }
        byte[] bArr = new byte[i];
        System.arraycopy(this.data, this.pos, bArr, 0, i);
        this.pos += i;
        return this.decInterface.BlockDecrypt(bArr);
    }

    private void readHeader() {
        byte[] block = readBlock(defines.LUA_SIGNATURE.length);
        for (int i = 0; i < defines.LUA_SIGNATURE.length; i++) {
            if (block[i] != defines.LUA_SIGNATURE[i]) {
                throw new RuntimeException(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("\u4e0d\u662f\u4e00\u4e2aLuaC\u6587\u4ef6\uff01LuaC\u5934\u90e8\u9519\u8bef\uff01\u5934\u90e8\u5e94\u4e3a").append(Collections.singletonList(defines.LUA_SIGNATURE)).toString()).append("\uff0c\u4f46\u662f\u8bfb\u53d6\u5230\u7684\u5934\u90e8\u4e3a").toString()).append(Collections.singletonList(block)).toString());
            }
        }
        if (this.decInterface.ByteDecrypt(readByte()) == defines.LUAC_VERSION[0]) {
            if (this.decInterface.ByteDecrypt(readByte()) != defines.LUAC_FORMAT[0]) {
                throw new RuntimeException("\u5728LuaC\u6587\u4ef6\u4e2d\u4e22\u5931\u683c\u5f0f\u5339\u914d");
            }
            byte[] block2 = readBlock(defines.LUAC_DATA.length);
            for (int i2 = 0; i2 < defines.LUAC_DATA.length; i2++) {
                if (block2[i2] != defines.LUAC_DATA[i2]) {
                    throw new RuntimeException(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("\u4e0d\u662f\u4e00\u4e2aLuaC\u6587\u4ef6\uff01LuaC\u6570\u636e\u9519\u8bef\uff01\u6570\u636e\u5e94\u4e3a").append(Collections.singletonList(defines.LUAC_DATA)).toString()).append("\uff0c\u4f46\u662f\u8bfb\u53d6\u5230\u7684\u6570\u636e\u4e3a").toString()).append(Collections.singletonList(block2)).toString());
                }
            }
            defines.sizeof_int = this.decInterface.ByteDecrypt(readByte());
            defines.sizeof_size_t = this.decInterface.ByteDecrypt(readByte());
            defines.sizeof_Instruction = this.decInterface.ByteDecrypt(readByte());
            defines.sizeof_lua_Integer = this.decInterface.ByteDecrypt(readByte());
            defines.sizeof_lua_Number = this.decInterface.ByteDecrypt(readByte());
            byte[] block3 = readBlock(defines.sizeof_lua_Integer);
            for (int i3 = 0; i3 < defines.sizeof_lua_Integer; i3++) {
                if (block3[i3] != defines.LUAC_INT[i3]) {
                    throw new RuntimeException(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("\u4e0d\u662f\u4e00\u4e2aLuaC\u6587\u4ef6\uff01LuaC\u6574\u6570\u9519\u8bef\uff01\u6574\u6570\u6570\u636e\u5e94\u4e3a").append(Collections.singletonList(defines.LUAC_INT)).toString()).append("\uff0c\u4f46\u662f\u8bfb\u53d6\u5230\u7684\u6574\u6570\u6570\u636e\u4e3a").toString()).append(Collections.singletonList(block3)).toString());
                }
            }
            byte[] block4 = readBlock(defines.sizeof_lua_Number);
            for (int i4 = 0; i4 < defines.sizeof_lua_Number; i4++) {
                if (block4[i4] != defines.LUAC_NUM[i4]) {
                    throw new RuntimeException(new StringBuffer().append(new StringBuffer().append(new StringBuffer().append("\u4e0d\u662f\u4e00\u4e2aLuaC\u6587\u4ef6\uff01LuaC\u6570\u5b57\u9519\u8bef\uff01\u6d6e\u70b9\u6570\u636e\u5e94\u4e3a").append(Collections.singletonList(defines.LUAC_NUM)).toString()).append("\uff0c\u4f46\u662f\u8bfb\u53d6\u5230\u7684\u6d6e\u70b9\u6570\u636e\u4e3a").toString()).append(Collections.singletonList(block4)).toString());
                }
            }
            return;
        }
        throw new RuntimeException("\u5728LuaC\u6587\u4ef6\u4e2d\u4e22\u5931\u7248\u672c\u5339\u914d");
    }

    private void readCode(Proto proto) {
        Integer num;
        boolean z = this.decInterface.OPMapReplace() != null;
        int iNDecrypt = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizecode");
        proto.sizecode = iNDecrypt;
        for (int i = 0; i < iNDecrypt; i++) {
            Instruction instructionInstructionDecrypt = this.decInterface.InstructionDecrypt(new Instruction(readInstruction()));
            if (z && (num = this.decInterface.OPMapReplace().get(new Integer(instructionInstructionDecrypt.opcode))) != null) {
                instructionInstructionDecrypt.opcode = num.intValue();
                instructionInstructionDecrypt.value = defines.SET_OPCODE(instructionInstructionDecrypt.value, num.intValue());
            }
            proto.code.add(instructionInstructionDecrypt);
        }
    }

    private void readUpvalues(Proto proto) {
        int iNDecrypt = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizeupvalues");
        proto.sizeupvalues = iNDecrypt;
        for (int i = 0; i < iNDecrypt; i++) {
            Upvaldesc upvaldesc = new Upvaldesc();
            upvaldesc.instack = this.decInterface.ByteDecrypt(readByte());
            upvaldesc.idx = this.decInterface.ByteDecrypt(readByte());
            proto.upvalues.add(upvaldesc);
        }
    }

    private void readProtos(Proto proto) {
        int iNDecrypt = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizep");
        proto.sizep = iNDecrypt;
        for (int i = 0; i < iNDecrypt; i++) {
            Proto proto2 = new Proto();
            readFunction(proto2);
            proto.p.add(proto2);
        }
    }

    private void readDebug(Proto proto) {
        int iNDecrypt = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizelineinfo");
        for (int i = 0; i < iNDecrypt; i++) {
            proto.lineinfo.add(new Integer((int) readInt()));
        }
        proto.sizelineinfo = iNDecrypt;
        int iNDecrypt2 = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizelocvars");
        for (int i2 = 0; i2 < iNDecrypt2; i2++) {
            LocVar locVar = new LocVar();
            locVar.varname = readTString();
            locVar.startpc = this.decInterface.IntDecrypt((int) readInt());
            locVar.endpc = this.decInterface.IntDecrypt((int) readInt());
            proto.locvars.add(locVar);
        }
        proto.sizelocvars = iNDecrypt2;
        int iNDecrypt3 = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizeupvalues");
        for (int i3 = 0; i3 < iNDecrypt3; i3++) {
            Upvaldesc upvaldesc = proto.upvalues.get(i3);
            if (upvaldesc != null) {
                upvaldesc.name = readTString();
            }
        }
    }

    private void readFunction(Proto proto) {
        proto.source = readTString();
        proto.linedefined = this.decInterface.IntDecrypt((int) readInt());
        proto.lastlinedefined = this.decInterface.IntDecrypt((int) readInt());
        proto.numparams = this.decInterface.ByteDecrypt(readByte());
        proto.is_vararg = this.decInterface.ByteDecrypt(readByte());
        proto.maxstacksize = this.decInterface.ByteDecrypt(readByte());
        readCode(proto);
        readConstants(proto);
        readUpvalues(proto);
        readProtos(proto);
        readDebug(proto);
    }

    private void readConstants(Proto proto) {
        int iNDecrypt = this.decInterface.NDecrypt(this.decInterface.IntDecrypt((int) readInt()), "sizek");
        proto.sizek = iNDecrypt;
        for (int i = 0; i < iNDecrypt; i++) {
            switch (this.decInterface.ByteDecrypt(readByte()) & 255) {
                case TValue.LUA_TNIL /* 0 */:
                    proto.k.add(TValue.NIL);
                    break;
                case TValue.LUA_TBOOLEAN /* 1 */:
                    proto.k.add(this.decInterface.BooleanDecrypt(this.decInterface.ByteDecrypt(readByte()) != 0) ? TValue.TRUE : TValue.FALSE);
                    break;
                case 3:
                    proto.k.add(TValue.createNumber(readNumber()));
                    break;
                case 4:
                case TValue.LUA_TLNGSTR /* 20 */:
                    proto.k.add(readTString());
                    break;
                case TValue.LUA_TNUMINT /* 19 */:
                    proto.k.add(TValue.createInteger(readInteger()));
                    break;
                default:
                    proto.k.add(TValue.NIL);
                    break;
            }
        }
    }

    public Proto parse() {
        Proto proto = new Proto();
        readHeader();
        this.decInterface.ByteDecrypt(readByte());
        readFunction(proto);
        return proto;
    }

    private byte readByte() {
        return readBlock(1)[0];
    }

    private long readInt() {
        return defines.bytes2int(readBlock(defines.sizeof_int));
    }

    private int readInstruction() {
        byte[] block = readBlock(defines.sizeof_Instruction);
        long j = 0;
        for (int i = 0; i < defines.sizeof_Instruction; i++) {
            j |= (block[i] & 255) << (i * 8);
        }
        return (int) j;
    }

    private long readSizeT() {
        byte[] block = readBlock(defines.sizeof_size_t);
        long j = 0;
        for (int i = 0; i < defines.sizeof_size_t; i++) {
            j |= (block[i] & 255) << (i * 8);
        }
        return j;
    }

    private double readNumber() {
        return this.decInterface.NumberDecrypt(defines.bytes2FLT(readBlock(defines.sizeof_lua_Number)));
    }

    private long readInteger() {
        return this.decInterface.IntegerDecrypt(defines.bytes2INT(readBlock(defines.sizeof_lua_Integer)));
    }

    private TValue readTString() {
        TValue tValueCreateString;
        int iByteDecrypt = this.decInterface.ByteDecrypt(readByte()) & 255;
        if (iByteDecrypt == 255) {
            tValueCreateString = TValue.createString(this.decInterface.StringDecrypt(readBlock(this.decInterface.IntDecrypt((int) readSizeT()) - 1)));
        } else if (iByteDecrypt == 0) {
            tValueCreateString = TValue.NIL;
        } else if (iByteDecrypt == 1) {
            tValueCreateString = TValue.EMPTY_STRING;
        } else {
            tValueCreateString = TValue.createString(this.decInterface.StringDecrypt(readBlock(iByteDecrypt - 1)));
        }
        return tValueCreateString;
    }
}