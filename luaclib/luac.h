/*
** luac.h - Lua 5.3 bytecode editor library (public header)
** Shared between luac.c and obfuscation modules
*/
#ifndef LUAC_H
#define LUAC_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "lua.h"
#include "lauxlib.h"

/*===========================================================================
** Data structures
**=========================================================================*/

typedef struct luac_Proto {
    unsigned int *code;
    struct luac_Proto **p;
    /* constants */
    int *k_tag;
    char **k_str;
    int *k_str_len;
    double *k_num;
    int64_t *k_int;  /* exact int64 for LUA_TNUMINT */
    int *k_bool;
    /* debug */
    int *lineinfo;
    char **locvar_name;
    int *locvar_name_len;
    int *locvar_startpc;
    int *locvar_endpc;
    char **upval_name;
    int *upval_name_len;
    unsigned char *upval_instack;
    unsigned char *upval_idx;
    /* sizes */
    int sizecode, sizep, sizek;
    int sizelineinfo, sizelocvars, sizeupvalues;
    /* header */
    int numparams;
    unsigned char is_vararg;
    unsigned char maxstacksize;
    int linedefined;
    int lastlinedefined;
    char *source;
    int source_len;
    /* cached Lua tables (registry refs) */
    int code_tbl, p_tbl, k_tbl;
    int lineinfo_tbl, locvars_tbl, upvalues_tbl;
} luac_Proto;

/* constant tags (matching Lua 5.3) */
#define LUA_TNIL      0
#define LUA_TBOOLEAN  1
#define LUA_TNUMFLT   3
#define LUA_TNUMINT   19
#define LUA_TSHRSTR   4
#define LUA_TLNGSTR   20

/*===========================================================================
** Instruction encoding (Lua 5.3)
**=========================================================================*/

/* opcode positions */
#define LUAC_OPCODE(i)   ((i) & 0x3F)
#define LUAC_ARG_A(i)    (((i) >> 6) & 0xFF)
#define LUAC_ARG_B(i)    (((i) >> 23) & 0x1FF)
#define LUAC_ARG_C(i)    (((i) >> 14) & 0x1FF)
#define LUAC_ARG_Bx(i)   ((i) >> 14)
#define LUAC_ARG_sBx(i)  (((i) >> 14) - 131071)
#define LUAC_ARG_Ax(i)   ((i) >> 6)

#define LUAC_BITRK 0x100

/* instruction constructors */
#define LUAC_ABC(op,a,b,c)  ((unsigned int)((op) | ((a)<<6) | ((c)<<14) | ((b)<<23)))
#define LUAC_ABx(op,a,bx)   ((unsigned int)((op) | ((a)<<6) | ((bx)<<14)))
#define LUAC_AsBx(op,a,sbx) ((unsigned int)((op) | ((a)<<6) | (((sbx)+131071)<<14)))
#define LUAC_Ax(op,ax)      ((unsigned int)((op) | ((ax)<<6)))

/* opcodes (Lua 5.3) */
enum {
    LUAC_OP_MOVE=0, LUAC_OP_LOADK=1, LUAC_OP_LOADKX=2, LUAC_OP_LOADBOOL=3,
    LUAC_OP_LOADNIL=4, LUAC_OP_GETUPVAL=5, LUAC_OP_GETTABUP=6, LUAC_OP_GETTABLE=7,
    LUAC_OP_SETTABUP=8, LUAC_OP_SETUPVAL=9, LUAC_OP_SETTABLE=10, LUAC_OP_NEWTABLE=11,
    LUAC_OP_SELF=12, LUAC_OP_ADD=13, LUAC_OP_SUB=14, LUAC_OP_MUL=15,
    LUAC_OP_MOD=16, LUAC_OP_POW=17, LUAC_OP_DIV=18, LUAC_OP_IDIV=19,
    LUAC_OP_BAND=20, LUAC_OP_BOR=21, LUAC_OP_BXOR=22, LUAC_OP_SHL=23,
    LUAC_OP_SHR=24, LUAC_OP_UNM=25, LUAC_OP_BNOT=26, LUAC_OP_NOT=27,
    LUAC_OP_LEN=28, LUAC_OP_CONCAT=29, LUAC_OP_JMP=30, LUAC_OP_EQ=31,
    LUAC_OP_LT=32, LUAC_OP_LE=33, LUAC_OP_TEST=34, LUAC_OP_TESTSET=35,
    LUAC_OP_CALL=36, LUAC_OP_TAILCALL=37, LUAC_OP_RETURN=38, LUAC_OP_FORLOOP=39,
    LUAC_OP_FORPREP=40, LUAC_OP_TFORCALL=41, LUAC_OP_TFORLOOP=42,
    LUAC_OP_SETLIST=43, LUAC_OP_CLOSURE=44, LUAC_OP_VARARG=45, LUAC_OP_EXTRAARG=48
};

/*===========================================================================
** Shared memory helpers (defined in luac.c)
**=========================================================================*/
void *luac_alloc(size_t sz);
char *luac_strdup(const char *s);
char *luac_strndup(const char *s, size_t len);

/*===========================================================================
** Proto lifecycle (defined in luac.c)
**=========================================================================*/
void luac_push_proto(lua_State *L, luac_Proto *p);

/*===========================================================================
** Obfuscation module registration
** Each module provides: int module_name(lua_State *L)
**   stack: proto userdata at 1, options table at 2
**   returns: number of changes
**=========================================================================*/

/* Register all obfuscation modules into the given table */
void luac_register_obfuscators(lua_State *L, int table_idx);

/* Sync all cached Lua tables (code/k/p/lineinfo/...) back to C arrays.
   idx: stack index of proto userdata. Call after modifying table contents. */
void luac_sync_proto(lua_State *L, int idx);

#endif /* LUAC_H */
