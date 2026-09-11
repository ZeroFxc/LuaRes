/*
** vm_asm_util.c - Buffer, RNG, template substitution
*/
#include "vm_asm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

/* ---- buffer ---- */
void vmbuf_init(VmBuf *b) { b->buf = NULL; b->len = 0; b->cap = 0; }

static void vmbuf_reserve(VmBuf *b, size_t extra) {
    if (b->len + extra + 1 > b->cap) {
        b->cap = (b->len + extra + 1) * 2;
        b->buf = realloc(b->buf, b->cap);
    }
}

void vmbuf_puts(VmBuf *b, const char *s) {
    size_t l = strlen(s);
    vmbuf_reserve(b, l);
    memcpy(b->buf + b->len, s, l);
    b->len += l;
    b->buf[b->len] = '\0';
}

void vmbuf_putc(VmBuf *b, char c) {
    vmbuf_reserve(b, 1);
    b->buf[b->len++] = c;
    b->buf[b->len] = '\0';
}

void vmbuf_printf(VmBuf *b, const char *fmt, ...) {
    char tmp[4096];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if ((size_t)n < sizeof(tmp)) {
        vmbuf_puts(b, tmp);
    } else {
        char *big = malloc(n + 1);
        va_start(ap, fmt);
        vsnprintf(big, n + 1, fmt, ap);
        va_end(ap);
        vmbuf_puts(b, big);
        free(big);
    }
}

char *vmbuf_detach(VmBuf *b, size_t *out_len) {
    if (out_len) *out_len = b->len;
    char *r = b->buf;
    b->buf = NULL; b->len = 0; b->cap = 0;
    if (!r) { r = (char *)malloc(1); r[0] = '\0'; } /* never return NULL: callers feed it to strlen/free */
    return r;
}

/* ---- RNG (xorshift32) ---- */
static unsigned int rng_state = 1;
void vm_srand(unsigned int seed) { rng_state = seed ? seed : 1; }
unsigned int vm_rand(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

/* ---- identifier generator ---- */
static const char *idchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
void vm_gen_id(char *buf, int len) {
    for (int i = 0; i < len; i++)
        buf[i] = idchars[vm_rand() % (strlen(idchars))];
    buf[len] = '\0';
}

/* ---- operand substitution in index expressions ---- */
static void subst_ops(char *dst, size_t dstsz, const char *src,
                      const char *vA, const char *vB, const char *vC,
                      const char *vBx, const char *vsBx) {
    size_t di = 0;
    const char *p = src;
    while (*p && di < dstsz - 1) {
        if (*p == '{') {
            const char *e = strchr(p, '}');
            if (e) {
                size_t tl = e - p - 1;
                char tag[32];
                if (tl >= sizeof(tag)) tl = sizeof(tag)-1;
                strncpy(tag, p+1, tl); tag[tl] = '\0';
                const char *rep = NULL;
                if (strcmp(tag,"A")==0) rep = vA;
                else if (strcmp(tag,"B")==0) rep = vB;
                else if (strcmp(tag,"C")==0) rep = vC;
                else if (strcmp(tag,"Bx")==0) rep = vBx;
                else if (strcmp(tag,"sBx")==0) rep = vsBx;
                if (rep) {
                    size_t rl = strlen(rep);
                    if (di + rl < dstsz) { memcpy(dst+di, rep, rl); di += rl; }
                    p = e + 1;
                    continue;
                }
            }
        }
        dst[di++] = *p++;
    }
    dst[di] = '\0';
}

/* ---- template body emission ---- */
void vm_emit_body(VmBuf *b, const char *body,
                  const char *R, const char *K, const char *UV, const char *PC,
                  const char *vCODE, const char *vTOP, const char *vPROTO,
                  const char *vA, const char *vB, const char *vC,
                  const char *vBx, const char *vsBx, int ret_mode) {
    const char *p = body;
    while (*p) {
        if (*p == '{') {
            int depth = 1;
            const char *q = p + 1;
            while (*q && depth > 0) {
                if (*q == '{') depth++;
                else if (*q == '}') depth--;
                q++;
            }
            size_t tlen = q - p - 2;
            char tag[128];
            if (tlen >= sizeof(tag)) tlen = sizeof(tag)-1;
            strncpy(tag, p+1, tlen); tag[tlen] = '\0';
            p = q;

            if (strcmp(tag,"A")==0) vmbuf_puts(b, vA);
            else if (strcmp(tag,"B")==0) vmbuf_puts(b, vB);
            else if (strcmp(tag,"C")==0) vmbuf_puts(b, vC);
            else if (strcmp(tag,"Bx")==0) vmbuf_puts(b, vBx);
            else if (strcmp(tag,"sBx")==0) vmbuf_puts(b, vsBx);
            else if (strncmp(tag,"REG:",4)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag+4, vA, vB, vC, vBx, vsBx);
                vmbuf_printf(b, "%s[%s]", R, idx);
            }
            else if (strncmp(tag,"RK:",3)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag+3, vA, vB, vC, vBx, vsBx);
                vmbuf_printf(b, "RK(%s, %s, %s)", idx, R, K);
            }
            else if (strncmp(tag,"K:",2)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag+2, vA, vB, vC, vBx, vsBx);
                if (strcmp(idx,"extra")==0) vmbuf_printf(b, "%s[extra]", K);
                else if (strcmp(idx,"next_ax")==0) vmbuf_printf(b, "%s[((code[%s+1][2] or 0)|((code[%s+1][5] or 0)<<8))+1]", K, PC, PC);
                else vmbuf_printf(b, "%s[%s+1]", K, idx);
            }
            else if (strcmp(tag,"PC")==0) vmbuf_puts(b, PC);
            else if (strncmp(tag,"JMP:",4)==0) {
                if (ret_mode) vmbuf_printf(b, "return %s+(%s), top", PC, vsBx);
                else vmbuf_printf(b, "%s=%s+(%s)", PC, PC, vsBx);
            }
            else if (strcmp(tag,"CODE")==0) {
                vmbuf_puts(b, vCODE);
            }
            else if (strcmp(tag,"R")==0) vmbuf_puts(b, R);
            else if (strcmp(tag,"K")==0) vmbuf_puts(b, K);
            else if (strcmp(tag,"UV")==0) vmbuf_puts(b, UV);
            else if (strcmp(tag,"TOP")==0) vmbuf_puts(b, vTOP);
            else if (strcmp(tag,"PROTO")==0) vmbuf_puts(b, vPROTO);
            else if (strcmp(tag,"NEXT")==0) {
                if (ret_mode) vmbuf_printf(b, "return %s+1, top", PC);
                else vmbuf_printf(b, "%s=%s+1", PC, PC);
            }
            else {
                vmbuf_putc(b, '{');
                vmbuf_puts(b, tag);
                vmbuf_putc(b, '}');
            }
        } else {
            vmbuf_putc(b, *p++);
        }
    }
}
