/*
** vm_asm.h - Lua VM Assembler (C, generates Lua-code VM)
** Driven by opcode metadata table; dynamically generates dispatch,
** decode, and handler code. Supports opcode remapping, identifier
** obfuscation, and selective instruction inclusion.
*/
#ifndef vm_asm_h
#define vm_asm_h

#include <stddef.h>

/* Operand format */
enum {
    FMT_ABC  = 0,  /* A B C */
    FMT_ABx  = 1,  /* A Bx */
    FMT_AsBx = 2,  /* A sBx */
    FMT_Ax   = 3,  /* Ax (extra arg) */
    FMT_AB   = 4,  /* A B (no C) */
};

/* Opcode metadata */
typedef struct {
    const char *name;
    int op;             /* standard opcode number */
    int fmt;            /* operand format */
    const char *body;   /* handler body template; NULL = no-op */
} OpDesc;

/* Assembly options */
typedef struct {
    int remap;          /* 1 = randomize opcode numbering */
    int obfuscate_names;/* 1 = randomize local variable names */
    unsigned int seed;  /* RNG seed */
    /* output: malloc'd Lua source, caller frees */
    char *out;
    size_t out_len;
} VmAsmOpts;

/* Assemble a complete Lua VM source string.
** Returns 0 on success, -1 on error. opts->out is malloc'd. */
int vm_assemble(VmAsmOpts *opts);

/* Get the opcode table (for vm_pack to remap consistently) */
const OpDesc *vm_op_table(int *count);

/* Free assembled output */
void vm_assemble_free(VmAsmOpts *opts);

#endif /* vm_asm_h */
