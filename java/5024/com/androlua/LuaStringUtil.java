package com.androlua;

import java.util.Arrays;
import java.util.Map;

/* loaded from: C:\Users\ruilo\Downloads\5024.dex */
public class LuaStringUtil {
    private static final char[] a = "^$*+?.([%-".toCharArray();
    private static final int[] c = {8211, 8212, 8224, 8225, 8252, 8265, 8315, 8364, 8377, 8381, 8471, 8482, 8505, 8592, 8593, 8594, 8595, 8596, 8597, 8598, 8599, 8600, 8601, 8617, 8618, 8645, 8646, 8710, 8711, 8712, 8730, 8734, 8745, 8746, 8801, 8834, 8986, 8987, 9000, 9167, 9193, 9194, 9195, 9196, 9197, 9198, 9199, 9200, 9201, 9202, 9203, 9208, 9209, 9210, 9410, 9642, 9643, 9650, 9654, 9660, 9664, 9674, 9675, 9679, 9711, 9723, 9724, 9725, 9726, 9728, 9729, 9730, 9731, 9732, 9742, 9745, 9748, 9749, 9752, 9757, 9760, 9762, 9763, 9766, 9770, 9774, 9775, 9784, 9785, 9786, 9792, 9794, 9800, 9801, 9802, 9803, 9804, 9805, 9806, 9807, 9808, 9809, 9810, 9811, 9823, 9824, 9827, 9829, 9830, 9832, 9851, 9854, 9855, 9874, 9875, 9876, 9877, 9878, 9879, 9881, 9883, 9884, 9888, 9889, 9895, 9898, 9899, 9904, 9905, 9917, 9918, 9924, 9925, 9928, 9934, 9935, 9937, 9939, 9940, 9961, 9962, 9968, 9969, 9970, 9971, 9972, 9973, 9975, 9976, 9977, 9978, 9981, 9986, 9989, 9992, 9993, 9994, 9995, 9996, 9997, 9999, 10002, 10004, 10006, 10013, 10017, 10024, 10035, 10036, 10052, 10055, 10060, 10062, 10067, 10068, 10069, 10071, 10083, 10084, 10133, 10134, 10135, 10145, 10160, 10175, 10548, 10549, 11013, 11014, 11015, 11035, 11036, 11088, 11093, 12336, 12349, 12951, 12953, 126980, 127183, 127344, 127345, 127358, 127359, 127374, 127377, 127378, 127379, 127380, 127381, 127382, 127383, 127384, 127385, 127386, 127489, 127490, 127514, 127535, 127538, 127539, 127540, 127541, 127542, 127543, 127544, 127545, 127546, 127568, 127569, 127744, 127745, 127746, 127747, 127748, 127749, 127750, 127751, 127752, 127753, 127754, 127755, 127756, 127757, 127758, 127759, 127760, 127761, 127762, 127763, 127764, 127765, 127766, 127767, 127768, 127769, 127770, 127771, 127772, 127773, 127774, 127775, 127776, 127777, 127780, 127781, 127782, 127783, 127784, 127785, 127786, 127787, 127788, 127789, 127790, 127791, 127792, 127793, 127794, 127795, 127796, 127797, 127798, 127799, 127800, 127801, 127802, 127803, 127804, 127805, 127806, 127807, 127808, 127809, 127810, 127811, 127812, 127813, 127814, 127815, 127816, 127817, 127818, 127819, 127820, 127821, 127822, 127823, 127824, 127825, 127826, 127827, 127828, 127829, 127830, 127831, 127832, 127833, 127834, 127835, 127836, 127837, 127838, 127839, 127840, 127841, 127842, 127843, 127844, 127845, 127846, 127847, 127848, 127849, 127850, 127851, 127852, 127853, 127854, 127855, 127856, 127857, 127858, 127859, 127860, 127861, 127862, 127863, 127864, 127865, 127866, 127867, 127868, 127869, 127870, 127871, 127872, 127873, 127874, 127875, 127876, 127877, 127878, 127879, 127880, 127881, 127882, 127883, 127884, 127885, 127886, 127887, 127888, 127889, 127890, 127891, 127894, 127895, 127897, 127898, 127899, 127902, 127903, 127904, 127905, 127906, 127907, 127908, 127909, 127910, 127911, 127912, 127913, 127914, 127915, 127916, 127917, 127918, 127919, 127920, 127921, 127922, 127923, 127924, 127925, 127926, 127927, 127928, 127929, 127930, 127931, 127932, 127933, 127934, 127935, 127936, 127937, 127938, 127939, 127940, 127941, 127942, 127943, 127944, 127945, 127946, 127947, 127948, 127949, 127950, 127951, 127952, 127953, 127954, 127955, 127956, 127957, 127958, 127959, 127960, 127961, 127962, 127963, 127964, 127965, 127966, 127967, 127968, 127969, 127970, 127971, 127972, 127973, 127974, 127975, 127976, 127977, 127978, 127979, 127980, 127981, 127982, 127983, 127984, 127987, 127988, 127989, 127991, 127992, 127993, 127994, 127995, 127996, 127997, 127998, 127999, 128000, 128001, 128002, 128003, 128004, 128005, 128006, 128007, 128008, 128009, 128010, 128011, 128012, 128013, 128014, 128015, 128016, 128017, 128018, 128019, 128020, 128021, 128022, 128023, 128024, 128025, 128026, 128027, 128028, 128029, 128030, 128031, 128032, 128033, 128034, 128035, 128036, 128037, 128038, 128039, 128040, 128041, 128042, 128043, 128044, 128045, 128046, 128047, 128048, 128049, 128050, 128051, 128052, 128053, 128054, 128055, 128056, 128057, 128058, 128059, 128060, 128061, 128062, 128063, 128064, 128065, 128066, 128067, 128068, 128069, 128070, 128071, 128072, 128073, 128074, 128075, 128076, 128077, 128078, 128079, 128080, 128081, 128082, 128083, 128084, 128085, 128086, 128087, 128088, 128089, 128090, 128091, 128092, 128093, 128094, 128095, 128096, 128097, 128098, 128099, 128100, 128101, 128102, 128103, 128104, 128105, 128106, 128107, 128108, 128109, 128110, 128111, 128112, 128113, 128114, 128115, 128116, 128117, 128118, 128119, 128120, 128121, 128122, 128123, 128124, 128125, 128126, 128127, 128128, 128129, 128130, 128131, 128132, 128133, 128134, 128135, 128136, 128137, 128138, 128139, 128140, 128141, 128142, 128143, 128144, 128145, 128146, 128147, 128148, 128149, 128150, 128151, 128152, 128153, 128154, 128155, 128156, 128157, 128158, 128159, 128160, 128161, 128162, 128163, 128164, 128165, 128166, 128167, 128168, 128169, 128170, 128171, 128172, 128173, 128174, 128175, 128176, 128177, 128178, 128179, 128180, 128181, 128182, 128183, 128184, 128185, 128186, 128187, 128188, 128189, 128190, 128191, 128192, 128193, 128194, 128195, 128196, 128197, 128198, 128199, 128200, 128201, 128202, 128203, 128204, 128205, 128206, 128207, 128208, 128209, 128210, 128211, 128212, 128213, 128214, 128215, 128216, 128217, 128218, 128219, 128220, 128221, 128222, 128223, 128224, 128225, 128226, 128227, 128228, 128229, 128230, 128231, 128232, 128233, 128234, 128235, 128236, 128237, 128238, 128239, 128240, 128241, 128242, 128243, 128244, 128245, 128246, 128247, 128248, 128249, 128250, 128251, 128252, 128253, 128255, 128256, 128257, 128258, 128259, 128260, 128261, 128262, 128263, 128264, 128265, 128266, 128267, 128268, 128269, 128270, 128271, 128272, 128273, 128274, 128275, 128276, 128277, 128278, 128279, 128280, 128281, 128282, 128283, 128284, 128285, 128286, 128287, 128288, 128289, 128290, 128291, 128292, 128293, 128294, 128295, 128296, 128297, 128298, 128299, 128300, 128301, 128302, 128303, 128304, 128305, 128306, 128307, 128308, 128309, 128310, 128311, 128312, 128313, 128314, 128315, 128316, 128317, 128329, 128330, 128331, 128332, 128333, 128334, 128336, 128337, 128338, 128339, 128340, 128341, 128342, 128343, 128344, 128345, 128346, 128347, 128348, 128349, 128350, 128351, 128352, 128353, 128354, 128355, 128356, 128357, 128358, 128359, 128367, 128368, 128371, 128372, 128373, 128374, 128375, 128376, 128377, 128378, 128391, 128394, 128395, 128396, 128397, 128400, 128405, 128406, 128420, 128421, 128424, 128433, 128434, 128444, 128450, 128451, 128452, 128465, 128466, 128467, 128476, 128477, 128478, 128481, 128483, 128488, 128495, 128499, 128506, 128507, 128508, 128509, 128510, 128511, 128512, 128513, 128514, 128515, 128516, 128517, 128518, 128519, 128520, 128521, 128522, 128523, 128524, 128525, 128526, 128527, 128528, 128529, 128530, 128531, 128532, 128533, 128534, 128535, 128536, 128537, 128538, 128539, 128540, 128541, 128542, 128543, 128544, 128545, 128546, 128547, 128548, 128549, 128550, 128551, 128552, 128553, 128554, 128555, 128556, 128557, 128558, 128559, 128560, 128561, 128562, 128563, 128564, 128565, 128566, 128567, 128568, 128569, 128570, 128571, 128572, 128573, 128574, 128575, 128576, 128577, 128578, 128579, 128580, 128581, 128582, 128583, 128584, 128585, 128586, 128587, 128588, 128589, 128590, 128591, 128640, 128641, 128642, 128643, 128644, 128645, 128646, 128647, 128648, 128649, 128650, 128651, 128652, 128653, 128654, 128655, 128656, 128657, 128658, 128659, 128660, 128661, 128662, 128663, 128664, 128665, 128666, 128667, 128668, 128669, 128670, 128671, 128672, 128673, 128674, 128675, 128676, 128677, 128678, 128679, 128680, 128681, 128682, 128683, 128684, 128685, 128686, 128687, 128688, 128689, 128690, 128691, 128692, 
    128693, 128694, 128695, 128696, 128697, 128698, 128699, 128700, 128701, 128702, 128703, 128704, 128705, 128706, 128707, 128708, 128709, 128715, 128716, 128717, 128718, 128719, 128720, 128721, 128722, 128725, 128726, 128727, 128736, 128737, 128738, 128739, 128740, 128741, 128745, 128747, 128748, 128752, 128755, 128756, 128757, 128758, 128759, 128760, 128761, 128762, 128763, 128764, 128992, 128993, 128994, 128995, 128996, 128997, 128998, 128999, 129000, 129001, 129002, 129003, 129292, 129293, 129294, 129295, 129296, 129297, 129298, 129299, 129300, 129301, 129302, 129303, 129304, 129305, 129306, 129307, 129308, 129309, 129310, 129311, 129312, 129313, 129314, 129315, 129316, 129317, 129318, 129319, 129320, 129321, 129322, 129323, 129324, 129325, 129326, 129327, 129328, 129329, 129330, 129331, 129332, 129333, 129334, 129335, 129336, 129337, 129338, 129340, 129341, 129342, 129343, 129344, 129345, 129346, 129347, 129348, 129349, 129351, 129352, 129353, 129354, 129355, 129356, 129357, 129358, 129359, 129360, 129361, 129362, 129363, 129364, 129365, 129366, 129367, 129368, 129369, 129370, 129371, 129372, 129373, 129374, 129375, 129376, 129377, 129378, 129379, 129380, 129381, 129382, 129383, 129384, 129385, 129386, 129387, 129388, 129389, 129390, 129391, 129392, 129393, 129394, 129395, 129396, 129397, 129398, 129399, 129400, 129402, 129403, 129404, 129405, 129406, 129407, 129408, 129409, 129410, 129411, 129412, 129413, 129414, 129415, 129416, 129417, 129418, 129419, 129420, 129421, 129422, 129423, 129424, 129425, 129426, 129427, 129428, 129429, 129430, 129431, 129432, 129433, 129434, 129435, 129436, 129437, 129438, 129439, 129440, 129441, 129442, 129443, 129444, 129445, 129446, 129447, 129448, 129449, 129450, 129451, 129452, 129453, 129454, 129455, 129456, 129457, 129458, 129459, 129460, 129461, 129462, 129463, 129464, 129465, 129466, 129467, 129468, 129469, 129470, 129471, 129472, 129473, 129474, 129475, 129476, 129477, 129478, 129479, 129480, 129481, 129482, 129483, 129485, 129486, 129487, 129488, 129489, 129490, 129491, 129492, 129493, 129494, 129495, 129496, 129497, 129498, 129499, 129500, 129501, 129502, 129503, 129504, 129505, 129506, 129507, 129508, 129509, 129510, 129511, 129512, 129513, 129514, 129515, 129516, 129517, 129518, 129519, 129520, 129521, 129522, 129523, 129524, 129525, 129526, 129527, 129528, 129529, 129530, 129531, 129532, 129533, 129534, 129535, 129648, 129649, 129650, 129651, 129652, 129656, 129657, 129658, 129664, 129665, 129666, 129667, 129668, 129669, 129670, 129680, 129681, 129682, 129683, 129684, 129685, 129686, 129687, 129688, 129689, 129690, 129691, 129692, 129693, 129694, 129695, 129696, 129697, 129699, 129700, 129701, 129702, 129703, 129704, 129712, 129713, 129714, 129715, 129716, 129717, 129718, 129728, 129729, 129730, 129744, 129745, 129746, 129747, 129748, 129749, 129750};
    private static final byte[] b = new byte[256];

    private static final class Buffer {
        private static final char[] a = new char[0];
        private char[] b;
        private int c;
        private int d;
        private String e;

        public Buffer() {
            this(64);
        }

        public Buffer(int i) {
            this.b = new char[i];
            this.c = 0;
            this.d = 0;
            this.e = null;
        }

        public Buffer(String str) {
            this.b = a;
            this.d = 0;
            this.c = 0;
            this.e = str;
        }

        private final void a(int i, int i2) {
            char[] cArr = this.b;
            if (i != cArr.length) {
                char[] cArr2 = new char[i];
                System.arraycopy(cArr, this.d, cArr2, i2, this.c);
                this.b = cArr2;
                this.d = i2;
            }
        }

        public static int encodeToUtf8(char[] cArr, int i, char[] cArr2, int i2) {
            int i3 = 0;
            int i4 = i2;
            while (i3 < i) {
                cArr2[i4] = cArr[i3];
                i3++;
                i4++;
            }
            return i4 - i2;
        }

        public final Buffer append(byte b) {
            makeroom(0, 1);
            char[] cArr = this.b;
            int i = this.d;
            int i2 = this.c;
            this.c = i2 + 1;
            cArr[i + i2] = (char) b;
            return this;
        }

        public final Buffer append(char c) {
            makeroom(0, 1);
            char[] cArr = this.b;
            int i = this.d;
            int i2 = this.c;
            cArr[i + i2] = c;
            this.c = i2 + 1;
            return this;
        }

        public final Buffer append(Object obj) {
            append(obj.toString());
            return this;
        }

        public final Buffer append(String str) {
            char[] charArray = str.toCharArray();
            int length = str.length();
            makeroom(0, length);
            encodeToUtf8(charArray, charArray.length, this.b, this.d + this.c);
            this.c += length;
            return this;
        }

        public Buffer concatTo(Number number) {
            String str = this.e;
            return str != null ? setvalue(str.concat(number.toString())) : prepend(number.toString());
        }

        public Buffer concatTo(Object obj) {
            return setvalue(this.e.concat(obj.toString()));
        }

        public Buffer concatTo(String str) {
            String str2 = this.e;
            return str2 != null ? setvalue(str.concat(str2)) : prepend(str);
        }

        public final void makeroom(int i, int i2) {
            String str = this.e;
            if (str != null) {
                this.e = null;
                this.c = str.length();
                this.d = i;
                this.b = new char[i + this.c + i2];
                System.arraycopy(str.toCharArray(), 0, this.b, this.d, this.c);
                return;
            }
            int i3 = this.d;
            if (this.c + i3 + i2 > this.b.length || i3 < i) {
                int i4 = this.c;
                int i5 = i + i4 + i2;
                if (i5 < 32) {
                    i5 = 32;
                } else if (i5 < i4 * 2) {
                    i5 = i4 * 2;
                }
                a(i5, i != 0 ? (i5 - this.c) - i2 : 0);
            }
        }

        public Buffer prepend(String str) {
            int length = str.length();
            makeroom(length, 0);
            System.arraycopy(str.toCharArray(), 0, this.b, this.d - length, length);
            this.d -= length;
            this.c += length;
            this.e = null;
            return this;
        }

        public Buffer setvalue(String str) {
            this.b = a;
            this.c = 0;
            this.d = 0;
            this.e = str;
            return this;
        }

        public String toString() {
            return tojstring();
        }

        public String tojstring() {
            return value();
        }

        public final String tostring() {
            a(this.c, 0);
            return new String(this.b, this.d, this.c);
        }

        public String value() {
            String str = this.e;
            return str != null ? str : tostring();
        }
    }

    public static class GMatchAux {
        private final int a;
        private final MatchState b;
        private final boolean c;
        private int d = 0;
        private int e = -1;

        public GMatchAux(String str, String str2, boolean z) {
            this.a = str.length();
            this.b = new MatchState(str, str2);
            this.c = z;
        }

        public MatchResult invoke() {
            while (this.d <= this.a) {
                this.b.a();
                int iB = this.b.b(this.d, 0);
                if (iB >= 0 && iB != this.e) {
                    int i = this.d;
                    this.d = iB;
                    this.e = iB;
                    return this.c ? new MatchResult(i + 1, iB, this.b.a(false, i, iB)) : new MatchResult(this.b.a(true, i, iB));
                }
                this.d++;
            }
            return null;
        }
    }

    public interface MatchFunc {
        String invoke(String[] strArr);
    }

    public static class MatchResult {
        private int a;
        private String b;
        private String[] c;
        private int d;
        private int e;

        public MatchResult(int i, int i2) {
            this.a = 0;
            this.d = -1;
            this.e = -1;
            this.d = i;
            this.e = i2;
        }

        public MatchResult(int i, int i2, String[] strArr) {
            this.a = 0;
            this.d = -1;
            this.e = -1;
            this.d = i;
            this.e = i2;
            this.c = strArr;
        }

        public MatchResult(String str, int i) {
            this.a = 0;
            this.d = -1;
            this.e = -1;
            this.b = str;
            this.a = i;
        }

        public MatchResult(String[] strArr) {
            this.a = 0;
            this.d = -1;
            this.e = -1;
            this.c = strArr;
            String[] strArr2 = this.c;
            this.a = strArr2.length;
            if (this.a > 0) {
                this.b = strArr2[0];
            }
        }

        public int end() {
            return this.e;
        }

        public String[] matchs() {
            return this.c;
        }

        public int n() {
            return this.a;
        }

        public String result() {
            return this.b;
        }

        public int start() {
            return this.d;
        }

        public String toString() {
            return "MatchResult{n=" + this.a + ", s='" + this.b + "', matchs=" + Arrays.toString(this.c) + ", start=" + this.d + ", end=" + this.e + '}';
        }
    }

    public static class MatchState {
        char[] a;
        final String c;
        final String d;
        int e = 0;
        int[] f = new int[32];
        int[] g = new int[32];
        int b = 200;

        MatchState(String str, String str2) {
            this.c = str;
            this.a = str.toCharArray();
            this.d = str2;
        }

        private void a(Buffer buffer, String str, int i, int i2) {
            String str2;
            int length = str.length();
            int i3 = 0;
            while (i3 < length) {
                char cCharAt = str.charAt(i3);
                if (cCharAt == '%') {
                    i3++;
                    cCharAt = i3 < length ? str.charAt(i3) : (char) 0;
                    if (Character.isDigit(cCharAt)) {
                        buffer.append(cCharAt == '0' ? this.c.substring(i, i2) : f(cCharAt - '1', i, i2).toString());
                    } else {
                        if (cCharAt != '%') {
                            StringBuilder sb = new StringBuilder();
                            sb.append("invalid use of '%' in replacement string: after '%' must be '0'-'9' or '%', but found ");
                            if (i3 < length) {
                                str2 = "symbol '" + cCharAt + "' with code " + cCharAt + " at pos " + (i3 + 1);
                            } else {
                                str2 = "end of string";
                            }
                            sb.append(str2);
                            a(sb.toString());
                        }
                        buffer.append(cCharAt);
                    }
                } else {
                    buffer.append(cCharAt);
                }
                i3++;
            }
        }

        private void a(String str) {
        }

        private boolean a(Object obj) {
            if (obj == null) {
                return false;
            }
            if (obj instanceof Boolean) {
                return ((Boolean) obj).booleanValue();
            }
            return true;
        }

        private int b() {
            for (int i = this.e - 1; i >= 0; i--) {
                if (this.g[i] == -1) {
                    return i;
                }
            }
            a("invalid pattern capture");
            return 0;
        }

        private int b(int i) {
            int i2 = i - 49;
            if (i2 < 0 || i2 >= this.e || this.g[i2] == -1) {
                a("invalid capture index %" + (i2 + 1));
            }
            return i2;
        }

        /* JADX WARN: Removed duplicated region for block: B:36:0x0053  */
        /* JADX WARN: Removed duplicated region for block: B:37:0x0056  */
        /*
            Code decompiled incorrectly, please refer to instructions dump.
            To view partially-correct code enable 'Show inconsistent code' option in preferences
        */
        static boolean d(int r5, int r6) {
            /*
                Method dump skipped, instructions count: 332
                To view this dump change 'Code comments level' option to 'DEBUG'
            */
            throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaStringUtil.MatchState.d(int, int):boolean");
        }

        public static boolean equals(char[] cArr, int i, char[] cArr2, int i2, int i3) {
            if (cArr.length < i + i3 || cArr2.length < i2 + i3) {
                return false;
            }
            while (true) {
                i3--;
                if (i3 < 0) {
                    return true;
                }
                int i4 = i + 1;
                int i5 = i2 + 1;
                if (cArr[i] != cArr2[i2]) {
                    return false;
                }
                i = i4;
                i2 = i5;
            }
        }

        private String f(int i, int i2, int i3) {
            if (i >= this.e) {
                if (i == 0) {
                    return this.c.substring(i2, i3);
                }
                return "invalid capture index %" + (i + 1);
            }
            int i4 = this.g[i];
            if (i4 == -1) {
                return "unfinished capture";
            }
            if (i4 == -2) {
                return String.valueOf(this.f[i] + 1);
            }
            int i5 = this.f[i];
            return this.c.substring(i5, i4 + i5);
        }

        int a(int i) {
            int i2 = i + 1;
            char cCharAt = this.d.charAt(i);
            if (cCharAt == '%') {
                if (i2 == this.d.length()) {
                    a("malformed pattern (ends with '%')");
                }
                return i2 + 1;
            }
            if (cCharAt != '[') {
                return i2;
            }
            if (i2 != this.d.length() && this.d.charAt(i2) == '^') {
                i2++;
            }
            while (true) {
                if (i2 == this.d.length()) {
                    a("malformed pattern (missing ']')");
                }
                int i3 = i2 + 1;
                if (this.d.charAt(i2) == '%' && i3 < this.d.length()) {
                    i3++;
                }
                i2 = i3;
                if (i2 != this.d.length() && this.d.charAt(i2) == ']') {
                    return i2 + 1;
                }
            }
        }

        int a(int i, int i2) {
            int iB = b();
            this.g[iB] = i - this.f[iB];
            int iB2 = b(i, i2);
            if (iB2 == -1) {
                this.g[iB] = -1;
            }
            return iB2;
        }

        void a() {
            this.e = 0;
            this.b = 200;
        }

        boolean a(int i, int i2, int i3) {
            boolean z;
            int i4;
            int i5 = i2 + 1;
            if (this.d.charAt(i5) == '^') {
                i2 = i5;
                z = false;
            } else {
                z = true;
            }
            while (true) {
                i2++;
                if (i2 >= i3) {
                    return !z;
                }
                if (this.d.charAt(i2) == '%') {
                    i2++;
                    if (d(i, this.d.charAt(i2))) {
                        return z;
                    }
                } else if (this.d.charAt(i2 + 1) != '-' || (i4 = i2 + 2) >= i3) {
                    if (this.d.charAt(i2) == i) {
                        return z;
                    }
                } else {
                    if (this.d.charAt(i4 - 2) <= i && i <= this.d.charAt(i4)) {
                        return z;
                    }
                    i2 = i4;
                }
            }
        }

        String[] a(boolean z, int i, int i2) {
            int i3 = (this.e == 0 && z) ? 1 : this.e;
            if (i3 == 0) {
                return null;
            }
            if (i3 == 1) {
                return new String[]{f(0, i, i2)};
            }
            String[] strArr = new String[i3];
            for (int i4 = 0; i4 < i3; i4++) {
                strArr[i4] = f(i4, i, i2);
            }
            return strArr;
        }

        public void add_value(Buffer buffer, int i, int i2, Object obj) {
            Object objInvoke;
            if (obj instanceof Map) {
                objInvoke = ((Map) obj).get(f(0, i, i2));
            } else {
                if (!(obj instanceof MatchFunc)) {
                    a(buffer, obj.toString(), i, i2);
                    return;
                }
                objInvoke = ((MatchFunc) obj).invoke(a(true, i, i2));
            }
            if (!a(objInvoke)) {
                objInvoke = this.c.substring(i, i2);
            } else if (!(objInvoke instanceof String)) {
                a("invalid replacement value (a " + objInvoke.getClass() + ")");
            }
            buffer.append(objInvoke.toString());
        }

        /* JADX WARN: Code restructure failed: missing block: B:37:0x008e, code lost:
        
            return r4;
         */
        /* JADX WARN: Code restructure failed: missing block: B:9:0x001b, code lost:
        
            return r7;
         */
        /* JADX WARN: Removed duplicated region for block: B:113:0x0168 A[SYNTHETIC] */
        /* JADX WARN: Removed duplicated region for block: B:73:0x011b  */
        /* JADX WARN: Removed duplicated region for block: B:76:0x0124 A[Catch: all -> 0x016e, TryCatch #0 {all -> 0x016e, blocks: (B:6:0x000e, B:10:0x001c, B:68:0x0101, B:70:0x010d, B:74:0x011c, B:76:0x0124, B:87:0x013e, B:90:0x0145, B:95:0x0159, B:97:0x0161, B:98:0x0168, B:18:0x0036, B:19:0x003c, B:21:0x0045, B:23:0x004d, B:24:0x0054, B:25:0x0059, B:27:0x0063, B:28:0x0068, B:32:0x0076, B:34:0x0083, B:39:0x0091, B:40:0x0096, B:42:0x00a0, B:45:0x00af, B:49:0x00bf, B:53:0x00ce, B:55:0x00d6, B:52:0x00c8, B:48:0x00b7, B:44:0x00aa, B:58:0x00dd, B:61:0x00e6, B:62:0x00ea, B:64:0x00f4), top: B:104:0x000e }] */
        /* JADX WARN: Removed duplicated region for block: B:79:0x012e  */
        /* JADX WARN: Unreachable blocks removed: 1, instructions: 1 */
        /*
            Code decompiled incorrectly, please refer to instructions dump.
            To view partially-correct code enable 'Show inconsistent code' option in preferences
        */
        int b(int r7, int r8) {
            /*
                Method dump skipped, instructions count: 374
                To view this dump change 'Code comments level' option to 'DEBUG'
            */
            throw new UnsupportedOperationException("Method not decompiled: com.androlua.LuaStringUtil.MatchState.b(int, int):int");
        }

        int b(int i, int i2, int i3) {
            int i4 = 0;
            while (true) {
                int i5 = i + i4;
                if (i5 >= this.c.length() || !d(this.c.charAt(i5), i2, i3)) {
                    break;
                }
                i4++;
            }
            while (i4 >= 0) {
                int iB = b(i + i4, i3 + 1);
                if (iB != -1) {
                    return iB;
                }
                i4--;
            }
            return -1;
        }

        int c(int i, int i2) {
            int iB = b(i2);
            int i3 = this.g[iB];
            if (this.c.length() - i < i3) {
                return -1;
            }
            char[] cArr = this.a;
            if (equals(cArr, this.f[iB], cArr, i, i3)) {
                return i + i3;
            }
            return -1;
        }

        int c(int i, int i2, int i3) {
            while (true) {
                int iB = b(i, i3 + 1);
                if (iB != -1) {
                    return iB;
                }
                if (i >= this.c.length() || !d(this.c.charAt(i), i2, i3)) {
                    break;
                }
                i++;
            }
            return -1;
        }

        boolean d(int i, int i2, int i3) {
            char cCharAt = this.d.charAt(i2);
            if (cCharAt == '%') {
                return d(i, this.d.charAt(i2 + 1));
            }
            if (cCharAt != '.') {
                return cCharAt != '[' ? this.d.charAt(i2) == i : a(i, i2, i3 - 1);
            }
            return true;
        }

        int e(int i, int i2) {
            char cCharAt;
            int length = this.d.length();
            if (i2 == length || i2 + 1 == length) {
                a("malformed pattern (missing arguments to '%b')");
            }
            int length2 = this.c.length();
            if (i >= length2 || this.c.charAt(i) != (cCharAt = this.d.charAt(i2))) {
                return -1;
            }
            char cCharAt2 = this.d.charAt(i2 + 1);
            int i3 = 1;
            while (true) {
                i++;
                if (i >= length2) {
                    return -1;
                }
                if (this.c.charAt(i) == cCharAt2) {
                    i3--;
                    if (i3 == 0) {
                        return i + 1;
                    }
                } else if (this.c.charAt(i) == cCharAt) {
                    i3++;
                }
            }
        }

        int e(int i, int i2, int i3) {
            int i4 = this.e;
            if (i4 >= 32) {
                a("too many captures");
            }
            this.f[i4] = i;
            this.g[i4] = i3;
            this.e = i4 + 1;
            int iB = b(i, i2);
            if (iB == -1) {
                this.e--;
            }
            return iB;
        }
    }

    static {
        for (int i = 0; i < 128; i++) {
            char c2 = (char) i;
            b[i] = (byte) (((c2 < ' ' || c2 == '\u007f') ? 64 : 0) | (Character.isDigit(c2) ? 8 : 0) | (Character.isLowerCase(c2) ? 2 : 0) | (Character.isUpperCase(c2) ? 4 : 0));
            if ((c2 >= 'a' && c2 <= 'f') || ((c2 >= 'A' && c2 <= 'F') || (c2 >= '0' && c2 <= '9'))) {
                byte[] bArr = b;
                bArr[i] = (byte) (bArr[i] | (-128));
            }
            if ((c2 >= '!' && c2 <= '/') || ((c2 >= ':' && c2 <= '@') || ((c2 >= '[' && c2 <= '`') || (c2 >= '{' && c2 <= '~')))) {
                byte[] bArr2 = b;
                bArr2[i] = (byte) (bArr2[i] | 16);
            }
            byte[] bArr3 = b;
            if ((bArr3[i] & 6) != 0) {
                bArr3[i] = (byte) (bArr3[i] | 1);
            }
        }
        byte[] bArr4 = b;
        bArr4[32] = 32;
        bArr4[13] = (byte) (bArr4[13] | 32);
        bArr4[10] = (byte) (bArr4[10] | 32);
        bArr4[9] = (byte) (bArr4[9] | 32);
        bArr4[11] = (byte) (bArr4[11] | 32);
        bArr4[12] = (byte) (bArr4[12] | 32);
    }

    private static int a(int i, int i2) {
        return i >= 0 ? i : i2 + i + 1;
    }

    private static int a(String str, char[] cArr) {
        for (char c2 : cArr) {
            if (str.indexOf(c2) > -1) {
                return 1;
            }
        }
        return -1;
    }

    private static MatchResult a(String str, String str2, int i, boolean z, boolean z2) {
        boolean z3;
        int i2;
        if (i > 0) {
            i = Math.min(i - 1, str.length());
        } else if (i < 0) {
            i = Math.max(0, str.length() + i);
        }
        if (z2 && (z || a(str2, a) == -1)) {
            int iIndexOf = str.indexOf(str2, i);
            if (iIndexOf != -1) {
                return new MatchResult(iIndexOf + 1, iIndexOf + str2.length());
            }
            return null;
        }
        MatchState matchState = new MatchState(str, str2);
        if (str2.length() <= 0 || str2.charAt(0) != '^') {
            z3 = false;
            i2 = 0;
        } else {
            z3 = true;
            i2 = 1;
        }
        while (true) {
            matchState.a();
            int iB = matchState.b(i, i2);
            if (iB != -1) {
                return z2 ? new MatchResult(i + 1, iB, matchState.a(false, i, iB)) : new MatchResult(matchState.a(true, i, iB));
            }
            int i3 = i + 1;
            if (i >= str.length() || z3) {
                return null;
            }
            i = i3;
        }
    }

    public static MatchResult find(String str, String str2) {
        return find(str, str2, 1, false);
    }

    public static MatchResult find(String str, String str2, int i) {
        return find(str, str2, i, false);
    }

    public static MatchResult find(String str, String str2, int i, boolean z) {
        return a(str, str2, i, z, true);
    }

    public static GMatchAux gfind(String str, String str2) {
        return new GMatchAux(str, str2, true);
    }

    public static GMatchAux gmatch(String str, String str2) {
        return new GMatchAux(str, str2, false);
    }

    public static MatchResult gsub(String str, String str2, Object obj) {
        try {
            return gsub(str, str2, obj, str.length() + 1);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public static MatchResult gsub(String str, String str2, Object obj, int i) {
        int length = str.length();
        int i2 = 0;
        int i3 = (str2.length() <= 0 || str2.charAt(0) != '^') ? 0 : 1;
        Buffer buffer = new Buffer(length);
        MatchState matchState = new MatchState(str, str2);
        int i4 = 0;
        int i5 = -1;
        while (i2 < i) {
            matchState.a();
            int iB = matchState.b(i4, i3);
            if (iB != -1 && iB != i5) {
                i2++;
                matchState.add_value(buffer, i4, iB, obj);
                i4 = iB;
                i5 = i4;
            } else {
                if (i4 >= length) {
                    break;
                }
                buffer.append(str.charAt(i4));
                i4++;
            }
            if (i3 != 0) {
                break;
            }
        }
        buffer.append(str.substring(i4, length));
        return new MatchResult(buffer.tostring(), i2);
    }

    public static MatchResult match(String str, String str2) {
        return match(str, str2, 1, false);
    }

    public static MatchResult match(String str, String str2, int i) {
        return match(str, str2, i, false);
    }

    public static MatchResult match(String str, String str2, int i, boolean z) {
        return a(str, str2, i, z, false);
    }

    public static String rep(String str, int i) {
        StringBuilder sb = new StringBuilder(str.length() * i);
        for (int i2 = 0; i2 < i; i2++) {
            sb.append(str);
        }
        return sb.toString();
    }

    public static String sub(String str, int i) {
        return sub(str, i, -1);
    }

    public static String sub(String str, int i, int i2) {
        int length = str.length();
        int iA = a(i, length);
        int iA2 = a(i2, length);
        if (iA < 1) {
            iA = 1;
        }
        if (iA2 > length) {
            iA2 = length;
        }
        return iA <= iA2 ? str.substring(iA - 1, iA2) : BuildConfig.FLAVOR;
    }
}