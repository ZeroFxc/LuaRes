/*
** regcheck_dbg.c - debug helper: scan every proto/instruction for register
** operands that exceed maxstacksize (which makes the VM write past its
** CallFrame stack). Returns a diagnostic string (empty = OK).
*/
#include <stdio.h>
#include "obf_util.h"

static void regcheck_proto(luac_Proto *p, char *buf, int bufsz) {
    if (bufsz <= 0 || buf[0] || !p->code) return;
    int ms = (int)p->maxstacksize;
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int A = (ins >> 6) & 0xFF;
        int C = (ins >> 14) & 0x1FF;
        int B = (ins >> 23) & 0x1FF;
        int bad = -1; const char *fld = "";
        #define CHK_A do { if (A >= ms) { bad = A; fld = "A"; } } while(0)
        #define CHK_B do { if (B < 256 && B >= ms) { bad = B; fld = "B"; } } while(0)
        #define CHK_C do { if (C < 256 && C >= ms) { bad = C; fld = "C"; } } while(0)
        switch (op) {
            case 0: CHK_A; CHK_B; break;
            case 1: case 2: CHK_A; break;   /* LOADK / LOADKX */
            case 3: CHK_A; break;
            case 4: CHK_A; if (bad<0 && (A+B) >= ms) { bad = A+B; fld = "A+B(loadnil count)"; } break;
            case 5: CHK_A; break;
            case 6: CHK_A; CHK_C; break;
            case 7: CHK_A; CHK_B; CHK_C; break;
            case 8: CHK_B; CHK_C; break;
            case 9: CHK_A; break;
            case 10: CHK_A; CHK_B; CHK_C; break;
            case 11: CHK_A; break;
            case 12: CHK_A; CHK_B; CHK_C;
                     if (bad < 0 && (A + 1) >= ms) { bad = A + 1; fld = "A+1(self)"; } break;
            case 13: case 14: case 15: case 16: case 17: case 18: case 19:
            case 20: case 21: case 22: case 23: case 24:
                     CHK_A; CHK_B; CHK_C; break;
            case 25: case 26: case 27: case 28: CHK_A; CHK_B; break;
            case 29: CHK_A; if (B >= ms) { bad = B; fld = "B"; }
                     if (bad < 0 && C >= ms) { bad = C; fld = "C"; } break;
            case 31: case 32: case 33: CHK_B; CHK_C; break;
            case 34: CHK_A; break;
            case 35: CHK_A; CHK_B; break;
            case 36: case 37: CHK_A; /* CALL/TAILCALL: args R(A)..R(A+B-1), results R(A)..R(A+C-2) */
                     if (bad<0 && B>=1 && B<256 && (A+B-1)>=ms) { bad=A+B-1; fld="A+B-1(call args)"; }
                     if (bad<0 && C>=2 && C<256 && (A+C-2)>=ms) { bad=A+C-2; fld="A+C-2(call res)"; } break;
            case 38: CHK_A; /* RETURN: R(A)..R(A+B-2) when B!=0 */
                     if (bad<0 && B>=1 && B<256 && (A+B-2)>=ms) { bad=A+B-2; fld="A+B-2(return)"; } break;
            case 39: case 40: CHK_A;
                     if (bad < 0 && (A + 3) >= ms) { bad = A + 3; fld = "A+3(for)"; } break;
            case 42: CHK_A; /* standalone TFORLOOP touches only R(A),R(A+1) */
                     if (bad < 0 && (A + 1) >= ms) { bad = A + 1; fld = "A+1(tforloop)"; } break;
            case 41: CHK_A; /* TFORCALL: func R(A+2), results R(A+3)..R(A+2+C) */
                     if (bad < 0 && (A + 2 + C) >= ms) { bad = A + 2 + C; fld = "A+2+C(tforcall)"; } break;
            case 43: CHK_A; /* SETLIST: writes R(A+1)..R(A+B) when B!=0 */
                     if (bad<0 && B>=1 && B<256 && (A+B)>=ms) { bad=A+B; fld="A+B(setlist)"; } break;
            case 44: CHK_A; break;
            case 45: CHK_A; /* VARARG: R(A)..R(A+B-2) when B!=0 */
                     if (bad<0 && B>=2 && B<256 && (A+B-2)>=ms) { bad=A+B-2; fld="A+B-2(vararg)"; } break;
            case 47: case 48: case 49: case 50: case 51: case 52: case 53:
                     CHK_A; CHK_B; CHK_C; break; /* luasafe extended */
            default: break;
        }
        #undef CHK_A
        #undef CHK_B
        #undef CHK_C
        if (bad >= 0) {
            snprintf(buf, bufsz, "REG_OOB pc=%d op=%d %s=%d maxstack=%d", i, op, fld, bad, ms);
            return;
        }
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) regcheck_proto(p->p[i], buf, bufsz);
}

int obf_regcheck_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    static char msg[512];
    msg[0] = 0;
    regcheck_proto(p, msg, sizeof(msg));
    lua_pushstring(L, msg);
    return 1;
}
