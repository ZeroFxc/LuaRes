/* stub for wasm build: lunsafe.c uses Linux-specific APIs not available in wasm */
#include "lua.h"
#include "lauxlib.h"

int luaopen_LUnSafe(lua_State *L) {
    (void)L;
    return 0;
}
