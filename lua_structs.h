/*
** IDA Pro Standalone Import Header for Lua 5.4
** No external dependencies (stddef.h/stdint.h removed)
*/

#ifndef LUA_IDA_STRUCTS_H
#define LUA_IDA_STRUCTS_H

/* ============================================================================
   Manual Type Definitions (Replacing stddef.h/stdint.h)
   ============================================================================ */

/* 基础类型定义，适配 64位/32位 环境 */
#ifdef __EA64__
typedef unsigned __int64 size_t;
typedef __int64          intptr_t;
typedef __int64          ptrdiff_t;
typedef __int64          int64_t;
#else
typedef unsigned int     size_t;
typedef int              intptr_t;
typedef int              ptrdiff_t;
typedef long long        int64_t;
#endif

typedef unsigned int     uint32_t;
typedef int              int32_t;
typedef unsigned short   uint16_t;
typedef short            int16_t;
typedef unsigned char    uint8_t;
typedef unsigned char    lu_byte;

/* Lua specific basic types */
typedef intptr_t      l_mem;
typedef int64_t       lua_Integer;
typedef double        lua_Number;
typedef int           lua_KContext;
typedef int           (*lua_KFunction)(void* L, int status, int ctx);
typedef void          (*lua_Hook)(void *L, void *ar);
typedef void* lua_Alloc;
typedef void          (*lua_WarnFunction)(void *ud, void *msg, int tocont);
typedef int           (*lua_CFunction)(void *L);

/* Constants needed for array sizes */
#define LUA_EXTRASPACE  sizeof(void*)
#define LUA_GCPN        3  /* parameter number for GC */
#define TM_N            24 /* number of tag methods */
#define LUA_NUMTYPES    9
#define STRCACHE_N      53
#define STRCACHE_M      2

/* Common Header for all GC objects */
#define CommonHeader    struct GCObject *next; lu_byte tt; lu_byte marked

/* Forward declarations */
struct lua_State;
struct global_State;
struct Table;
struct Udata;
struct UpVal;
struct Proto;

/* ============================================================================
   Object Definitions
   ============================================================================ */

/* Generic GC Object wrapper */
typedef struct GCObject {
    CommonHeader;
} GCObject;

/* Lua Value Union */
typedef union Value {
    struct GCObject *gc;    /* collectable objects */
    void *p;                /* light userdata */
    lua_CFunction f;        /* light C functions */
    lua_Integer i;          /* integer numbers */
    lua_Number n;           /* float numbers */
} Value;

/* Lua TValue (Tagged Value) */
typedef struct TValue {
    Value value_;
    lu_byte tt_;
} TValue;

/* Stack pointers */
typedef TValue *StkId;
typedef TValue *StkIdRel; 

/* String Object */
typedef struct TString {
    CommonHeader;
    lu_byte extra;  /* reserved words for short strings; "has hash" for long strings */
    lu_byte shrlen; /* length for short strings */
    unsigned int hash;
    union {
        size_t lnglen;  /* length for long strings */
        struct TString *hnext;  /* linked list for hash table */
    } u;
    char contents[1];
} TString;

/* String Table (for internal string cache) */
typedef struct stringtable {
    TString **hash;
    int nuse;
    int size;
} stringtable;

/* ============================================================================
   State Structures
   ============================================================================ */

/* CallInfo: Information about a call */
typedef struct CallInfo {
    StkIdRel func;  /* function index in the stack */
    StkIdRel top;   /* top for this function */
    struct CallInfo *previous, *next;  /* dynamic call link */
    union {
        struct {  /* only for Lua functions */
            const uint32_t *savedpc; /* Instruction * */
            volatile int trap;       /* l_signalT */
            int nextraargs;
        } l;
        struct {  /* only for C functions */
            lua_KFunction k;
            ptrdiff_t old_errfunc;
            lua_KContext ctx;
        } c;
    } u;
    union {
        int funcidx;  /* called-function index */
        int nyield;   /* number of values yielded */
        int nres;     /* number of values returned */
    } u2;
    unsigned short callstatus;
    unsigned short CIST_OAH; /* Simplified status bits */
} CallInfo;

/* Status of a thread */
typedef int TStatus;

/* lua_State: Per-thread state */
typedef struct lua_State {
    CommonHeader;
    lu_byte allowhook;
    unsigned short status; /* TStatus */
    StkIdRel top;          /* first free slot in the stack */
    struct global_State *l_G;
    CallInfo *ci;          /* call info for current function */
    StkIdRel stack_last;   /* end of stack (last element + 1) */
    StkIdRel stack;        /* stack base */
    struct UpVal *openupval; /* list of open upvalues in this stack */
    StkIdRel tbclist;      /* list of to-be-closed variables */
    GCObject *gclist;
    struct lua_State *twups; /* list of threads with open upvalues */
    struct lua_longjmp *errorJmp; /* current error recover point */
    CallInfo base_ci;      /* CallInfo for first level (C host) */
    volatile lua_Hook hook;
    ptrdiff_t errfunc;     /* current error handling function (stack index) */
    uint32_t nCcalls;      /* number of nested non-yieldable or C calls */
    int oldpc;             /* last pc traced */
    int nci;               /* number of items in 'ci' list */
    int basehookcount;
    int hookcount;
    volatile int hookmask; /* l_signalT */
    struct {
        int ftransfer;
        int ntransfer;
    } transferinfo;
} lua_State;

/* LX: Thread state + extra space (Internal wrapper) */
typedef struct LX {
    lu_byte extra_[LUA_EXTRASPACE];
    lua_State l;
} LX;

/* global_State: Shared by all threads */
typedef struct global_State {
    lua_Alloc frealloc;  /* function to reallocate memory */
    void *ud;            /* auxiliary data to 'frealloc' */
    l_mem GCtotalbytes;  /* number of bytes currently allocated + debt */
    l_mem GCdebt;        /* bytes counted but not yet allocated */
    l_mem GCmarked;      /* number of objects marked in a GC cycle */
    l_mem GCmajorminor;  /* auxiliary counter to control major-minor shifts */
    stringtable strt;    /* hash table for strings */
    TValue l_registry;
    TValue nilvalue;     /* a nil value */
    unsigned int seed;   /* randomized seed for hashes */
    lu_byte gcparams[LUA_GCPN];
    lu_byte currentwhite;
    lu_byte gcstate;     /* state of garbage collector */
    lu_byte gckind;      /* kind of GC running */
    lu_byte gcstopem;    /* stops emergency collections */
    lu_byte gcstp;       /* control whether GC is running */
    lu_byte gcemergency; /* true if this is an emergency collection */
    GCObject *allgc;     /* list of all collectable objects */
    GCObject **sweepgc;  /* current position of sweep in list */
    GCObject *finobj;    /* list of collectable objects with finalizers */
    GCObject *gray;      /* list of gray objects */
    GCObject *grayagain; /* list of objects to be traversed atomically */
    GCObject *weak;      /* list of tables with weak values */
    GCObject *ephemeron; /* list of ephemeron tables (weak keys) */
    GCObject *allweak;   /* list of all-weak tables */
    GCObject *tobefnz;   /* list of userdata to be GC */
    GCObject *fixedgc;   /* list of objects not to be collected */
    /* fields for generational collector */
    GCObject *survival;  /* start of objects that survived one GC cycle */
    GCObject *old1;      /* start of old1 objects */
    GCObject *reallyold; /* objects more than one cycle old ("really old") */
    GCObject *firstold1; /* first OLD1 object in the list (if any) */
    GCObject *finobjsur; /* list of survival objects with finalizers */
    GCObject *finobjold1;/* list of old1 objects with finalizers */
    GCObject *finobjrold;/* list of really old objects with finalizers */
    struct lua_State *twups; /* list of threads with open upvalues */
    lua_CFunction panic;     /* to be called in unprotected errors */
    TString *memerrmsg;      /* message for memory-allocation errors */
    TString *tmname[TM_N];   /* array with tag-method names */
    struct Table *mt[LUA_NUMTYPES]; /* metatables for basic types */
    TString *strcache[STRCACHE_N][STRCACHE_M]; /* cache for strings in API */
    lua_WarnFunction warnf;  /* warning function */
    void *ud_warn;           /* auxiliary data to 'warnf' */
    LX mainth;               /* main thread of this state */
} global_State;

/* ============================================================================
   Additional Dummy Structs for Pointers
   ============================================================================ */

struct UpVal {
    GCObject *next; lu_byte tt; lu_byte marked; /* CommonHeader */
    TValue *v;  /* points to stack or to its own value */
    union {
        struct {
            struct UpVal *next;
            struct UpVal **previous;
        } open;
        TValue value;
    } u;
};

struct Table {
    CommonHeader;
    lu_byte flags;
    lu_byte lsizenode;
    unsigned int alimit;
    TValue *array;
    void *node;
    struct Table *metatable;
    GCObject *gclist;
};

struct Udata {
    CommonHeader;
    unsigned short nuvalue;
    size_t len;
    struct Table *metatable;
    GCObject *gclist;
};


typedef struct LoadS {
  const char *s;
  size_t size;
} LoadS;


#define ClosureHeader \
    CommonHeader; lu_byte nupvalues; GCObject *gclist

typedef struct CClosure {
  ClosureHeader;
  lua_CFunction f;
  TValue upvalue[1];  /* list of upvalues */
} CClosure;


typedef struct LClosure {
  ClosureHeader;
  struct Proto *p;
  UpVal *upvals[1];  /* list of upvalues */
} LClosure;


typedef union Closure {
  CClosure c;
  LClosure l;
} Closure;

typedef unsigned long l_uint32;

typedef l_uint32 Instruction;

typedef struct Upvaldesc {
  TString *name;  /* upvalue name (for debug information) */
  lu_byte instack;  /* whether it is in stack (register) */
  lu_byte idx;  /* index of upvalue (in stack or in outer function's list) */
  lu_byte kind;  /* kind of corresponding variable */
} Upvaldesc;

typedef signed char ls_byte;

typedef struct AbsLineInfo {
  int pc;
  int line;
} AbsLineInfo;

typedef struct LocVar {
  TString *varname;
  int startpc;  /* first point where variable is active */
  int endpc;    /* first point where variable is dead */
} LocVar;


typedef struct Proto {
  CommonHeader;
  lu_byte numparams;  /* number of fixed (named) parameters */
  lu_byte flag;
  lu_byte maxstacksize;  /* number of registers needed by this function */
  int sizeupvalues;  /* size of 'upvalues' */
  int sizek;  /* size of 'k' */
  int sizecode;
  int sizelineinfo;
  int sizep;  /* size of 'p' */
  int sizelocvars;
  int sizeabslineinfo;  /* size of 'abslineinfo' */
  int linedefined;  /* debug information  */
  int lastlinedefined;  /* debug information  */
  TValue *k;  /* constants used by the function */
  Instruction *code;  /* opcodes */
  struct Proto **p;  /* functions defined inside the function */
  Upvaldesc *upvalues;  /* upvalue information */
  ls_byte *lineinfo;  /* information about source lines (debug information) */
  AbsLineInfo *abslineinfo;  /* idem */
  LocVar *locvars;  /* information about local variables (debug information) */
  TString  *source;  /* used for debug information */
  GCObject *gclist;
} Proto;

typedef int (*lua_Writer) (lua_State *L, const void *p, size_t sz, void *ud);
typedef const char * (*lua_Reader) (lua_State *L, void *ud, size_t *sz);
typedef int (*lua_CFunction) (lua_State *L);
typedef int (*lua_KFunction) (lua_State *L, int status, lua_KContext ctx);
typedef void * (*lua_Alloc) (void *ud, void *ptr, size_t osize, size_t nsize);


typedef unsigned long long LUA_UNSIGNED;

typedef LUA_UNSIGNED lua_Unsigned;

typedef struct {
  lua_State *L;
  lua_Writer writer;
  void *data;
  size_t offset;  /* current position relative to beginning of dump */
  int strip;
  int status;
  Table *h;  /* table to track saved strings */
  lua_Unsigned nstr;  /* counter for counting saved strings */
} DumpState;

struct Zio {
  size_t n;         /* bytes still unread */
  const char *p;        /* current position in buffer */
  lua_Reader reader;        /* reader function */
  void *data;           /* additional data */
  lua_State *L;         /* Lua state (for reader) */
};

typedef struct Zio ZIO;

typedef struct Mbuffer {
  char *buffer;
  size_t n;
  size_t buffsize;
} Mbuffer;

typedef struct Vardesc {
  short idx;  /* variable index in stack */
} Vardesc;

/* description of pending goto statements and label statements */
typedef struct Labeldesc {
  TString *name;  /* label identifier */
  int pc;  /* position in code */
  int line;  /* line where it appeared */
  lu_byte nactvar;  /* local level where it appears in current block */
} Labeldesc;


/* list of labels or gotos */
typedef struct Labellist {
  Labeldesc *arr;  /* array */
  int n;  /* number of entries in use */
  int size;  /* array size */
} Labellist;

typedef struct Dyndata {
  struct {  /* list of active local variables */
    Vardesc *arr;
    int n;
    int size;
  } actvar;
  Labellist gt;  /* list of pending gotos */
  Labellist label;   /* list of active labels */
} Dyndata;

struct SParser {  /* data to 'f_parser' */
  ZIO *z;
  Mbuffer buff;  /* dynamic structure used by the scanner */
  Dyndata dyd;  /* dynamic structures used by the parser */
  const char *mode;
  const char *name;
};

#endif