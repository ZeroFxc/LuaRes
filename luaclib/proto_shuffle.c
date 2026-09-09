/*
** proto_shuffle.c - Sub-proto reordering
** Shuffles the order of child protos in p->p[] and fixes all CLOSURE
** instruction Bx fields to point to the new indices.
** Deterministic shuffle (even-index first, odd-index second) to avoid
** obf_rand memory-layout sensitivity.
*/
#include "obf_util.h"

static int process_function(lua_State *L, luac_Proto *p) {
    if (!p->p || p->sizep < 2) return 0;

    int n = p->sizep;

    /* build deterministic permutation: even indices first, then odd */
    int *order = luac_alloc(sizeof(int) * n);
    int idx = 0;
    for (int i = 0; i < n; i += 2) order[idx++] = i;
    for (int i = 1; i < n; i += 2) order[idx++] = i;

    /* map[old_index] = new_index */
    int *map = luac_alloc(sizeof(int) * n);
    for (int new_i = 0; new_i < n; new_i++) {
        map[order[new_i]] = new_i;
    }

    /* reorder p->p[] */
    luac_Proto **new_p = luac_alloc(sizeof(luac_Proto *) * n);
    for (int i = 0; i < n; i++) {
        new_p[i] = p->p[order[i]];
    }
    free(p->p);
    p->p = new_p;

    /* if p_tbl exists, rebuild it in new order to keep Lua-side refs consistent */
    if (p->p_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, p->p_tbl);
        if (lua_istable(L, -1)) {
            /* create new table with reordered protos */
            lua_newtable(L);
            for (int i = 0; i < n; i++) {
                luac_push_proto(L, new_p[i]);
                /* luac_push_proto nulls the source struct's pointers; point
                   p->p[] at the valid userdata copy instead of the nulled one. */
                new_p[i] = (luac_Proto *)lua_touserdata(L, -1);
                lua_rawseti(L, -2, i + 1);
            }
            /* replace old ref */
            luaL_unref(L, LUA_REGISTRYINDEX, p->p_tbl);
            p->p_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
            /* pop the old table (still on stack from rawgeti) */
            lua_pop(L, 1);
        } else {
            lua_pop(L, 1);
        }
    }

    /* fix all CLOSURE instructions: Bx = old sub-proto index -> new index */
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_CLOSURE) {
            int a = (p->code[i] >> 6) & 0xFF;
            int bx = (int)(p->code[i] >> 14);
            if (bx >= 0 && bx < n) {
                p->code[i] = LUAC_ABx(LUAC_OP_CLOSURE, a, map[bx]);
                count++;
            }
        }
    }

    free(order);
    free(map);
    return count;
}

int proto_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* collect all protos */
    /* heap-allocated to avoid WASM stack overflow (64KB default stack) */
    int cap = 1024;
    luac_Proto **list = luac_alloc(sizeof(luac_Proto *) * cap);
    int list_count = 0;
    luac_Proto **stk = luac_alloc(sizeof(luac_Proto *) * cap);
    int sp = 0;
    stk[sp++] = p;
    while (sp > 0) {
        luac_Proto *cur = stk[--sp];
        if (list_count >= cap) {
            cap *= 2;
            list = realloc(list, sizeof(luac_Proto *) * cap);
            stk = realloc(stk, sizeof(luac_Proto *) * cap);
        }
        list[list_count++] = cur;
        if (cur->p) {
            for (int j = cur->sizep - 1; j >= 0; j--)
                stk[sp++] = cur->p[j];
        }
    }

    int total = 0;
    for (int i = 0; i < list_count; i++) {
        total += process_function(L, list[i]);
    }

    lua_pushinteger(L, total);
    return 1;
}
