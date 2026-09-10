/*
** vm_asm.c - Lua VM Assembler
** Generates a complete Lua 5.3 bytecode VM in Lua source, driven by
** an opcode metadata table. Supports opcode remapping and identifier
** obfuscation for anti-analysis.
*/
#include "vm_asm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

/* ---- dynamic string buffer ---- */
typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} SBuf;

static void sb_init(SBuf *sb) { sb->buf = NULL; sb->len = 0; sb->cap = 0; }
static void sb_reserve(SBuf *sb, size_t extra) {
    if (sb->len + extra + 1 > sb->cap) {
        sb->cap = (sb->len + extra + 1) * 2;
        sb->buf = realloc(sb->buf, sb->cap);
    }
}
static void sb_puts(SBuf *sb, const char *s) {
    size_t l = strlen(s);
    sb_reserve(sb, l);
    memcpy(sb->buf + sb->len, s, l);
    sb->len += l;
    sb->buf[sb->len] = '\0';
}
static void sb_putc(SBuf *sb, char c) {
    sb_reserve(sb, 1);
    sb->buf[sb->len++] = c;
    sb->buf[sb->len] = '\0';
}
static void sb_printf(SBuf *sb, const char *fmt, ...) {
    char tmp[4096];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(tmp, sizeof(tmp), fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if ((size_t)n < sizeof(tmp)) {
        sb_puts(sb, tmp);
    } else {
        char *big = malloc(n + 1);
        va_start(ap, fmt);
        vsnprintf(big, n + 1, fmt, ap);
        va_end(ap);
        sb_puts(sb, big);
        free(big);
    }
}

/* ---- simple RNG (xorshift32) ---- */
static unsigned int rng_state = 1;
static unsigned int rng_next(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

/* ---- opcode metadata table ----
** body templates use these placeholders:
**   {A} {B} {C} {Bx} {sBx}  - operands (already decoded)
**   {REG:x}  - register x access  -> R[x]
**   {RK:x}   - RK(x) lookup       -> (x<256 and R[x] or K[x-255])
**   {PC}     - program counter
**   {JMP:off} - pc += off (handles pre-increment model)
**   {NEXT}   - skip next instruction (pc += 1 extra)
*/
static const OpDesc op_table[] = {
    {"MOVE",     0,  FMT_ABC,  "{REG:{A}} = {REG:{B}}"},
    {"LOADK",    1,  FMT_ABx,  "{REG:{A}} = {K:{Bx}}"},
    {"LOADKX",   2,  FMT_AB,   "{REG:{A}} = {K:EXTRA}"},
    {"LOADBOOL", 3,  FMT_ABC,  "{REG:{A}} = ({B}~=0); if {C}~=0 then {NEXT} end"},
    {"LOADNIL",  4,  FMT_AB,   "for _i={A},{A}+{B} do {REG:_i}=nil end"},
    {"GETUPVAL", 5,  FMT_AB,   "{REG:{A}} = getuv({B})"},
    {"GETTABUP", 6,  FMT_ABC,  "{REG:{A}} = getuv({B})[{RK:{C}}]"},
    {"GETTABLE", 7,  FMT_ABC,  "{REG:{A}} = {REG:{B}}[{RK:{C}}]"},
    {"SETTABUP", 8,  FMT_ABC,  "getuv({A})[{RK:{B}}] = {RK:{C}}"},
    {"SETUPVAL", 9,  FMT_AB,   "setuv({B}, {REG:{A}})"},
    {"SETTABLE", 10, FMT_ABC,  "{REG:{A}}[{RK:{B}}] = {RK:{C}}"},
    {"NEWTABLE", 11, FMT_ABC,  "{REG:{A}} = {}"},
    {"SELF",     12, FMT_ABC,  "{REG:{A}+1}={REG:{B}}; {REG:{A}}={REG:{B}}[{RK:{C}}]"},
    {"ADD",      13, FMT_ABC,  "{REG:{A}} = {RK:{B}} + {RK:{C}}"},
    {"SUB",      14, FMT_ABC,  "{REG:{A}} = {RK:{B}} - {RK:{C}}"},
    {"MUL",      15, FMT_ABC,  "{REG:{A}} = {RK:{B}} * {RK:{C}}"},
    {"MOD",      16, FMT_ABC,  "{REG:{A}} = {RK:{B}} % {RK:{C}}"},
    {"POW",      17, FMT_ABC,  "{REG:{A}} = {RK:{B}} ^ {RK:{C}}"},
    {"DIV",      18, FMT_ABC,  "{REG:{A}} = {RK:{B}} / {RK:{C}}"},
    {"IDIV",     19, FMT_ABC,  "{REG:{A}} = {RK:{B}} // {RK:{C}}"},
    {"BAND",     20, FMT_ABC,  "{REG:{A}} = {RK:{B}} & {RK:{C}}"},
    {"BOR",      21, FMT_ABC,  "{REG:{A}} = {RK:{B}} | {RK:{C}}"},
    {"BXOR",     22, FMT_ABC,  "{REG:{A}} = {RK:{B}} ~ {RK:{C}}"},
    {"SHL",      23, FMT_ABC,  "{REG:{A}} = {RK:{B}} << {RK:{C}}"},
    {"SHR",      24, FMT_ABC,  "{REG:{A}} = {RK:{B}} >> {RK:{C}}"},
    {"UNM",      25, FMT_AB,   "{REG:{A}} = -{REG:{B}}"},
    {"BNOT",     26, FMT_AB,   "{REG:{A}} = ~{REG:{B}}"},
    {"NOT",      27, FMT_AB,   "{REG:{A}} = not {REG:{B}}"},
    {"LEN",      28, FMT_AB,   "{REG:{A}} = #{REG:{B}}"},
    {"CONCAT",   29, FMT_ABC,  "local _s={}; for _i={B},{C} do _s[#_s+1]=tostring({REG:_i}) end; {REG:{A}}=table.concat(_s)"},
    {"JMP",      30, FMT_AsBx, "if {A}~=0 then closeuv({A}-1, R) end; {JMP:{sBx}}"},
    {"EQ",       31, FMT_ABC,  "if ({RK:{B}}=={RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"LT",       32, FMT_ABC,  "if ({RK:{B}}<{RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"LE",       33, FMT_ABC,  "if ({RK:{B}}<={RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"TEST",     34, FMT_ABC,  "local _v={REG:{A}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {NEXT} end"},
    {"TESTSET",  35, FMT_ABC,  "local _v={REG:{B}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {REG:{A}}=_v else {NEXT} end"},
    {"CALL",     36, FMT_ABC,  "docall({A},{B},{C})"},
    {"TAILCALL", 37, FMT_ABC,  "return dotailcall({A},{B})"},
    {"RETURN",   38, FMT_AB,   "return doreturn({A},{B})"},
    {"FORLOOP",  39, FMT_AsBx, "{REG:{A}}={REG:{A}}+{REG:{A}+2}; if ({REG:{A}+2}>=0 and {REG:{A}}<={REG:{A}+1}) or ({REG:{A}+2}<0 and {REG:{A}}>={REG:{A}+1}) then {REG:{A}+3}={REG:{A}}; {JMP:{sBx}} end"},
    {"FORPREP",  40, FMT_AsBx, "{REG:{A}}={REG:{A}}-{REG:{A}+2}; {JMP:{sBx}}"},
    {"TFORCALL", 41, FMT_ABC,  "dotforcall({A},{C})"},
    {"TFORLOOP", 42, FMT_AsBx, "if {REG:{A}+1}~=nil then {REG:{A}}={REG:{A}+1}; {JMP:{sBx}} end"},
    {"SETLIST",  43, FMT_ABC,  "dosetlist({A},{B},{C})"},
    {"CLOSURE",  44, FMT_ABx,  "{REG:{A}} = makeclosure({Bx})"},
    {"VARARG",   45, FMT_AB,   "dovararg({A},{B})"},
    {"EXTRAARG", 46, FMT_Ax,   NULL},
    /* andlua extensions - minimal stubs */
    {"TBC",      47, FMT_AB,   NULL},
    {"NEWARRAY", 48, FMT_ABC,  "{REG:{A}} = {}"},
    {"TFOREACH", 49, FMT_ABC,  NULL},
    {"SECTION",  50, FMT_ABC,  NULL},
    {"IS",       51, FMT_ABC,  "{REG:{A}} = (type({REG:{B}}) == {C})"},
    {"TRY",      52, FMT_ABC,  NULL},
    {"TRYRETURN",53, FMT_AB,   "return doreturn({A},{B})"},
};

#define OP_COUNT (sizeof(op_table)/sizeof(op_table[0]))

const OpDesc *vm_op_table(int *count) {
    if (count) *count = (int)OP_COUNT;
    return op_table;
}

/* ---- identifier obfuscation ---- */
static const char *idchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
static void gen_id(char *buf, int len) {
    for (int i = 0; i < len; i++) {
        buf[i] = idchars[rng_next() % (sizeof(idchars)-1)];
    }
    buf[len] = '\0';
}

/* ---- template substitution ----
** Replaces placeholders in handler body with actual variable names.
*/
/* operand variable names (runtime) */
typedef struct {
    const char *A; const char *B; const char *C;
    const char *Bx; const char *sBx;
} OpNames;

/* substitute {A},{B},{C},{Bx},{sBx} with operand var names in a small buffer */
static void subst_ops(char *dst, size_t dstsz, const char *src, const OpNames *on) {
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
                if (strcmp(tag,"A")==0) rep = on->A;
                else if (strcmp(tag,"B")==0) rep = on->B;
                else if (strcmp(tag,"C")==0) rep = on->C;
                else if (strcmp(tag,"Bx")==0) rep = on->Bx;
                else if (strcmp(tag,"sBx")==0) rep = on->sBx;
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

static void emit_body(SBuf *sb, const char *body,
                      const char *R, const char *K, const char *UV,
                      const char *PC, const OpNames *on) {
    const char *p = body;
    while (*p) {
        if (*p == '{') {
            /* find matching } handling nesting */
            int depth = 1;
            const char *q = p + 1;
            while (*q && depth > 0) {
                if (*q == '{') depth++;
                else if (*q == '}') depth--;
                q++;
            }
            /* q points past matching } */
            size_t tlen = q - p - 2; /* content between outer { and } */
            char tag[128];
            if (tlen >= sizeof(tag)) tlen = sizeof(tag)-1;
            strncpy(tag, p+1, tlen);
            tag[tlen] = '\0';
            p = q;

            /* strip inner braces from operand refs: {A} -> A */
            char tag2[128];
            strcpy(tag2, tag);

            if (strcmp(tag2, "A")==0) sb_puts(sb, on->A);
            else if (strcmp(tag2, "B")==0) sb_puts(sb, on->B);
            else if (strcmp(tag2, "C")==0) sb_puts(sb, on->C);
            else if (strcmp(tag2, "Bx")==0) sb_puts(sb, on->Bx);
            else if (strcmp(tag2, "sBx")==0) sb_puts(sb, on->sBx);
            else if (strncmp(tag2, "REG:", 4)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag2+4, on);
                sb_printf(sb, "%s[%s]", R, idx);
            }
            else if (strncmp(tag2, "RK:", 3)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag2+3, on);
                sb_printf(sb, "(%s<256 and %s[%s] or %s[%s-255])", idx, R, idx, K, idx);
            }
            else if (strncmp(tag2, "K:", 2)==0) {
                char idx[64];
                subst_ops(idx, sizeof(idx), tag2+2, on);
                if (strcmp(idx,"extra")==0) sb_printf(sb, "%s[extra]", K);
                else sb_printf(sb, "%s[%s+1]", K, idx);  /* K is 1-based */
            }
            else if (strcmp(tag2, "PC")==0) sb_puts(sb, PC);
            else if (strncmp(tag2, "JMP:", 4)==0) {
                sb_printf(sb, "%s=%s+(%s)", PC, PC, on->sBx);
            }
            else if (strcmp(tag2, "NEXT")==0) {
                sb_printf(sb, "%s=%s+1", PC, PC);
            }
            else {
                sb_putc(sb, '{');
                sb_puts(sb, tag2);
                sb_putc(sb, '}');
            }
        } else {
            sb_putc(sb, *p++);
        }
    }
}

/* ---- main assembly ---- */
int vm_assemble(VmAsmOpts *opts) {
    if (!opts) return -1;
    rng_state = opts->seed ? opts->seed : (unsigned int)time(NULL);

    /* variable names */
    char vR[16], vK[16], vUV[16], vPC[16], vCODE[16], vTOP[16];
    char vCF[16], vPROTO[16], vARG[16];
    if (opts->obfuscate_names) {
        gen_id(vR, 6); gen_id(vK, 6); gen_id(vUV, 6); gen_id(vPC, 6);
        gen_id(vCODE, 6); gen_id(vTOP, 6); gen_id(vCF, 6); gen_id(vPROTO, 6);
        gen_id(vARG, 6);
    } else {
        strcpy(vR,"R"); strcpy(vK,"K"); strcpy(vUV,"UV"); strcpy(vPC,"pc");
        strcpy(vCODE,"code"); strcpy(vTOP,"top"); strcpy(vCF,"cf");
        strcpy(vPROTO,"proto"); strcpy(vARG,"arg");
    }

    /* opcode mapping: remap[i] = new opcode number for standard op i */
    int remap[256];
    for (int i = 0; i < 256; i++) remap[i] = i;
    if (opts->remap) {
        /* Fisher-Yates shuffle on used opcodes */
        int n = (int)OP_COUNT;
        for (int i = n-1; i > 0; i--) {
            int j = rng_next() % (i+1);
            int t = remap[i]; remap[i] = remap[j]; remap[j] = t;
        }
    }

    SBuf sb; sb_init(&sb);

    /* === HEADER === */
    sb_puts(&sb, "-- Auto-generated Lua 5.3 bytecode VM (vm_asm)\n");
    sb_puts(&sb, "local VM = {}\n\n");

    /* opcode constants */
    sb_puts(&sb, "-- opcode constants\n");
    for (int i = 0; i < (int)OP_COUNT; i++) {
        sb_printf(&sb, "local OP_%s = %d\n", op_table[i].name, remap[op_table[i].op]);
    }
    sb_puts(&sb, "\n");

    /* === HELPER FUNCTIONS === */
    sb_printf(&sb,
        "local function %s(v) return v==nil or v==false end\n", vARG); /* isfalse */
    sb_puts(&sb,
        "local function arith(op, b, c)\n"
        "  if op==13 then return b+c\n"
        "  elseif op==14 then return b-c\n"
        "  elseif op==15 then return b*c\n"
        "  elseif op==16 then return b%c\n"
        "  elseif op==17 then return b^c\n"
        "  elseif op==18 then return b/c\n"
        "  elseif op==19 then return b//c\n"
        "  elseif op==20 then return b&c\n"
        "  elseif op==21 then return b|c\n"
        "  elseif op==22 then return b~c\n"
        "  elseif op==23 then return b<<c\n"
        "  elseif op==24 then return b>>c end\n"
        "end\n\n");

    /* === CORE EXECUTION FUNCTION === */
    sb_printf(&sb, "local function execute(closure, ...)\n");
    sb_printf(&sb, "  local %s = closure.proto\n", vPROTO);
    sb_printf(&sb, "  local %s = {...}\n", vARG);
    sb_printf(&sb, "  local %s = {}\n", vR);
    sb_printf(&sb, "  local %s = %s.k\n", vK, vPROTO);
    sb_printf(&sb, "  local %s = %s.code\n", vCODE, vPROTO);
    sb_printf(&sb, "  local %s = 1\n", vPC);
    sb_printf(&sb, "  local %s = %s.maxstacksize\n", vTOP, vPROTO);
    sb_printf(&sb, "  local %s = closure.upvals\n", vUV);
    sb_printf(&sb, "  local vararg = {}\n");
    sb_printf(&sb, "  for i=1,%s.num_params do %s[i-1]=%s[i] end\n", vPROTO, vR, vARG);
    sb_printf(&sb, "  if %s.is_vararg and #%s>%s.num_params then\n", vPROTO, vARG, vPROTO);
    sb_printf(&sb, "    for i=%s.num_params+1,#%s do vararg[#vararg+1]=%s[i] end\n", vPROTO, vARG, vARG);
    sb_printf(&sb, "  end\n");

    /* upvalue helpers: cells reference live registers, closeuv snapshots */
    sb_printf(&sb,
        "  local cells = {}  -- shared upvalue cells per register\n"
        "  local function getuv(i) local u=%s[i]; if not u then return nil end; if u.cell then return u.cell.reg and u.cell.reg[u.cell.idx] or u.cell.val end; return u.val end\n"
        "  local function setuv(i,v) local u=%s[i]; if not u then u={val=v}; %s[i]=u; return end; if u.cell then if u.cell.reg then u.cell.reg[u.cell.idx]=v else u.cell.val=v end else u.val=v end end\n"
        "  local function closeuv(lvl) local _cs=cells[R] or {} for idx,cell in pairs(_cs) do if idx>=lvl and cell.reg then cell.val=cell.reg[cell.idx]; cell.reg=nil end end end\n",
        vUV, vUV, vUV);

    /* RK helper */
    sb_printf(&sb,
        "  local function rk(x) return x<256 and %s[x] or %s[x-255] end\n", vR, vK);

    /* call helper */
    sb_printf(&sb,
        "  local function docall(a,b,c)\n"
        "    local func=%s[a]\n"
        "    local nargs = b==0 and %s-a-1 or b-1\n"
        "    local args={}; for i=1,nargs do args[i]=%s[a+i] end\n"
        "    local res\n"
        "    if type(func)=='table' and func.proto then res={execute(func,table.unpack(args))}\n"
        "    else res={func(table.unpack(args))} end\n"
        "    local nret = c==0 and #res or c-1\n"
        "    if c==0 then %s=a+nret end\n"
        "    for i=1,nret do %s[a+i-1]=res[i] end\n"
        "    for i=nret+1,%s-a do %s[a+i-1]=nil end\n"
        "  end\n",
        vR, vTOP, vR, vTOP, vR, vTOP, vR);

    /* tailcall helper */
    sb_printf(&sb,
        "  local function dotailcall(a,b)\n"
        "    local func=%s[a]\n"
        "    local nargs = b==0 and %s-a-1 or b-1\n"
        "    local args={}; for i=1,nargs do args[i]=%s[a+i] end\n"
        "    if type(func)=='table' and func.proto then return execute(func,table.unpack(args))\n"
        "    else return func(table.unpack(args)) end\n"
        "  end\n", vR, vTOP, vR);

    /* return helper */
    sb_printf(&sb,
        "  local function doreturn(a,b)\n"
        "    local nret = b==0 and %s-a or b-1\n"
        "    closeuv(0)\n"
        "    local r={}; for i=1,nret do r[i]=%s[a+i-1] end\n"
        "    return table.unpack(r)\n"
        "  end\n", vTOP, vR);

    /* setlist helper */
    sb_printf(&sb,
        "  local function dosetlist(a,b,c)\n"
        "    local t=%s[a]; local n = b==0 and %s-a-1 or b\n"
        "    local fpf=50; local start\n"
        "    if c==0 then local ex=%s[%s+1]; start=(ex[2]-1)*fpf; %s=%s+1\n"
        "    else start=(c-1)*fpf end\n"
        "    for i=1,n do t[start+i]=%s[a+i] end\n"
        "  end\n", vR, vTOP, vCODE, vPC, vPC, vPC, vR);

    /* vararg helper */
    sb_printf(&sb,
        "  local function dovararg(a,b)\n"
        "    local n = b==0 and #vararg or b-1\n"
        "    if b==0 then %s=a+n end\n"
        "    for i=1,n do %s[a+i-1]=vararg[i] end\n"
        "  end\n", vTOP, vR);

    /* tforcall helper */
    sb_printf(&sb,
        "  local function dotforcall(a,c)\n"
        "    local res={%s[a](%s[a+1],%s[a+2])}\n"
        "    for i=1,c do %s[a+2+i]=res[i] end\n"
        "  end\n", vR, vR, vR, vR);

    /* closure helper: open upvalues use shared cells */
    sb_printf(&sb,
        "  local function makeclosure(bx)\n"
        "    local factory=%s.p[bx+1]\n"
        "    local uv_defs=%s.sub_uvs[bx+1] or {}\n"
        "    local uv={}\n"
        "    for i=0,#uv_defs-1 do\n"
        "      local d=uv_defs[i+1]\n"
        "      if d.instack~=0 then\n"
        "        local _cs=cells[R]\n"
        "        if not _cs then _cs={}; cells[R]=_cs end\n"
        "        if not _cs[d.idx] then _cs[d.idx]={reg=%s,idx=d.idx} end\n"
        "        uv[i]={cell=_cs[d.idx]}\n"
        "      else\n"
        "        uv[i]={val=getuv(d.idx)}\n"
        "      end\n"
        "    end\n"
        "    return factory(uv)\n"
        "  end\n", vPROTO, vPROTO, vR);

    /* === MAIN LOOP === */
    sb_printf(&sb, "  while true do\n");
    sb_printf(&sb, "    local ins = %s[%s]\n", vCODE, vPC);
    sb_printf(&sb, "    if not ins then break end\n");
    sb_printf(&sb, "    %s = %s + 1  -- pre-increment (Lua model)\n", vPC, vPC);
    sb_printf(&sb, "    local op = ins[1]\n");
    sb_printf(&sb, "    local a = ins[2] local b = ins[3] local c = ins[4]\n");
    sb_printf(&sb, "    local bx = ins[5] local sbx = ins[6]\n");

    /* dispatch: if-elseif chain generated from op table */
    for (int i = 0; i < (int)OP_COUNT; i++) {
        const OpDesc *od = &op_table[i];
        if (!od->body) continue;
        const char *kw = (i == 0) ? "if" : "elseif";
        sb_printf(&sb, "    %s op == %d then  -- %s\n", kw, remap[od->op], od->name);
        sb_puts(&sb, "      ");
        OpNames on = {"a","b","c","bx","sbx"};
        emit_body(&sb, od->body, vR, vK, vUV, vPC, &on);
        sb_putc(&sb, '\n');
    }
    sb_puts(&sb, "    else\n");
    sb_printf(&sb, "      error('VM: unknown opcode '..tostring(op)..' at pc='..tostring(%s))\n", vPC);
    sb_puts(&sb, "    end\n");
    sb_puts(&sb, "  end\n");
    sb_puts(&sb, "end\n\n");

    /* === LOADER === */
    sb_puts(&sb,
        "-- Load chunk table into executable closure\n"
        "local function load_chunk(chunk, env)\n"
        "  local k={}\n"
        "  for i,kc in ipairs(chunk.k) do\n"
        "    if kc.t=='n' then k[i]=nil\n"
        "    elseif kc.t=='b' then k[i]=kc.v\n"
        "    elseif kc.t=='i' then k[i]=math.tointeger(kc.v) or kc.v\n"
        "    elseif kc.t=='f' then k[i]=kc.v+0.0\n"
        "    elseif kc.t=='s' then k[i]=kc.v end\n"
        "  end\n"
        "  local subs={}\n"
        "  local sub_uvs={}\n"
        "  for i,sp in ipairs(chunk.p) do\n"
        "    subs[i]=load_chunk(sp,env)\n"
        "    sub_uvs[i]=sp.upvalues\n"
        "  end\n"
        "  local proto={code=chunk.code,k=k,p=subs,sub_uvs=sub_uvs,upvalues=chunk.upvalues,\n"
        "    num_params=chunk.num_params,is_vararg=chunk.is_vararg,maxstacksize=chunk.maxstacksize}\n"
        "  return function(upvals) return {proto=proto,upvals=upvals} end\n"
        "end\n\n");

    /* === PUBLIC API === */
    sb_puts(&sb,
        "function VM.load(chunk, env)\n"
        "  local factory=load_chunk(chunk,env or _G)\n"
        "  return factory({[0]={open=false,val=env or _G}})\n"
        "end\n"
        "function VM.run(closure, ...) return execute(closure, ...) end\n"
        "function VM.exec(chunk, ...) return execute(VM.load(chunk), ...) end\n"
        "return VM\n");

    opts->out = sb.buf;
    opts->out_len = sb.len;
    return 0;
}

void vm_assemble_free(VmAsmOpts *opts) {
    if (opts && opts->out) { free(opts->out); opts->out = NULL; opts->out_len = 0; }
}
