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
int condition_split_process(lua_State *L);
int loop_restructure_process(lua_State *L);
int for_loop_unroll_process(lua_State *L);
int tforcall_to_call_process(lua_State *L);
int tforloop_as_jump_process(lua_State *L);
int fake_forloop_process(lua_State *L);
int junk_process(lua_State *L);
int jmp_obfuscate_process(lua_State *L);
int indirect_call_process(lua_State *L);
int flatten_enhance_process(lua_State *L);
int reg_shuffle_process(lua_State *L);
int proto_shuffle_process(lua_State *L);
int live_range_split_process(lua_State *L);
int vm_embed_process(lua_State *L);
int operator_substitute_process(lua_State *L);
int debug_mutate_process(lua_State *L);
int call_rewrite_process(lua_State *L);
int upvalue_promote_process(lua_State *L);
int block_clone_process(lua_State *L);
int obf_heapcheck_process(lua_State *L);
int obf_regcheck_process(lua_State *L);
int cfg_shuffle_process(lua_State *L);
int vm_dispatch_shuffle_process(lua_State *L);
int vm_shuffle_register(lua_State *L);

static int obf_srand_lua(lua_State *L) {
    unsigned int seed = (unsigned int)luaL_checkinteger(L, 1);
    obf_srand_force(seed);
    return 0;
}

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
    {"condition_split_c", condition_split_process},
    {"loop_restructure_c", loop_restructure_process},
    {"for_loop_unroll_c", for_loop_unroll_process},
    {"tforcall_to_call_c", tforcall_to_call_process},
    {"tforloop_as_jump_c", tforloop_as_jump_process},
    {"fake_forloop_c", fake_forloop_process},
    {"junk_c", junk_process},
    {"jmp_obfuscate_c", jmp_obfuscate_process},
    {"indirect_call_c", indirect_call_process},
    {"flatten_enhance_c", flatten_enhance_process},
    {"reg_shuffle_c", reg_shuffle_process},
    {"proto_shuffle_c", proto_shuffle_process},
    {"live_range_split_c", live_range_split_process},
    {"vm_embed_c", vm_embed_process},
    {"operator_substitute_c", operator_substitute_process},
    {"debug_mutate_c", debug_mutate_process},
    {"call_rewrite_c", call_rewrite_process},
    {"upvalue_promote_c", upvalue_promote_process},
    {"block_clone_c", block_clone_process},
    {"heapcheck_c", obf_heapcheck_process},
    {"regcheck_c", obf_regcheck_process},
    {"cfg_shuffle_c", cfg_shuffle_process},
    {"vm_dispatch_shuffle_c", vm_dispatch_shuffle_process},
    {"srand", obf_srand_lua},
    {NULL, NULL}
};

void luac_register_obfuscators(lua_State *L, int table_idx) {
    int abs_idx = lua_absindex(L, table_idx);
    for (const luaL_Reg *f = obf_funcs; f->name; f++) {
        lua_pushcfunction(L, f->func);
        lua_setfield(L, abs_idx, f->name);
    }
    /* vm_reg_shuffle_c / vm_const_shuffle_c: expect table on top */
    lua_pushvalue(L, abs_idx);
    vm_shuffle_register(L);
    lua_pop(L, 1);
}
