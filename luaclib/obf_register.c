/*
** obf_register.c - Register all C obfuscation modules into the luac table
*/
#include "obf_util.h"

int str_encrypt_process(lua_State *L);
int destr_encrypt_process(lua_State *L);
int const_hide_process(lua_State *L);
int deconst_hide_process(lua_State *L);
int const_shuffle_process(lua_State *L);
int debug_strip_process(lua_State *L);
int bool_obfuscate_process(lua_State *L);
int num_obfuscate_process(lua_State *L);
int junk_jmp_process(lua_State *L);
int op48_junk_process(lua_State *L);
int opaque_predicate_process(lua_State *L);
int junk_loadk_process(lua_State *L);
int junk_move_process(lua_State *L);
int const_poison_process(lua_State *L);
int antidec_process(lua_State *L);
int table_obfuscate_process(lua_State *L);
int detable_obfuscate_process(lua_State *L);
int instruction_mutate_process(lua_State *L);
int str_split_process(lua_State *L);
int opaque_junk_process(lua_State *L);
int luac_obfuscate_process(lua_State *L);
int luac_flatten_process(lua_State *L);

static const luaL_Reg obf_funcs[] = {
    {"str_encrypt_c", str_encrypt_process},
    {"destr_encrypt_c", destr_encrypt_process},
    {"const_hide_c", const_hide_process},
    {"deconst_hide_c", deconst_hide_process},
    {"const_shuffle_c", const_shuffle_process},
    {"debug_strip_c", debug_strip_process},
    {"bool_obfuscate_c", bool_obfuscate_process},
    {"num_obfuscate_c", num_obfuscate_process},
    {"junk_jmp_c", junk_jmp_process},
    {"op48_junk_c", op48_junk_process},
    {"opaque_predicate_c", opaque_predicate_process},
    {"junk_loadk_c", junk_loadk_process},
    {"junk_move_c", junk_move_process},
    {"const_poison_c", const_poison_process},
    {"antidec_c", antidec_process},
    {"table_obfuscate_c", table_obfuscate_process},
    {"detable_obfuscate_c", detable_obfuscate_process},
    {"instruction_mutate_c", instruction_mutate_process},
    {"str_split_c", str_split_process},
    {"opaque_junk_c", opaque_junk_process},
    {"luac_obfuscate_c", luac_obfuscate_process},
    {"luac_flatten_c", luac_flatten_process},
    {NULL, NULL}
};

void luac_register_obfuscators(lua_State *L, int table_idx) {
    int abs_idx = lua_absindex(L, table_idx);
    for (const luaL_Reg *f = obf_funcs; f->name; f++) {
        lua_pushcfunction(L, f->func);
        lua_setfield(L, abs_idx, f->name);
    }
}
