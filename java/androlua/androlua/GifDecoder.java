package com.androlua;

import android.graphics.Bitmap;
import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.InputStream;

/* JADX INFO: loaded from: C:\Users\ruilo\Downloads\classes.dex */
public class GifDecoder extends Thread {
    public static final int STATUS_FINISH = -1;
    public static final int STATUS_FORMAT_ERROR = 1;
    public static final int STATUS_OPEN_ERROR = 2;
    public static final int STATUS_PARSING = 0;
    private boolean A;
    private byte[] B;
    private int C;
    private int D;
    private int E;
    private boolean F;
    private int G;
    private int H;
    private short[] I;
    private byte[] J;
    private byte[] K;
    private byte[] L;
    private GifFrame M;
    private int N;
    private GifAction O;
    private byte[] P;

    /* JADX INFO: renamed from: a, reason: collision with root package name */
    private InputStream f692a;

    /* JADX INFO: renamed from: b, reason: collision with root package name */
    private int f693b;

    /* JADX INFO: renamed from: c, reason: collision with root package name */
    private boolean f694c;
    private int d;
    private int e;
    private int[] f;
    private int[] g;
    private int[] h;
    public int height;
    private int i;
    private int j;
    private int k;
    private int l;
    private boolean m;
    private boolean n;
    private int o;
    private int p;
    private int q;
    private int r;
    private int s;
    private int t;
    private int u;
    private int v;
    private int w;
    public int width;
    private Bitmap x;
    private Bitmap y;
    private GifFrame z;

    public interface GifAction {
        void parseOk(boolean z, int i);
    }

    public static class GifFrame {
        public int delay;
        public Bitmap image;
        public GifFrame nextFrame = null;

        public GifFrame(Bitmap bitmap, int i) {
            this.image = bitmap;
            this.delay = i;
        }
    }

    public GifDecoder(InputStream inputStream, GifAction gifAction) {
        this.e = 1;
        this.z = null;
        this.A = false;
        this.B = new byte[256];
        this.C = 0;
        this.D = 0;
        this.E = 0;
        this.F = false;
        this.G = 0;
        this.O = null;
        this.P = null;
        this.f692a = inputStream;
        this.O = gifAction;
    }

    public GifDecoder(String str, GifAction gifAction) {
        this.e = 1;
        this.z = null;
        this.A = false;
        this.B = new byte[256];
        this.C = 0;
        this.D = 0;
        this.E = 0;
        this.F = false;
        this.G = 0;
        this.O = null;
        this.P = null;
        this.f692a = new FileInputStream(str);
        this.O = gifAction;
    }

    public GifDecoder(byte[] bArr, GifAction gifAction) {
        this.e = 1;
        this.z = null;
        this.A = false;
        this.B = new byte[256];
        this.C = 0;
        this.D = 0;
        this.E = 0;
        this.F = false;
        this.G = 0;
        this.O = null;
        this.P = null;
        this.P = bArr;
        this.O = gifAction;
    }

    /* JADX WARN: Multi-variable type inference failed */
    /* JADX WARN: Type inference failed for: r2v20 */
    /* JADX WARN: Type inference failed for: r2v21 */
    /* JADX WARN: Type inference failed for: r2v22 */
    /* JADX WARN: Type inference failed for: r2v25, types: [short] */
    /* JADX WARN: Type inference failed for: r2v27 */
    private void a() {
        int i;
        int i2;
        int i3;
        int i4;
        int i5;
        int i6;
        short s;
        int i7 = this.r * this.s;
        byte[] bArr = this.L;
        if (bArr == null || bArr.length < i7) {
            this.L = new byte[i7];
        }
        if (this.I == null) {
            this.I = new short[4096];
        }
        if (this.J == null) {
            this.J = new byte[4096];
        }
        if (this.K == null) {
            this.K = new byte[4097];
        }
        int iD = d();
        int i8 = 1 << iD;
        int i9 = i8 + 1;
        int i10 = i8 + 2;
        int i11 = iD + 1;
        int i12 = (1 << i11) - 1;
        for (int i13 = 0; i13 < i8; i13++) {
            this.I[i13] = 0;
            this.J[i13] = (byte) i13;
        }
        int i14 = i11;
        int i15 = i10;
        int i16 = i12;
        int i17 = -1;
        int i18 = 0;
        int i19 = 0;
        int i20 = 0;
        int i21 = 0;
        int iE = 0;
        int i22 = 0;
        int i23 = 0;
        int i24 = 0;
        while (i18 < i7) {
            if (i19 != 0) {
                i = i11;
                i2 = i9;
                int i25 = i23;
                i3 = i8;
                i4 = i25;
            } else if (i20 < i14) {
                if (iE == 0) {
                    iE = e();
                    if (iE <= 0) {
                        break;
                    } else {
                        i22 = 0;
                    }
                }
                i21 += (this.B[i22] & 255) << i20;
                i20 += 8;
                i22++;
                iE--;
            } else {
                int i26 = i21 & i16;
                i21 >>= i14;
                i20 -= i14;
                if (i26 > i15 || i26 == i9) {
                    break;
                }
                if (i26 == i8) {
                    i14 = i11;
                    i15 = i10;
                    i16 = i12;
                    i17 = -1;
                } else if (i17 == -1) {
                    this.K[i19] = this.J[i26];
                    i17 = i26;
                    i23 = i17;
                    i19++;
                    i11 = i11;
                } else {
                    i = i11;
                    if (i26 == i15) {
                        i6 = i19 + 1;
                        i5 = i26;
                        this.K[i19] = (byte) i23;
                        s = i17;
                    } else {
                        i5 = i26;
                        i6 = i19;
                        s = i5;
                    }
                    while (s > i8) {
                        this.K[i6] = this.J[s];
                        s = this.I[s];
                        i6++;
                        i8 = i8;
                    }
                    i3 = i8;
                    byte[] bArr2 = this.J;
                    i4 = bArr2[s] & 255;
                    if (i15 >= 4096) {
                        break;
                    }
                    i19 = i6 + 1;
                    i2 = i9;
                    byte b2 = (byte) i4;
                    this.K[i6] = b2;
                    this.I[i15] = (short) i17;
                    bArr2[i15] = b2;
                    i15++;
                    if ((i15 & i16) == 0 && i15 < 4096) {
                        i14++;
                        i16 += i15;
                    }
                    i17 = i5;
                }
            }
            i19--;
            this.L[i24] = this.K[i19];
            i18++;
            i24++;
            i8 = i3;
            i9 = i2;
            i23 = i4;
            i11 = i;
        }
        for (int i27 = i24; i27 < i7; i27++) {
            this.L[i27] = 0;
        }
    }

    private int[] a(int i) {
        int i2;
        int i3 = i * 3;
        byte[] bArr = new byte[i3];
        try {
            i2 = this.f692a.read(bArr);
        } catch (Exception e) {
            e.printStackTrace();
            i2 = 0;
        }
        if (i2 < i3) {
            this.f693b = 1;
            return null;
        }
        int[] iArr = new int[256];
        int i4 = 0;
        for (int i5 = 0; i5 < i; i5++) {
            int i6 = i4 + 1;
            int i7 = i6 + 1;
            iArr[i5] = ((bArr[i4] & 255) << 16) | (-16777216) | ((bArr[i6] & 255) << 8) | (bArr[i7] & 255);
            i4 = i7 + 1;
        }
        return iArr;
    }

    private boolean b() {
        return this.f693b != 0;
    }

    private void c() {
        this.f693b = 0;
        this.N = 0;
        this.M = null;
        this.f = null;
        this.g = null;
    }

    private int d() {
        try {
            return this.f692a.read();
        } catch (Exception unused) {
            this.f693b = 1;
            return 0;
        }
    }

    private int e() {
        this.C = d();
        int i = 0;
        if (this.C > 0) {
            while (i < this.C) {
                try {
                    int i2 = this.f692a.read(this.B, i, this.C - i);
                    if (i2 == -1) {
                        break;
                    }
                    i += i2;
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            if (i < this.C) {
                this.f693b = 1;
            }
        }
        return i;
    }

    private int f() {
        this.f692a = new ByteArrayInputStream(this.P);
        this.P = null;
        return n();
    }

    private void g() {
        boolean z = false;
        while (!z && !b()) {
            int iD = d();
            if (iD != 0) {
                if (iD == 33) {
                    int iD2 = d();
                    if (iD2 != 249) {
                        if (iD2 == 255) {
                            e();
                            String str = BuildConfig.FLAVOR;
                            for (int i = 0; i < 11; i++) {
                                str = str + ((char) this.B[i]);
                            }
                            if (str.equals("NETSCAPE2.0")) {
                                l();
                            }
                        }
                        q();
                    } else {
                        h();
                    }
                } else if (iD == 44) {
                    j();
                } else if (iD != 59) {
                    this.f693b = 1;
                } else {
                    z = true;
                }
            }
        }
    }

    private void h() {
        d();
        int iD = d();
        this.D = (iD & 28) >> 2;
        if (this.D == 0) {
            this.D = 1;
        }
        this.F = (iD & 1) != 0;
        this.G = m() * 10;
        this.H = d();
        d();
    }

    private void i() {
        String str = BuildConfig.FLAVOR;
        for (int i = 0; i < 6; i++) {
            str = str + ((char) d());
        }
        if (!str.startsWith("GIF")) {
            this.f693b = 1;
            return;
        }
        k();
        if (!this.f694c || b()) {
            return;
        }
        this.f = a(this.d);
        this.j = this.f[this.i];
    }

    private void j() {
        this.p = m();
        this.q = m();
        this.r = m();
        this.s = m();
        int iD = d();
        int i = 0;
        this.m = (iD & 128) != 0;
        this.n = (iD & 64) != 0;
        this.o = 2 << (iD & 7);
        if (this.m) {
            this.g = a(this.o);
            this.h = this.g;
        } else {
            this.h = this.f;
            if (this.i == this.H) {
                this.j = 0;
            }
        }
        if (this.F) {
            int[] iArr = this.h;
            int i2 = this.H;
            int i3 = iArr[i2];
            iArr[i2] = 0;
            i = i3;
        }
        if (this.h == null) {
            this.f693b = 1;
        }
        if (b()) {
            return;
        }
        a();
        q();
        if (b()) {
            return;
        }
        this.N++;
        this.x = Bitmap.createBitmap(this.width, this.height, Bitmap.Config.ARGB_4444);
        p();
        GifFrame gifFrame = this.M;
        if (gifFrame == null) {
            this.M = new GifFrame(this.x, this.G);
            this.z = this.M;
        } else {
            while (true) {
                GifFrame gifFrame2 = gifFrame.nextFrame;
                if (gifFrame2 == null) {
                    break;
                } else {
                    gifFrame = gifFrame2;
                }
            }
            gifFrame.nextFrame = new GifFrame(this.x, this.G);
        }
        if (this.F) {
            this.h[this.H] = i;
        }
        o();
        this.O.parseOk(true, this.N);
    }

    private void k() {
        this.width = m();
        this.height = m();
        int iD = d();
        this.f694c = (iD & 128) != 0;
        this.d = 2 << (iD & 7);
        this.i = d();
        this.l = d();
    }

    private void l() {
        do {
            e();
            byte[] bArr = this.B;
            if (bArr[0] == 1) {
                this.e = ((bArr[2] & 255) << 8) | (bArr[1] & 255);
            }
            if (this.C <= 0) {
                return;
            }
        } while (!b());
    }

    private int m() {
        return d() | (d() << 8);
    }

    private int n() {
        c();
        if (this.f692a != null) {
            i();
            if (b()) {
                this.O.parseOk(false, -1);
                this.f692a.close();
            } else {
                g();
                if (this.N < 0) {
                    this.f693b = 1;
                    this.O.parseOk(false, -1);
                    try {
                        this.f692a.close();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    this.f693b = -1;
                    this.O.parseOk(true, -1);
                    this.f692a.close();
                }
            }
        } else {
            this.f693b = 2;
            this.O.parseOk(false, -1);
        }
        return this.f693b;
    }

    private void o() {
        this.E = this.D;
        this.t = this.p;
        this.u = this.q;
        this.v = this.r;
        this.w = this.s;
        this.y = this.x;
        this.k = this.j;
        this.D = 0;
        this.F = false;
        this.G = 0;
        this.g = null;
    }

    private void p() {
        int i;
        int[] iArr = new int[this.width * this.height];
        int i2 = this.E;
        int i3 = 0;
        if (i2 > 0) {
            if (i2 == 3) {
                int i4 = this.N - 2;
                this.y = i4 > 0 ? getFrameImage(i4 - 1) : null;
            }
            Bitmap bitmap = this.y;
            if (bitmap != null) {
                int i5 = this.width;
                bitmap.getPixels(iArr, 0, i5, 0, 0, i5, this.height);
                if (this.E == 2) {
                    int i6 = !this.F ? this.k : 0;
                    for (int i7 = 0; i7 < this.w; i7++) {
                        int i8 = ((this.u + i7) * this.width) + this.t;
                        int i9 = this.v + i8;
                        while (i8 < i9) {
                            iArr[i8] = i6;
                            i8++;
                        }
                    }
                }
            }
        }
        int i10 = 0;
        int i11 = 1;
        int i12 = 8;
        while (true) {
            int i13 = this.s;
            if (i3 >= i13) {
                this.x = Bitmap.createBitmap(iArr, this.width, this.height, Bitmap.Config.ARGB_4444);
                return;
            }
            if (this.n) {
                if (i10 >= i13) {
                    i11++;
                    if (i11 == 2) {
                        i10 = 4;
                    } else if (i11 == 3) {
                        i10 = 2;
                        i12 = 4;
                    } else if (i11 == 4) {
                        i10 = 1;
                        i12 = 2;
                    }
                }
                i = i10 + i12;
            } else {
                i = i10;
                i10 = i3;
            }
            int i14 = i10 + this.q;
            if (i14 < this.height) {
                int i15 = this.width;
                int i16 = i14 * i15;
                int i17 = this.p + i16;
                int i18 = this.r + i17;
                if (i16 + i15 < i18) {
                    i18 = i16 + i15;
                }
                int i19 = this.r * i3;
                while (i17 < i18) {
                    int i20 = i19 + 1;
                    int i21 = this.h[this.L[i19] & 255];
                    if (i21 != 0) {
                        iArr[i17] = i21;
                    }
                    i17++;
                    i19 = i20;
                }
            }
            i3++;
            i10 = i;
        }
    }

    private void q() {
        do {
            e();
            if (this.C <= 0) {
                return;
            }
        } while (!b());
    }

    public void free() {
        while (true) {
            GifFrame gifFrame = this.M;
            if (gifFrame == null) {
                break;
            }
            gifFrame.image = null;
            this.M = this.M.nextFrame;
        }
        InputStream inputStream = this.f692a;
        if (inputStream != null) {
            try {
                inputStream.close();
            } catch (Exception unused) {
            }
            this.f692a = null;
        }
        this.P = null;
    }

    public GifFrame getCurrentFrame() {
        return this.z;
    }

    public int getDelay(int i) {
        GifFrame frame;
        this.G = -1;
        if (i >= 0 && i < this.N && (frame = getFrame(i)) != null) {
            this.G = frame.delay;
        }
        return this.G;
    }

    public int[] getDelays() {
        GifFrame gifFrame = this.M;
        int[] iArr = new int[this.N];
        for (int i = 0; gifFrame != null && i < this.N; i++) {
            iArr[i] = gifFrame.delay;
            gifFrame = gifFrame.nextFrame;
        }
        return iArr;
    }

    public GifFrame getFrame(int i) {
        GifFrame gifFrame = this.M;
        int i2 = 0;
        while (gifFrame != null) {
            if (i2 == i) {
                return gifFrame;
            }
            gifFrame = gifFrame.nextFrame;
            i2++;
        }
        return null;
    }

    public int getFrameCount() {
        return this.N;
    }

    public Bitmap getFrameImage(int i) {
        GifFrame frame = getFrame(i);
        if (frame == null) {
            return null;
        }
        return frame.image;
    }

    public Bitmap getImage() {
        return getFrameImage(0);
    }

    public int getLoopCount() {
        return this.e;
    }

    public int getStatus() {
        return this.f693b;
    }

    public GifFrame next() {
        GifFrame gifFrame;
        if (!this.A) {
            this.A = true;
            return this.M;
        }
        if (this.f693b == 0) {
            gifFrame = this.z.nextFrame;
            if (gifFrame != null) {
                this.z = gifFrame;
            }
        } else {
            this.z = this.z.nextFrame;
            if (this.z == null) {
                gifFrame = this.M;
                this.z = gifFrame;
            }
        }
        return this.z;
    }

    public boolean parseOk() {
        return this.f693b == -1;
    }

    public void reset() {
        this.z = this.M;
    }

    @Override // java.lang.Thread, java.lang.Runnable
    public void run() {
        if (this.f692a != null) {
            n();
        } else if (this.P != null) {
            f();
        }
    }
}