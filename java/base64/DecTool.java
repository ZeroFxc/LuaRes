package base64;

import base64.luacparse.Configuration;
import base64.luacparse.decompile.OpV;
import base64.luacparse.parse.BHeader;
import base64.luacparse.parse.LString;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.zip.Inflater;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes(2).dex */
public class DecTool {
    private static final byte[] luaSignature = {27, 76, 117, 97};

    public enum DecMode {
        Error,
        Normal,
        XorDecrypt,
        StringDecrypt,
        Base64Decrypt,
        ZlibDecrypt,
        Unknown
    }

    public static byte[] Method_StringDecrypt(byte[] bArr) {
        byte[] bArr2 = new byte[bArr.length];
        if (bArr.length > 0) {
            int length = bArr.length;
            bArr2[0] = (byte) (bArr[0] ^ (length % 255));
            int unsignedInt = Byte.toUnsignedInt(bArr2[0]) + bArr.length;
            for (int i = 1; i < bArr.length; i++) {
                length += unsignedInt;
                bArr2[i] = (byte) (bArr[i] ^ (length % 255));
            }
        }
        return bArr2;
    }

    public static void main(String[] args) {
        decryptFile("D:\\project\\javaProject\\decrypt\\a.lua", "D:\\project\\javaProject\\decrypt\\a.out.lua");
    }

    public static DecMode analyzeMode(byte[] data) {
        if (data == null || data.length == 0) {
            return DecMode.Error;
        }
        if (data[0] == 61) {
            return DecMode.Base64Decrypt;
        }
        if (data[0] == 28) {
            return DecMode.ZlibDecrypt;
        }
        if (data[0] == 26) {
            return DecMode.StringDecrypt;
        }
        if (data[0] == luaSignature[0] && data[1] == luaSignature[1] && data[2] == luaSignature[2] && data[3] == luaSignature[3]) {
            return DecMode.Normal;
        }
        if (data[0] == luaSignature[0] && data[1] != luaSignature[1]) {
            return DecMode.XorDecrypt;
        }
        return DecMode.Unknown;
    }

    public static byte[] decryptXorDecrypt(byte[] buff) {
        int size = buff.length;
        byte[] buff1 = new byte[size];
        buff1[0] = 27;
        int t = 0;
        for (int i = 1; i < size; i++) {
            t += size;
            Long v = Long.valueOf((((-2139062143) * ((long) t)) >> 32) + ((long) t));
            int v1 = ((int) (v.longValue() & (-1))) >> 7;
            int v2 = v.intValue() < 0 ? 1 : 0;
            int iii = buff[i] ^ ((t + v1) + v2);
            buff1[i] = (byte) iii;
        }
        return buff1;
    }

    public static byte[] decryptNormal(byte[] buff) {
        int size = buff.length;
        byte[] buff1 = new byte[size];
        System.arraycopy(buff, 0, buff1, 0, size);
        return buff1;
    }

    public static byte[] decryptStringDecrypt(byte[] buff) {
        try {
            buff[0] = 27;
            File templua = File.createTempFile("temp", "lua");
            File tempfile = File.createTempFile("temp", "file");
            templua.deleteOnExit();
            tempfile.deleteOnExit();
            FileOutputStream fos = new FileOutputStream(templua);
            fos.write(buff);
            fos.close();
            Method mm = DecTool.class.getMethod("Method_StringDecrypt", byte[].class);
            mm.setAccessible(true);
            LString.decryptMethod = mm;
            ByteBuffer buffer = ByteBuffer.wrap(buff);
            buffer.order(ByteOrder.LITTLE_ENDIAN);
            Configuration config = new Configuration();
            buffer.rewind();
            BHeader header = new BHeader(buffer, config);
            FileOutputStream fos2 = new FileOutputStream(tempfile);
            header.write(fos2);
            fos2.close();
            FileInputStream fis = new FileInputStream(tempfile);
            byte[] luac = new byte[fis.available()];
            fis.read(luac);
            fis.close();
            LString.decryptMethod = null;
            return luac;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public static byte[] decryptZlibDecrypt(byte[] buff) {
        byte[] output;
        try {
            buff[0] = 120;
            byte[] bArr = new byte[0];
            Inflater inflater = new Inflater();
            inflater.reset();
            inflater.setInput(buff);
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            try {
                try {
                    byte[] result = new byte[1024];
                    while (!inflater.finished()) {
                        int count = inflater.inflate(result);
                        outputStream.write(result, 0, count);
                    }
                    output = outputStream.toByteArray();
                    try {
                        outputStream.close();
                        inflater.end();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                } finally {
                    try {
                        outputStream.close();
                        inflater.end();
                    } catch (IOException e2) {
                        e2.printStackTrace();
                    }
                }
            } catch (Exception e3) {
                output = buff;
                e3.printStackTrace();
            }
            return decryptStringDecrypt(output);
        } catch (Exception e4) {
            throw new RuntimeException(e4);
        }
    }

    public static byte[] decryptBase64Decrypt(byte[] buff) {
        try {
            buff[0] = 72;
            byte[] wxorbuff = Base64.decode(buff);
            int key = 0;
            for (int i = 0; i < wxorbuff.length; i++) {
                key ^= wxorbuff[i];
                wxorbuff[i] = (byte) key;
            }
            return decryptZlibDecrypt(wxorbuff);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /* JADX INFO: renamed from: base64.DecTool$1, reason: invalid class name */
    static /* synthetic */ class AnonymousClass1 {
        static final /* synthetic */ int[] $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode = new int[DecMode.values().length];

        static {
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[DecMode.Normal.ordinal()] = 1;
            } catch (NoSuchFieldError e) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[DecMode.XorDecrypt.ordinal()] = 2;
            } catch (NoSuchFieldError e2) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[DecMode.StringDecrypt.ordinal()] = 3;
            } catch (NoSuchFieldError e3) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[DecMode.ZlibDecrypt.ordinal()] = 4;
            } catch (NoSuchFieldError e4) {
            }
            try {
                $SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[DecMode.Base64Decrypt.ordinal()] = 5;
            } catch (NoSuchFieldError e5) {
            }
        }
    }

    public static byte[] decrypt(byte[] buff) {
        DecMode mode = analyzeMode(buff);
        switch (AnonymousClass1.$SwitchMap$com$nwdxlgzs$decryptofficialluac$DecTool$DecMode[mode.ordinal()]) {
            case OpV.LUA50 /* 1 */:
                return decryptNormal(buff);
            case OpV.LUA51 /* 2 */:
                return decryptXorDecrypt(buff);
            case 3:
                return decryptStringDecrypt(buff);
            case OpV.LUA52 /* 4 */:
                return decryptZlibDecrypt(buff);
            case 5:
                return decryptBase64Decrypt(buff);
            default:
                return buff;
        }
    }

    public static void decryptFile(String in, String out) {
        decryptFile(new File(in), new File(out));
    }

    public static void decryptFile(File in, File out) {
        try {
            FileInputStream fis = new FileInputStream(in);
            byte[] buff = new byte[fis.available()];
            fis.read(buff);
            fis.close();
            byte[] result = decrypt(buff);
            FileOutputStream fos = new FileOutputStream(out);
            fos.write(result);
            fos.close();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public static void decryptDirFiles(String in, String out) {
        decryptDirFiles(new File(in), new File(out));
    }

    public static void decryptDirFiles(File in, File out) {
        ArrayList<File> files = getFiles(in);
        for (File file : files) {
            String tail = file.getAbsolutePath().substring(in.getAbsolutePath().length());
            File outFile = new File(out.getAbsolutePath() + tail);
            decryptFile(file, outFile);
        }
    }

    public static ArrayList<File> getFiles(String path) {
        return getFiles(new File(path));
    }

    public static ArrayList<File> getFiles(File path) {
        ArrayList<File> files = new ArrayList<>();
        File[] fs = path.listFiles();
        for (File f : fs) {
            if (f.isFile()) {
                files.add(f);
            } else {
                files.addAll(getFiles(f));
            }
        }
        return files;
    }

    public static class Base64 {
        public static final String DEFAULT_ENCODING = "UTF-8";

        public static byte[] encode(byte[] byteData) {
            if (byteData == null) {
                throw new IllegalArgumentException("byteData cannot be null");
            }
            byte[] byteDest = new byte[((byteData.length + 2) / 3) * 4];
            int iSrcIdx = 0;
            int iDestIdx = 0;
            while (iSrcIdx < byteData.length - 2) {
                int iDestIdx2 = iDestIdx + 1;
                byteDest[iDestIdx] = (byte) ((byteData[iSrcIdx] >>> 2) & 63);
                int iDestIdx3 = iDestIdx2 + 1;
                byteDest[iDestIdx2] = (byte) (((byteData[iSrcIdx + 1] >>> 4) & 15) | ((byteData[iSrcIdx] << 4) & 63));
                int iDestIdx4 = iDestIdx3 + 1;
                byteDest[iDestIdx3] = (byte) (((byteData[iSrcIdx + 2] >>> 6) & 3) | ((byteData[iSrcIdx + 1] << 2) & 63));
                iDestIdx = iDestIdx4 + 1;
                byteDest[iDestIdx4] = (byte) (byteData[iSrcIdx + 2] & 63);
                iSrcIdx += 3;
            }
            if (iSrcIdx < byteData.length) {
                int iDestIdx5 = iDestIdx + 1;
                byteDest[iDestIdx] = (byte) ((byteData[iSrcIdx] >>> 2) & 63);
                if (iSrcIdx < byteData.length - 1) {
                    int iDestIdx6 = iDestIdx5 + 1;
                    byteDest[iDestIdx5] = (byte) (((byteData[iSrcIdx + 1] >>> 4) & 15) | ((byteData[iSrcIdx] << 4) & 63));
                    byteDest[iDestIdx6] = (byte) ((byteData[iSrcIdx + 1] << 2) & 63);
                    iDestIdx = iDestIdx6 + 1;
                } else {
                    iDestIdx = iDestIdx5 + 1;
                    byteDest[iDestIdx5] = (byte) ((byteData[iSrcIdx] << 4) & 63);
                }
            }
            int iSrcIdx2 = 0;
            while (iSrcIdx2 < iDestIdx) {
                if (byteDest[iSrcIdx2] < 26) {
                    byteDest[iSrcIdx2] = (byte) (byteDest[iSrcIdx2] + 65);
                } else if (byteDest[iSrcIdx2] < 52) {
                    byteDest[iSrcIdx2] = (byte) ((byteDest[iSrcIdx2] + 97) - 26);
                } else if (byteDest[iSrcIdx2] < 62) {
                    byteDest[iSrcIdx2] = (byte) ((byteDest[iSrcIdx2] + 48) - 52);
                } else if (byteDest[iSrcIdx2] < 63) {
                    byteDest[iSrcIdx2] = 43;
                } else {
                    byteDest[iSrcIdx2] = 47;
                }
                iSrcIdx2++;
            }
            while (iSrcIdx2 < byteDest.length) {
                byteDest[iSrcIdx2] = 61;
                iSrcIdx2++;
            }
            return byteDest;
        }

        public static byte[] decode(byte[] byteData) {
            if (byteData == null) {
                throw new IllegalArgumentException("byteData cannot be null");
            }
            byte[] byteTemp = new byte[byteData.length];
            int reviSrcIdx = byteData.length;
            while (reviSrcIdx - 1 > 0 && byteData[reviSrcIdx - 1] == 61) {
                reviSrcIdx--;
            }
            if (reviSrcIdx - 1 == 0) {
                return null;
            }
            byte[] byteDest = new byte[(reviSrcIdx * 3) / 4];
            for (int iSrcIdx = 0; iSrcIdx < reviSrcIdx; iSrcIdx++) {
                if (byteData[iSrcIdx] == 43) {
                    byteTemp[iSrcIdx] = 62;
                } else if (byteData[iSrcIdx] == 47) {
                    byteTemp[iSrcIdx] = 63;
                } else if (byteData[iSrcIdx] < 58) {
                    byteTemp[iSrcIdx] = (byte) ((byteData[iSrcIdx] + 52) - 48);
                } else if (byteData[iSrcIdx] < 91) {
                    byteTemp[iSrcIdx] = (byte) (byteData[iSrcIdx] - 65);
                } else if (byteData[iSrcIdx] < 123) {
                    byteTemp[iSrcIdx] = (byte) ((byteData[iSrcIdx] + 26) - 97);
                }
            }
            int iSrcIdx2 = 0;
            int iDestIdx = 0;
            while (iSrcIdx2 < reviSrcIdx && iDestIdx < (byteDest.length / 3) * 3) {
                int iDestIdx2 = iDestIdx + 1;
                byteDest[iDestIdx] = (byte) (((byteTemp[iSrcIdx2] << 2) & 252) | ((byteTemp[iSrcIdx2 + 1] >>> 4) & 3));
                int iDestIdx3 = iDestIdx2 + 1;
                byteDest[iDestIdx2] = (byte) (((byteTemp[iSrcIdx2 + 1] << 4) & 240) | ((byteTemp[iSrcIdx2 + 2] >>> 2) & 15));
                byteDest[iDestIdx3] = (byte) (((byteTemp[iSrcIdx2 + 2] << 6) & 192) | (byteTemp[iSrcIdx2 + 3] & 63));
                iSrcIdx2 += 4;
                iDestIdx = iDestIdx3 + 1;
            }
            if (iSrcIdx2 < reviSrcIdx) {
                if (iSrcIdx2 < reviSrcIdx - 2) {
                    int iDestIdx4 = iDestIdx + 1;
                    byteDest[iDestIdx] = (byte) (((byteTemp[iSrcIdx2] << 2) & 252) | ((byteTemp[iSrcIdx2 + 1] >>> 4) & 3));
                    int i = iDestIdx4 + 1;
                    byteDest[iDestIdx4] = (byte) (((byteTemp[iSrcIdx2 + 1] << 4) & 240) | ((byteTemp[iSrcIdx2 + 2] >>> 2) & 15));
                    return byteDest;
                }
                if (iSrcIdx2 < reviSrcIdx - 1) {
                    int i2 = iDestIdx + 1;
                    byteDest[iDestIdx] = (byte) (((byteTemp[iSrcIdx2] << 2) & 252) | ((byteTemp[iSrcIdx2 + 1] >>> 4) & 3));
                    return byteDest;
                }
                throw new IllegalArgumentException("Warning: 1 input bytes left to process. This was not Base64 input");
            }
            return byteDest;
        }
    }
}