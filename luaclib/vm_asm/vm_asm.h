/*
** vm_asm.h - Modular Lua VM Assembler
** Generates a self-contained Lua 5.3 bytecode VM in Lua source.
** Supports coroutines, pcall, dynamic load, full stdlib, self-hosting.
**
** Component model: each .c file provides a generator function that returns
** malloc'd Lua source. Main assembler composes them in order.
*/
#ifndef vm_asm_h
#define vm_asm_h

#include <stddef.h>

/* Operand formats */
enum {
    FMT_ABC  = 0,
    FMT_ABx  = 1,
    FMT_AsBx = 2,
    FMT_Ax   = 3,
    FMT_AB   = 4,
};

/* Opcode descriptor */
typedef struct {
    const char *name;
    int op;
    int fmt;
    const char *body;        /* handler template; NULL = no-op */
    const char *body_compat; /* LuaJIT-compat template; NULL = use body */
} VmOp;

/* Assembly options */
typedef struct {
    int remap;            /* randomize opcode numbering */
    int dispatch_mode;    /* 0=ordered chain, 1=shuffled chain, 2=table, 3=arithmetic */
    int obfuscate_names;  /* randomize local variable names */
    int include_coroutine;/* include coroutine support */
    int include_debug;    /* include debug library */
    int luajit_compat;    /* generate LuaJIT (5.1) compatible code */
    unsigned int seed;
    /* output */
    char *out;
    size_t out_len;
} VmAsmOpts;

/* Dynamic string buffer */
typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} VmBuf;

void vmbuf_init(VmBuf *b);
void vmbuf_puts(VmBuf *b, const char *s);
void vmbuf_putc(VmBuf *b, char c);
void vmbuf_printf(VmBuf *b, const char *fmt, ...);
char *vmbuf_detach(VmBuf *b, size_t *out_len);

/* RNG */
void vm_srand(unsigned int seed);
unsigned int vm_rand(void);

/* Identifier generator */
void vm_gen_id(char *buf, int len);

/* Template substitution: replaces {A},{B},{C},{Bx},{sBx},{REG:x},{RK:x},{K:x},{JMP:x},{NEXT},{PC} */
void vm_emit_body(VmBuf *b, const char *body,
                  const char *R, const char *K, const char *UV, const char *PC,
                  const char *vA, const char *vB, const char *vC,
                  const char *vBx, const char *vsBx);

/* Component generators (each returns malloc'd Lua source) */
char *vm_gen_header(size_t *len);
char *vm_gen_opcodes(const int *remap, int luajit_compat, size_t *len);
char *vm_gen_runtime(const char *R, const char *K, const char *UV,
                     const char *PC, const char *TOP, const char *PROTO,
                     int include_coroutine, int luajit_compat, size_t *len);
char *vm_gen_dispatch(const VmOp *ops, int nops, const int *remap, int mode,
                      const char *R, const char *K, const char *UV, const char *PC,
                      int luajit_compat, unsigned int seed, size_t *len);
int *vm_dispatch_make_remap(unsigned int seed, int nops);
void vm_dispatch_set(unsigned int seed, int mode);
unsigned int vm_dispatch_get_seed(void);
int vm_dispatch_get_mode(void);
char *vm_gen_loader(size_t *len);
char *vm_gen_stdlib(int include_debug, size_t *len);
char *vm_gen_api(size_t *len);

/* Opcode table access */
const VmOp *vm_op_table(int *count);

/* Main entry */
int vm_assemble(VmAsmOpts *opts);
int vm_assemble_runtime(VmAsmOpts *opts);
char *vm_embed_generate(const unsigned char *bc, size_t bc_len, int luajit_compat, size_t *out_len);
void vm_assemble_free(VmAsmOpts *opts);

#endif /* vm_asm_h */
