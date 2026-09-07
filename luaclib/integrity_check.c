/*
** integrity_check.c - Runtime integrity check (pure opcode + library calls)
**
** Check function (0 upvalues, receives dump as arg):
**   function(f, expected, dump)
**     local bc = dump(f)
**     local sum = 0
**     for i = 1, #bc do sum = sum + string.byte(bc, i) end
**     if sum ~= expected then while true do end end
**   end
**
** Checksum is computed via Lua round-trip to match runtime string.dump exactly:
**   temporarily replace target head with CLOSURE sub + RETURN,
**   dump+load+call to get sub-function, string.dump it, sum bytes, restore.
**
** Inserted at function start (main chunk only):
**   GETTABUP r_str, _ENV, "string"
**   GETTABLE r_dump, r_str, "dump"
**   GETTABLE r_byte, r_str, "byte"
**   CLOSURE r_check, check_idx
**   CLOSURE r_sub, sub_idx
**   LOADK r_expected, K(sum)
**   MOVE r_dump_arg, r_dump
**   MOVE r_byte_arg, r_byte
**   CALL r_check, 6, 1  ; check(sub, expected, dump, byte)
*/
#include <time.h>
#include "obf_util.h"

static const char *CHECK_SOURCE =
    "return function(f, expected, dump, byte)\n"
    "  local bc = dump(f)\n"
    "  local sum = 0\n"
    "  for i = 1, #bc do\n"
    "    sum = sum + byte(bc, i)\n"
    "  end\n"
    "  if sum ~= expected then\n"
    "    while true do end\n"
    "  end\n"
    "end\n";

typedef struct { char *buf; size_t len; } DumpBuf;

static int dump_writer(lua_State *L, const void *p, size_t sz, void *ud) {
    (void)L;
    DumpBuf *db = (DumpBuf *)ud;
    db->buf = realloc(db->buf, db->len + sz);
    memcpy(db->buf + db->len, p, sz);
    db->len += sz;
    return 0;
}

static luac_Proto *compile_check_proto(lua_State *L) {
    if (luaL_loadstring(L, CHECK_SOURCE) != 0) { lua_pop(L, 1); return NULL; }
    DumpBuf db = {0};
    if (lua_dump(L, dump_writer, &db, 0) != 0) { free(db.buf); lua_pop(L, 1); return NULL; }
    lua_pop(L, 1);

    lua_getglobal(L, "require");
    lua_pushstring(L, "luac");
    if (lua_pcall(L, 1, 1, 0) != 0) { lua_pop(L, 1); free(db.buf); return NULL; }
    lua_getfield(L, -1, "undump");
    lua_pushlstring(L, db.buf, db.len);
    lua_pushboolean(L, 0);
    free(db.buf);
    if (lua_pcall(L, 2, 1, 0) != 0) { lua_pop(L, 2); return NULL; }

    luac_Proto *main_proto = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
    if (!main_proto || main_proto->sizep < 1) { lua_pop(L, 2); return NULL; }
    luac_Proto *check = main_proto->p[0];
    main_proto->p[0] = NULL;
    lua_pop(L, 2);
    return check;
}

/* Compute checksum of sub-proto's runtime string.dump via Lua round-trip.
** Temporarily replaces p's first 2 instructions with CLOSURE sub + RETURN,
** dumps/loads/calls p to get sub-function, string.dumps it, sums bytes.
** Returns -1 on failure. Restores p's instructions before returning. */
static long long compute_checksum(lua_State *L, luac_Proto *p, int sub_idx) {
    if (p->sizecode < 2) return -1;

    /* save original first 2 instructions */
    unsigned int saved0 = p->code[0];
    unsigned int saved1 = p->code[1];

    /* replace with: CLOSURE R0, sub_idx; RETURN R0, 2 (1 result) */
    p->code[0] = LUAC_ABx(LUAC_OP_CLOSURE, 0, sub_idx);
    p->code[1] = LUAC_ABC(LUAC_OP_RETURN, 0, 2, 0);

    /* dump p to bytecode via luac.dump */
    lua_getglobal(L, "require");
    lua_pushstring(L, "luac");
    if (lua_pcall(L, 1, 1, 0) != 0) { lua_pop(L, 1); p->code[0]=saved0; p->code[1]=saved1; return -1; }
    lua_getfield(L, -1, "dump");
    lua_pushvalue(L, 1); /* proto userdata (arg 1) */
    if (lua_pcall(L, 1, 1, 0) != 0) { lua_pop(L, 2); p->code[0]=saved0; p->code[1]=saved1; return -1; }

    size_t bc_len;
    const char *bc = lua_tolstring(L, -1, &bc_len);
    if (!bc) { lua_pop(L, 2); p->code[0]=saved0; p->code[1]=saved1; return -1; }

    /* load bytecode */
    if (luaL_loadbuffer(L, bc, bc_len, "integrity_check") != 0) { lua_pop(L, 3); p->code[0]=saved0; p->code[1]=saved1; return -1; }

    /* call to get sub-function */
    if (lua_pcall(L, 0, 1, 0) != 0) { lua_pop(L, 3); p->code[0]=saved0; p->code[1]=saved1; return -1; }

    /* string.dump the sub-function */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    lua_pushvalue(L, -3); /* sub-function */
    if (lua_pcall(L, 1, 1, 0) != 0) { lua_pop(L, 4); p->code[0]=saved0; p->code[1]=saved1; return -1; }

    size_t dump_len;
    const char *dump_str = lua_tolstring(L, -1, &dump_len);
    long long sum = 0;
    if (dump_str) {
        for (size_t i = 0; i < dump_len; i++) sum += (unsigned char)dump_str[i];
    }

    lua_pop(L, 5); /* pop dump_str, string table, sub-func, bytecode, luac table */

    /* restore original instructions */
    p->code[0] = saved0;
    p->code[1] = saved1;

    return sum;
}

static int find_const_str(luac_Proto *p, const char *s) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) &&
            p->k_str[i] && strcmp(p->k_str[i], s) == 0) return i;
    }
    return -1;
}

static void inject_function(lua_State *L, luac_Proto *p) {
    if (!p->code || p->sizecode < 2) return;
    if (!p->p || p->sizep < 1) return;
    if (p->sizeupvalues < 1) return; /* need _ENV for GETTABUP */

    int sub_idx = -1;
    for (int i = 0; i < p->sizep; i++) {
        if (p->p[i] && p->p[i]->sizecode > 0) { sub_idx = i; break; }
    }
    if (sub_idx < 0) return;

    /* compute checksum FIRST (before modifying p) */
    long long expected = compute_checksum(L, p, sub_idx);
    if (expected < 0) return;

    luac_Proto *check = compile_check_proto(L);
    if (!check) return;

    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));
    int check_idx = p->sizep;
    p->p[check_idx] = check;
    p->sizep++;

    int expected_kidx = obf_add_k_integer(p, expected);

    int str_kidx = find_const_str(p, "string");
    if (str_kidx < 0) str_kidx = obf_add_k_string(p, "string", 6);
    int dump_kidx = find_const_str(p, "dump");
    if (dump_kidx < 0) dump_kidx = obf_add_k_string(p, "dump", 4);
    int byte_kidx = find_const_str(p, "byte");
    if (byte_kidx < 0) byte_kidx = obf_add_k_string(p, "byte", 4);

    int old_max = p->maxstacksize;
    int need_regs = 8;
    if (old_max + need_regs > 250) return;
    obf_ensure_stack(p, old_max + need_regs);

    int r_str = old_max;
    int r_dump = old_max + 1;
    int r_byte = old_max + 2;
    int r_check = old_max + 3;

    int extra_n = 9;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + extra_n));
    memmove(&p->code[extra_n], &p->code[0], sizeof(unsigned int) * p->sizecode);

    p->code[0] = LUAC_ABC(LUAC_OP_GETTABUP, r_str, 0, str_kidx + LUAC_BITRK);
    p->code[1] = LUAC_ABC(LUAC_OP_GETTABLE, r_dump, r_str, dump_kidx + LUAC_BITRK);
    p->code[2] = LUAC_ABC(LUAC_OP_GETTABLE, r_byte, r_str, byte_kidx + LUAC_BITRK);
    p->code[3] = LUAC_ABx(LUAC_OP_CLOSURE, r_check, check_idx);
    p->code[4] = LUAC_ABx(LUAC_OP_CLOSURE, r_check + 1, sub_idx);
    p->code[5] = LUAC_ABx(LUAC_OP_LOADK, r_check + 2, expected_kidx);
    p->code[6] = LUAC_ABC(LUAC_OP_MOVE, r_check + 3, r_dump, 0);
    p->code[7] = LUAC_ABC(LUAC_OP_MOVE, r_check + 4, r_byte, 0);
    p->code[8] = LUAC_ABC(LUAC_OP_CALL, r_check, 6, 1);

    p->sizecode += extra_n;
    obf_adjust_jumps_insert(p->code, p->sizecode, 1, extra_n);

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int integrity_check_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* apply to main chunk only (sub-functions need parent upvalues) */
    inject_function(L, p);

    lua_pushinteger(L, 1);
    return 1;
}
