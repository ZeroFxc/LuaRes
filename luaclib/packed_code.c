/*
** packed_code.c - Packed instruction storage for self-contained VM
**
** When enabled, vm_embed stores instructions as a packed byte string
** (9 bytes per instruction: op1+a1+bop2+c2+bx3) instead of Lua tables
** {op,a,bop,c,bx,sbx}. The VM decodes on the fly via unpack_ins().
**
** This avoids luajit NaN-tagging precision loss on 18-bit bx fields
** when the self-contained VM is compiled by luajit.
**
** luac.packed_code_c(proto, {on=1}) -> sets global flag
*/
#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include "obf_util.h"
#include "luac.h"

static int g_packed_code = 0;

int packed_code_get(void) { return g_packed_code; }
void packed_code_set(int on) { g_packed_code = on ? 1 : 0; }

int packed_code_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int on = 1;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "on");
        if (lua_isboolean(L, -1)) on = lua_toboolean(L, -1) ? 1 : 0;
        else if (lua_isnumber(L, -1)) on = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    packed_code_set(on);
    lua_pushinteger(L, on);
    return 1;
}
