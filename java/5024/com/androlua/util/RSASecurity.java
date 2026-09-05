package com.androlua.util;

import com.androlua.LuaApplication;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.security.Key;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.SecureRandom;
import javax.crypto.Cipher;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class RSASecurity {
    private static String a = LuaApplication.getInstance().getLuaExtDir("PublicKey");
    private static String b = LuaApplication.getInstance().getLuaExtDir("PrivateKey");

    public static byte[] decrypt(byte[] bArr) throws Exception {
        ObjectInputStream objectInputStream = null;
        try {
            try {
                ObjectInputStream objectInputStream2 = new ObjectInputStream(new FileInputStream(b));
                try {
                    Key key = (Key) objectInputStream2.readObject();
                    objectInputStream2.close();
                    Cipher cipher = Cipher.getInstance("RSA");
                    cipher.init(2, key);
                    return cipher.doFinal(bArr);
                } catch (Exception e) {
                    throw e;
                } catch (Throwable th) {
                    th = th;
                    objectInputStream = objectInputStream2;
                    objectInputStream.close();
                    throw th;
                }
            } catch (Throwable th2) {
                th = th2;
            }
        } catch (Exception e2) {
            throw e2;
        }
    }

    public static byte[] encrypt(String str) throws Exception {
        generateKeyPair();
        ObjectInputStream objectInputStream = null;
        try {
            try {
                ObjectInputStream objectInputStream2 = new ObjectInputStream(new FileInputStream(a));
                try {
                    Key key = (Key) objectInputStream2.readObject();
                    objectInputStream2.close();
                    Cipher cipher = Cipher.getInstance("RSA");
                    cipher.init(1, key);
                    return cipher.doFinal(str.getBytes());
                } catch (Exception e) {
                    objectInputStream = objectInputStream2;
                    throw e;
                } catch (Throwable th) {
                    th = th;
                    objectInputStream = objectInputStream2;
                    objectInputStream.close();
                    throw th;
                }
            } catch (Exception e2) {
                throw e2;
            }
        } catch (Throwable th2) {
            th = th2;
        }
    }

    public static void generateKeyPair() throws Throwable {
        ObjectOutputStream objectOutputStream;
        ObjectOutputStream objectOutputStream2;
        SecureRandom secureRandom = new SecureRandom();
        KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("RSA");
        keyPairGenerator.initialize(1024, secureRandom);
        keyPairGenerator.initialize(1024);
        KeyPair keyPairGenerateKeyPair = keyPairGenerator.generateKeyPair();
        PublicKey publicKey = keyPairGenerateKeyPair.getPublic();
        PrivateKey privateKey = keyPairGenerateKeyPair.getPrivate();
        ObjectOutputStream objectOutputStream3 = null;
        try {
            objectOutputStream = new ObjectOutputStream(new FileOutputStream(a));
        } catch (Exception e) {
            e = e;
            objectOutputStream2 = null;
        } catch (Throwable th) {
            th = th;
            objectOutputStream = null;
        }
        try {
            objectOutputStream2 = new ObjectOutputStream(new FileOutputStream(b));
        } catch (Exception e2) {
            e = e2;
            objectOutputStream2 = null;
        } catch (Throwable th2) {
            th = th2;
            objectOutputStream.close();
            objectOutputStream3.close();
            throw th;
        }
        try {
            objectOutputStream.writeObject(publicKey);
            objectOutputStream2.writeObject(privateKey);
            objectOutputStream.close();
            objectOutputStream2.close();
        } catch (Exception e3) {
            e = e3;
            objectOutputStream3 = objectOutputStream;
            try {
                throw e;
            } catch (Throwable th3) {
                th = th3;
                objectOutputStream = objectOutputStream3;
                objectOutputStream3 = objectOutputStream2;
                objectOutputStream.close();
                objectOutputStream3.close();
                throw th;
            }
        } catch (Throwable th4) {
            th = th4;
            objectOutputStream3 = objectOutputStream2;
            objectOutputStream.close();
            objectOutputStream3.close();
            throw th;
        }
    }
}