/*
** vm_embed.c - 自包含 VM 生成器（成品式）
** 调用 vm_assemble_runtime 生成精简执行器，把输入字节码解析为已解码的指令表嵌入，
** 输出一个可直接 dofile 运行的自包含 lua 文件，不依赖 string.dec / luac 等库。
**
** 库函数: vm_embed_generate(bc, bc_len, out_len) -> malloc'd lua source
** 可执行: vm_embed <input.luac> [output.lua]
*/
#include "vm_asm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <time.h>

/* Debug macro: compile with -DVM_EMBED_DEBUG=1 to enable */
#ifndef VM_EMBED_DEBUG
#define VM_EMBED_DEBUG 0
#endif

/* ---------- 字节码读取 ---------- */
typedef struct {
    const unsigned char *buf;
    size_t pos, len;
    int encrypted;
} Reader;

static uint8_t  rd_byte(Reader *r) { return r->buf[r->pos++]; }
static uint32_t rd_int(Reader *r) {
    uint32_t v; memcpy(&v, r->buf + r->pos, 4); r->pos += 4; return v;
}
static double rd_float(Reader *r) {
    double v; memcpy(&v, r->buf + r->pos, 8); r->pos += 8; return v;
}
static int64_t rd_integer(Reader *r) {
    int64_t v; memcpy(&v, r->buf + r->pos, 8); r->pos += 8; return v;
}

static int is_valid_text(const unsigned char *p, size_t len) {
    size_t i = 0;
    if (len == 0) return 1;
    while (i < len) {
        unsigned char c = p[i];
        int need;
        if (c == 0x00) return 0;
        if (c < 0x80) {
            if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) return 0;
            if (c == 0x7F) return 0;
            i++; continue;
        }
        if (c < 0xC0) return 0;
        if (c < 0xE0) need = 1;
        else if (c < 0xF0) need = 2;
        else if (c < 0xF8) need = 3;
        else return 0;
        if (i + need >= len) return 0;
        i++;
        while (need-- > 0) { if ((p[i] & 0xC0) != 0x80) return 0; i++; }
    }
    return 1;
}

static void decrypt_string(unsigned char *buff, size_t len) {
    size_t length = len;
    unsigned char first = (unsigned char)(buff[0] ^ (length % 255));
    size_t step = (size_t)first + len;
    buff[0] = first;
    for (size_t i = 1; i < len; i++) {
        length += step;
        buff[i] ^= (unsigned char)(length % 255);
    }
}

static char *rd_string(Reader *r, size_t *outlen) {
    size_t size = rd_byte(r);
    if (size == 0xFF) {
        /* dumper writes sizeof(size_t) bytes (little-endian), not 4 */
        size = 0;
        for (int i = 0; i < (int)sizeof(size_t); i++)
            size |= ((size_t)rd_byte(r)) << (i * 8);
    }
    if (size == 0) { *outlen = 0; return strdup(""); }
    size_t len = size - 1;
    unsigned char *raw = malloc(len ? len : 1);
    if (len) memcpy(raw, r->buf + r->pos, len);
    r->pos += len;
    if (r->encrypted && len > 0) {
        unsigned char *tmp = malloc(len);
        memcpy(tmp, raw, len);
        decrypt_string(tmp, len);
        int valid = (len == 1) || is_valid_text(tmp, len);
        if (len == 1 && (raw[0] >= 0x80)) {
#if VM_EMBED_DEBUG
            { FILE *df = fopen("_vm_dbg.txt", "a"); fprintf(df, "rd_string len=%zu raw[0]=%d dec[0]=%d valid=%d\n", len, raw[0], tmp[0], valid); fclose(df); }
#endif
        }
        if (valid) memcpy(raw, tmp, len);
        free(tmp);
    }
#if VM_EMBED_DEBUG
    if (len == 1 && raw[0] >= 0x80) {
        FILE *df = fopen("_vm_dbg.txt", "a");
        fprintf(df, "rd_string: len=%zu byte=%d encrypted=%d pos=%zu\n", len, raw[0], r->encrypted, r->pos);
        fclose(df);
    }
#endif
    *outlen = len;
    return (char*)raw;
}

/* ---------- lua table 序列化 ---------- */
typedef struct { char *data; size_t len, cap; } Buf;
static void buf_init(Buf *b) { b->data = NULL; b->len = 0; b->cap = 0; }
static void buf_put(Buf *b, const char *s, size_t n) {
    if (b->len + n + 1 > b->cap) {
        b->cap = (b->len + n + 1) * 2;
        b->data = realloc(b->data, b->cap);
    }
    memcpy(b->data + b->len, s, n);
    b->len += n; b->data[b->len] = 0;
}
static void buf_str(Buf *b, const char *s) { buf_put(b, s, strlen(s)); }
static void buf_char(Buf *b, char c) { buf_put(b, &c, 1); }

static void buf_escape_string(Buf *b, const char *s, size_t len) {
    buf_char(b, '"');
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        if (c == '"') buf_str(b, "\\\"");
        else if (c == '\\') buf_str(b, "\\\\");
        else if (c == '\n') buf_str(b, "\\n");
        else if (c == '\r') buf_str(b, "\\r");
        else if (c == '\t') buf_str(b, "\\t");
        else if (c < 0x20 || c >= 0x7F) {
            char tmp[8]; snprintf(tmp, sizeof(tmp), "\\%03d", c); buf_str(b, tmp);
        } else buf_char(b, (char)c);
    }
    buf_char(b, '"');
}

/* ---------- proto 递归解析 + 序列化（已解码常量） ---------- */
typedef struct {
    const int *op_remap;   /* dispatch opcode remap or NULL */
    int reg_on; unsigned int reg_seed;
    int const_on; unsigned int const_seed;
    int *idxp;             /* shared proto counter (deterministic per-proto seeds) */
    const int *parent_reg; /* parent proto reg map (for instack=1 upvalues) */
    int parent_maxstack;   /* parent proto maxstacksize (parent_reg length) */
    int packed_code;       /* store instructions as packed byte string */
} EmbedCtx;

static void serialize_proto(Reader *r, Buf *b, int depth, EmbedCtx *ctx);

static void serialize_proto(Reader *r, Buf *b, int depth, EmbedCtx *ctx) {
#if VM_SHUFFLE_DEBUG
    buf_str(b, "-- [DBG_ENTRY] serialize_proto called depth=\n");
#endif
    size_t slen;
    char *src = rd_string(r, &slen); free(src);
    rd_int(r); rd_int(r);
    uint8_t numparams = rd_byte(r);
    uint8_t is_vararg = rd_byte(r);
    uint8_t maxstacksize = rd_byte(r);

    uint32_t ncode = rd_int(r);
    unsigned int *ins_arr = ncode ? malloc(ncode * sizeof(unsigned int)) : NULL;
    for (uint32_t i = 0; i < ncode; i++) ins_arr[i] = rd_int(r);

    uint32_t nk = rd_int(r);

    /* read all constants into memory (needed before reg_map for upvalue anchoring) */
    typedef struct { int t; char *s; size_t sl; double f; int64_t iv; int bv; } KVal;
    KVal *kvs = nk ? malloc(nk * sizeof(KVal)) : NULL;
    for (uint32_t i = 0; i < nk; i++) {
        KVal *kv = &kvs[i];
        kv->t = rd_byte(r); kv->s = NULL; kv->sl = 0; kv->f = 0; kv->iv = 0; kv->bv = 0;
        switch (kv->t) {
            case 0: break;
            case 1: kv->bv = rd_byte(r); break;
            case 3: kv->f = rd_float(r); break;
            case 19: kv->iv = rd_integer(r); break;
            case 4: case 20: kv->s = rd_string(r, &kv->sl); break;
            default: break; /* poison/unknown: no payload */
        }
    }

    /* read upvalues early (needed for reg_map anchor scan) */
    uint32_t nuv = rd_int(r);
    uint8_t *uv_instack = nuv ? malloc(nuv) : NULL;
    uint8_t *uv_idx = nuv ? malloc(nuv) : NULL;
    for (uint32_t i = 0; i < nuv; i++) {
        uv_instack[i] = rd_byte(r);
        uv_idx[i] = rd_byte(r);
    }

    /* per-proto deterministic seeds derived from base seed + proto index */
    int pidx = (*ctx->idxp)++;
    unsigned int rseed = ctx->reg_seed ^ (unsigned int)(pidx * 2654435761u);
    unsigned int cseed = ctx->const_seed ^ (unsigned int)(pidx * 2246822519u);

    /* reg map: anchor scan (CALL/SETLIST/VARARG/RETURN/SELF/TFORCALL zones stay
       in place), non-anchored registers permute */
    int *reg_map = NULL;
    unsigned char *anchored = NULL;
    if (ctx->reg_on && maxstacksize > 0) {
        anchored = malloc(maxstacksize);
        vm_reg_anchor_scan(ins_arr, (int)ncode, anchored, maxstacksize, numparams);
        /* anchor all registers referenced by instack=1 upvalues (prevents remap from
           moving an upvalue-referenced register into/out of JMP close range) */
        for (uint32_t i = 0; i < nuv; i++) {
            if (uv_instack[i] && uv_idx[i] < maxstacksize) {
                anchored[uv_idx[i]] = 1;
            }
        }
        /* (R1锚定临时修复已移除，恢复调试) */
        reg_map = vm_make_regmap(rseed, anchored, maxstacksize);
    }
#if VM_SHUFFLE_DEBUG
    {
        char dbg[2048];
        int pos = 0;
        pos += snprintf(dbg+pos, sizeof(dbg)-pos, "-- [VM_RMAP] ms=%d np=%d nuv=%d reg_on=%d ncode=%d\n",
                maxstacksize, numparams, nuv, ctx->reg_on, ncode);
        if (anchored) {
            pos += snprintf(dbg+pos, sizeof(dbg)-pos, "--   anchored=");
            for (int i = 0; i < maxstacksize && i < 16; i++) {
                pos += snprintf(dbg+pos, sizeof(dbg)-pos, "%d", anchored[i]);
            }
            pos += snprintf(dbg+pos, sizeof(dbg)-pos, "\n");
        }
        if (reg_map) {
            pos += snprintf(dbg+pos, sizeof(dbg)-pos, "--   map=");
            for (int i = 0; i < maxstacksize && i < 16; i++) {
                pos += snprintf(dbg+pos, sizeof(dbg)-pos, "%d:%d,", i, reg_map[i]);
            }
            pos += snprintf(dbg+pos, sizeof(dbg)-pos, "\n");
        }
        /* 输出指令序列 */
        pos += snprintf(dbg+pos, sizeof(dbg)-pos, "--   code=");
        for (uint32_t i = 0; i < ncode && i < 20; i++) {
            unsigned int ins = ins_arr[i];
            unsigned int op = ins & 0x3F;
            unsigned int a = (ins >> 6) & 0xFF;
            unsigned int b = (ins >> 23) & 0x1FF;
            unsigned int c = (ins >> 14) & 0x1FF;
            pos += snprintf(dbg+pos, sizeof(dbg)-pos, "[%d]op%d a=%d b=%d c=%d ", i, op, a, b, c);
        }
        pos += snprintf(dbg+pos, sizeof(dbg)-pos, "\n");
        buf_str(b, dbg);
    }
#endif
    if (anchored) free(anchored);
    int *k_map = NULL;
    if (ctx->const_on && nk > 0) k_map = vm_make_kmap(cseed, (int)nk);

    buf_str(b, "{\n");
    for (int i = 0; i < depth; i++) buf_str(b, "  ");

    if (ctx->packed_code) {
        buf_str(b, "code_packed={");
        for (uint32_t _pi = 0; _pi < ncode; _pi++) {
            uint32_t _ins = ins_arr[_pi];
            uint32_t _rop = _ins & 0x3F;
            uint32_t _op = ctx->op_remap ? ctx->op_remap[_rop] : _rop;
            int _a = (_ins >> 6) & 0xFF;
            int _c = (_ins >> 14) & 0x1FF;
            int _bop = (_ins >> 23) & 0x1FF;
            int _bx = (int)(_ins >> 14);
            vm_shuffle_fields((int)_rop, &_a, &_bop, &_c, &_bx, reg_map, maxstacksize, k_map, (int)nk);
            if (_pi) buf_char(b, ',');
            char _tmp[64];
            snprintf(_tmp, sizeof(_tmp), "%u,%d,%d,%d,%d", _op, _a, _bop, _c, _bx);
            buf_str(b, _tmp);
        }
        buf_str(b, "},\n");
    } else {
    buf_str(b, "code={");
    int uv_setup_remaining = 0;  /* CLOSURE 后面还剩多少条 upvalue 设置指令 */
    for (uint32_t i = 0; i < ncode; i++) {
        uint32_t ins = ins_arr[i];
        uint32_t raw_op = ins & 0x3F;
        uint32_t op = raw_op;
        if (ctx->op_remap) op = (uint32_t)ctx->op_remap[raw_op];
        int a = (ins >> 6) & 0xFF;
        int c = (ins >> 14) & 0x1FF;
        int bop = (ins >> 23) & 0x1FF;
        int bx = (int)(ins >> 14);

        /* CLOSURE 后面的 upvalue 设置区识别（启发式）：
           CLOSURE(44) 后面跟 MOVE(0)/GETUPVAL(5)/GETTABUP(6) 设置 upvalue。
           这些 MOVE 的 A 字段是 upvalue 索引（不是寄存器），不能被 remap。
           启发式：CLOSURE 后面连续的 MOVE/GETUPVAL/GETTABUP 就是 upvalue 设置区，
           直到遇到其他指令。upvalue 数量不超过 255（8 位索引）。 */
        int uv_setup_move = 0;
        if (raw_op == 44) {  /* CLOSURE */
            uv_setup_remaining = 255;  /* 上限，实际由后续指令类型决定 */
        } else if (uv_setup_remaining > 0) {
            if (raw_op == 0 || raw_op == 5 || raw_op == 6) {
                uv_setup_remaining--;
                if (raw_op == 0) uv_setup_move = 1;  /* MOVE 的 A 是 upvalue 索引 */
            } else {
                uv_setup_remaining = 0;  /* upvalue 设置区结束 */
            }
        }
#if VM_SHUFFLE_DEBUG
        if (i >= 8 && i <= 16) {
            char dbg[256];
            snprintf(dbg, sizeof(dbg), "-- [UVDBG] i=%u op=%u a=%d uv_rem=%d uv_move=%d\n", i, raw_op, a, uv_setup_remaining, uv_setup_move);
            buf_str(b, dbg);
        }
#endif

        /* 字段语义按原始 opcode 判定（dispatch remap 只改输出编号，不改变字段含义） */
        vm_shuffle_fields((int)raw_op, &a, &bop, &c, &bx,
                          reg_map, maxstacksize, k_map, (int)nk);
        /* CLOSURE 后 MOVE 的 A 是 upvalue 索引，恢复原值（不 remap） */
        if (uv_setup_move) {
            a = (ins >> 6) & 0xFF;
        }
        int32_t sbx = bx - 131071;
        char tmp[128];
        snprintf(tmp, sizeof(tmp), "%s{%u,%d,%d,%d,%d,%d}",
                 i ? "," : "", op, a, bop, c, bx, sbx);
        buf_str(b, tmp);
    }
    buf_str(b, "},\n");
    }
    for (int i = 0; i < depth; i++) buf_str(b, "  ");

    /* emit constants in shuffled order (kvs already read) */
    buf_str(b, "k={");
    if (k_map) {
        /* 新表位置 k_map[old] = 原表 old（指令 new=k_map[old] 取新表[k_map[old]]=原表[old] 一致） */
        KVal **ordered = malloc(nk * sizeof(KVal*));
        for (uint32_t i = 0; i < nk; i++) ordered[k_map[i]] = &kvs[i];
        for (uint32_t i = 0; i < nk; i++) {
            KVal *kv = ordered[i];
            if (i) buf_char(b, ',');
            switch (kv->t) {
                case 0: buf_str(b, "nil"); break;
                case 1: buf_str(b, kv->bv ? "true" : "false"); break;
                case 3: {
                    double fv = kv->f;
                    if (isnan(fv)) { buf_str(b, "(0/0)"); break; }
                    if (isinf(fv)) { buf_str(b, fv > 0 ? "(1/0)" : "(-1/0)"); break; }
                    char tmp[64]; snprintf(tmp, sizeof(tmp), "%.17g", fv);
                    if (!strpbrk(tmp, ".eE") && !strchr(tmp, 'i')) strcat(tmp, ".0");
                    buf_str(b, tmp); break;
                }
                case 19: {
                    char tmp[64]; snprintf(tmp, sizeof(tmp), "%lld", (long long)kv->iv);
                    buf_str(b, tmp); break;
                }
                case 4: case 20: buf_escape_string(b, kv->s, kv->sl); break;
                default: buf_str(b, "nil"); break;
            }
        }
        free(ordered);
    } else {
        for (uint32_t i = 0; i < nk; i++) {
            KVal *kv = &kvs[i];
            if (i) buf_char(b, ',');
            switch (kv->t) {
                case 0: buf_str(b, "nil"); break;
                case 1: buf_str(b, kv->bv ? "true" : "false"); break;
                case 3: {
                    double fv = kv->f;
                    if (isnan(fv)) { buf_str(b, "(0/0)"); break; }
                    if (isinf(fv)) { buf_str(b, fv > 0 ? "(1/0)" : "(-1/0)"); break; }
                    char tmp[64]; snprintf(tmp, sizeof(tmp), "%.17g", fv);
                    if (!strpbrk(tmp, ".eE") && !strchr(tmp, 'i')) strcat(tmp, ".0");
                    buf_str(b, tmp); break;
                }
                case 19: {
                    char tmp[64]; snprintf(tmp, sizeof(tmp), "%lld", (long long)kv->iv);
                    buf_str(b, tmp); break;
                }
                case 4: case 20: buf_escape_string(b, kv->s, kv->sl); break;
                default: buf_str(b, "nil"); break;
            }
        }
    }
    buf_str(b, "},\n");
    for (int i = 0; i < depth; i++) buf_str(b, "  ");
    for (uint32_t i = 0; i < nk; i++) free(kvs[i].s);
    free(kvs);

    /* emit upvalues (already read into uv_instack/uv_idx) */
    buf_str(b, "upvalues={");
    for (uint32_t i = 0; i < nuv; i++) {
        uint8_t instack = uv_instack[i];
        uint8_t idx = uv_idx[i];
        uint8_t old_idx = idx;
        if (instack && ctx->parent_reg && idx < ctx->parent_maxstack)
            idx = (uint8_t)ctx->parent_reg[idx];
#if VM_SHUFFLE_DEBUG
        {
            char dbg2[256];
            snprintf(dbg2, sizeof(dbg2), "-- [VM_UV] uv[%d] instack=%d idx:%d->%d parent_reg=%p\n", i, instack, old_idx, idx, (void*)ctx->parent_reg);
            buf_str(b, dbg2);
        }
#endif
        char tmp[64];
        snprintf(tmp, sizeof(tmp), "%s{instack=%d,idx=%d}", i ? "," : "", instack, idx);
        buf_str(b, tmp);
    }
    buf_str(b, "},\n");
    free(uv_instack);
    free(uv_idx);
    for (int i = 0; i < depth; i++) buf_str(b, "  ");

    uint32_t np = rd_int(r);
    buf_str(b, "p={");
    EmbedCtx sub = *ctx;
    sub.parent_reg = reg_map; /* children's instack=1 upvalues refer to OUR frame */
    sub.parent_maxstack = maxstacksize;
    for (uint32_t i = 0; i < np; i++) {
        if (i) buf_char(b, ',');
        serialize_proto(r, b, depth + 1, &sub);
    }
    buf_str(b, "},\n");
    for (int i = 0; i < depth; i++) buf_str(b, "  ");

    char tmp[128];
    snprintf(tmp, sizeof(tmp), "num_params=%d,is_vararg=%d,maxstacksize=%d}\n",
             numparams, is_vararg, maxstacksize);
    buf_str(b, tmp);

    free(k_map);
    free(reg_map);
    free(ins_arr);

    uint32_t nline = rd_int(r); r->pos += nline * 4;
    uint32_t nloc = rd_int(r);
    for (uint32_t i = 0; i < nloc; i++) {
        char *sv = rd_string(r, &slen); free(sv);
        rd_int(r); rd_int(r);
    }
    uint32_t nupn = rd_int(r);
    for (uint32_t i = 0; i < nupn; i++) {
        char *sv = rd_string(r, &slen); free(sv);
    }
}

/* ---------- 库函数：字节码 -> 自包含 lua 源码 ---------- */
char *vm_embed_generate(const unsigned char *bc, size_t bc_len, int luajit_compat, size_t *out_len) {
    *out_len = 0;
    if (!bc || bc_len < 34 || (bc[0] != 0x1B && bc[0] != 0x1A)) {
        fprintf(stderr, "vm_embed: invalid bytecode (magic 0x%02X)\n", bc[0]);
        return NULL;
    }

    /* dispatch shuffle: enabled via vm_dispatch_shuffle_c / vm_dispatch_set */
    int dmode = vm_dispatch_get_mode();
    unsigned int dseed = vm_dispatch_get_seed();
    int dnops; vm_op_table(&dnops);
    int *remap = NULL;
    if (dmode > 0) {
        if (dseed == 0) { dseed = (unsigned int)time(NULL); vm_dispatch_set(dseed, dmode); }
        remap = vm_dispatch_make_remap(dseed, dnops);
    }

    Reader r = { bc, 0, bc_len, (bc[0] == 0x1A) ? 1 : 0 };
    r.pos = 34;
#if VM_EMBED_DEBUG
    { FILE *df = fopen("_vm_dbg.txt", "w"); fprintf(df, "bc[0]=0x%02X encrypted=%d bc_len=%zu dmode=%d dseed=%u\n", bc[0], r.encrypted, bc_len, dmode, dseed); fclose(df); }
#endif

    EmbedCtx ctx = {0};
    ctx.op_remap = remap;
    ctx.reg_on = vm_reg_shuffle_enabled();
    ctx.reg_seed = vm_reg_shuffle_get_seed();
    ctx.const_on = vm_const_shuffle_enabled();
    ctx.const_seed = vm_const_shuffle_get_seed();
    if (ctx.reg_on && ctx.reg_seed == 0) { ctx.reg_seed = (unsigned int)time(NULL); vm_reg_shuffle_set(ctx.reg_seed); }
    if (ctx.const_on && ctx.const_seed == 0) { ctx.const_seed = (unsigned int)time(NULL); vm_const_shuffle_set(ctx.const_seed); }
    int pidx = 0;
    ctx.idxp = &pidx;
    ctx.packed_code = 1;  /* HARDCODED for test */

    Buf chunk; buf_init(&chunk);
    serialize_proto(&r, &chunk, 1, &ctx);
    if (remap) { free(remap); remap = NULL; }

    VmAsmOpts opts = {0};
    opts.include_coroutine = 1;
    opts.include_debug = 0;
    opts.luajit_compat = luajit_compat;
    opts.dispatch_mode = dmode;
    opts.remap = (dmode > 0);
    opts.seed = dseed;
    opts.packed_code = ctx.packed_code;
    if (vm_assemble_runtime(&opts) != 0) {
        free(chunk.data);
        return NULL;
    }

    Buf out; buf_init(&out);
    buf_put(&out, opts.out, opts.out_len);
    vm_assemble_free(&opts);

    buf_str(&out, "\n");

    buf_str(&out, "local _chunk = \n");
    buf_put(&out, chunk.data, chunk.len);
    free(chunk.data);
    buf_str(&out, "\nlocal _main = build_proto(_chunk)\n");
    buf_str(&out, "local _cl = _main({[0] = {open = false, val = _G}})\n");
    buf_str(&out, "execute(_cl)\n");

    *out_len = out.len;
    return out.data;
}

/* ---------- 可执行入口 ---------- */
#if !defined(EMSCRIPTEN) && !defined(VM_EMBED_NO_MAIN)
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <input.luac> [output.lua]\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { perror("open input"); return 1; }
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    unsigned char *fbuf = malloc(fsize);
    fread(fbuf, 1, fsize, fp);
    fclose(fp);

    int lj = 0;
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--luajit") == 0) { lj = 1; argv[i] = NULL; }
    }
    size_t out_len = 0;
    char *result = vm_embed_generate(fbuf, (size_t)fsize, lj, &out_len);
    free(fbuf);
    if (!result) { fprintf(stderr, "vm_embed_generate failed\n"); return 1; }

    FILE *outf = (argc >= 3) ? fopen(argv[2], "wb") : stdout;
    if (!outf) { perror("open output"); free(result); return 1; }
    fwrite(result, 1, out_len, outf);
    if (outf != stdout) fclose(outf);
    free(result);
    return 0;
}
#endif /* EMSCRIPTEN */
