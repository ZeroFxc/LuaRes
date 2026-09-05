/*
** $Id: lundump.c,v 2.44 2015/11/02 16:09:30 roberto Exp $
** load precompiled Lua chunks
** See Copyright Notice in lua.h
*/

#define lundump_c
#define LUA_CORE

#include "lprefix.h"


#include <string.h>
#include <stdint.h>

#include "lua.h"

#include "ldebug.h"
#include "ldo.h"
#include "lfunc.h"
#include "lmem.h"
#include "lobject.h"
#include "lstring.h"
#include "lundump.h"
#include "lzio.h"


#if !defined(luai_verifycode)
#define luai_verifycode(L,b,f)  /* empty */
#endif


typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  size_t sizeof_size_t;
  int encrypted;  /* 1 = andlua encrypted format (luaU_undump2) */
} LoadState;



static l_noret error(LoadState *S, const char *why) {
  luaO_pushfstring(S->L, "%s: %s precompiled chunk", S->name, why);
  luaD_throw(S->L, LUA_ERRSYNTAX);
}


/*
** All high-level loads go through LoadVector; you can change it to
** adapt to the endianness of the input
*/
#define LoadVector(S,b,n)	LoadBlock(S,b,(n)*sizeof((b)[0]))

static void LoadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0)
    error(S, "truncated");
}


#define LoadVar(S,x)		LoadVector(S,&x,1)


static lu_byte LoadByte (LoadState *S) {
  lu_byte x;
  LoadVar(S, x);
  return x;
}


static int LoadInt (LoadState *S) {
  int x;
  LoadVar(S, x);
  return x;
}


static lua_Number LoadNumber (LoadState *S) {
  lua_Number x;
  LoadVar(S, x);
  return x;
}


static lua_Integer LoadInteger (LoadState *S) {
  lua_Integer x;
  LoadVar(S, x);
  return x;
}


/*
** andlua encrypted string decryption (inverse of DumpString).
** buff[0] = first_char ^ (len % 255)
** key_i = (len + first_char + key_{i-1}) % 255
** buff[i] = str[i] ^ key_i
*/
static void decrypt_string(unsigned char *buff, size_t len) {
  size_t length = len;
  unsigned char first = (unsigned char)(buff[0] ^ (length % 255));
  size_t step = (size_t)first + len;
  size_t i;
  buff[0] = first;
  for (i = 1; i < len; i++) {
    length += step;
    buff[i] ^= (unsigned char)(length % 255);
  }
}

/*
** Check if byte buffer is valid UTF-8 text.
** Used to auto-detect whether a string was andlua-encrypted:
**   encrypted -> decrypt yields valid text  -> use decrypted
**   plaintext -> decrypt yields garbage     -> keep original
*/
static int is_valid_text(const unsigned char *p, size_t len) {
  size_t i = 0;
  if (len == 0) return 1;
  while (i < len) {
    unsigned char c = p[i];
    int need;
    if (c == 0x00) return 0;  // text strings don't contain NUL
    if (c < 0x80) {
      /* ASCII: reject control chars except \t \n \r */
      if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) return 0;
      if (c == 0x7F) return 0;
      i++;
      continue;
    }
    if (c < 0xC0) return 0;  // stray continuation byte
    if (c < 0xE0) need = 1;
    else if (c < 0xF0) need = 2;
    else if (c < 0xF8) need = 3;
    else return 0;
    if (i + need >= len) return 0;
    i++;
    while (need-- > 0) {
      if ((p[i] & 0xC0) != 0x80) return 0;
      i++;
    }
  }
  return 1;
}


static TString *LoadString (LoadState *S) {
  size_t size = LoadByte(S);
  size_t len;
  if (size == 0xFF) {
    uint32_t s32;
    LoadVar(S, s32);
    size = s32;
  }
  if (size == 0)
    return NULL;
  /* andlua: only decrypt strings when loaded from encrypted bytecode (undump2).
     Standard bytecode (undump1) stores plaintext strings. */
  len = size - 1;
  if (len <= LUAI_MAXSHORTLEN) {
    char buff[LUAI_MAXSHORTLEN + 1];
    LoadVector(S, buff, len);
    if (S->encrypted && len > 0) {
      char tmp[LUAI_MAXSHORTLEN + 1];
      memcpy(tmp, buff, len);
      decrypt_string((unsigned char *)tmp, len);
      if (is_valid_text((unsigned char *)tmp, len))
        memcpy(buff, tmp, len);
    }
    return luaS_newlstr(S->L, buff, len);
  } else {
    TString *ts = luaS_createlngstrobj(S->L, len);
    LoadVector(S, getstr(ts), len);
    if (S->encrypted && len > 0) {
      char *tmp = luaM_newvector(S->L, len, char);
      memcpy(tmp, getstr(ts), len);
      decrypt_string((unsigned char *)tmp, len);
      if (is_valid_text((unsigned char *)tmp, len))
        memcpy(getstr(ts), tmp, len);
      luaM_freearray(S->L, tmp, len);
    }
    return ts;
  }
}




static void LoadCode (LoadState *S, Proto *f) {
  int n = LoadInt(S);
  f->code = luaM_newvector(S->L, n, Instruction);
  f->sizecode = n;
  LoadVector(S, f->code, n);
}


static void LoadFunction(LoadState *S, Proto *f, TString *psource);


static void LoadConstants (LoadState *S, Proto *f) {
  int i;
  int n = LoadInt(S);
  f->k = luaM_newvector(S->L, n, TValue);
  f->sizek = n;
  for (i = 0; i < n; i++)
    setnilvalue(&f->k[i]);
  for (i = 0; i < n; i++) {
    TValue *o = &f->k[i];
    int t = LoadByte(S);
    switch (t) {
    case LUA_TNIL:
      setnilvalue(o);
      break;
    case LUA_TBOOLEAN:
      setbvalue(o, LoadByte(S));
      break;
    case LUA_TNUMFLT:
      setfltvalue(o, LoadNumber(S));
      break;
    case LUA_TNUMINT:
      setivalue(o, LoadInteger(S));
      break;
    case LUA_TSHRSTR:
    case LUA_TLNGSTR:
      setsvalue2n(S->L, o, LoadString(S));
      break;
    default:
      lua_assert(0);
    }
  }
}


static void LoadProtos (LoadState *S, Proto *f) {
  int i;
  int n = LoadInt(S);
  f->p = luaM_newvector(S->L, n, Proto *);
  f->sizep = n;
  for (i = 0; i < n; i++)
    f->p[i] = NULL;
  for (i = 0; i < n; i++) {
    f->p[i] = luaF_newproto(S->L);
    LoadFunction(S, f->p[i], f->source);
  }
}


static void LoadUpvalues (LoadState *S, Proto *f) {
  int i, n;
  n = LoadInt(S);
  f->upvalues = luaM_newvector(S->L, n, Upvaldesc);
  f->sizeupvalues = n;
  for (i = 0; i < n; i++)
    f->upvalues[i].name = NULL;
  for (i = 0; i < n; i++) {
    f->upvalues[i].instack = LoadByte(S);
    f->upvalues[i].idx = LoadByte(S);
  }
}


static void LoadDebug (LoadState *S, Proto *f) {
  int i, n;
  n = LoadInt(S);
  f->lineinfo = luaM_newvector(S->L, n, int);
  f->sizelineinfo = n;
  LoadVector(S, f->lineinfo, n);
  n = LoadInt(S);
  f->locvars = luaM_newvector(S->L, n, LocVar);
  f->sizelocvars = n;
  for (i = 0; i < n; i++)
    f->locvars[i].varname = NULL;
  for (i = 0; i < n; i++) {
    f->locvars[i].varname = LoadString(S);
    f->locvars[i].startpc = LoadInt(S);
    f->locvars[i].endpc = LoadInt(S);
  }
  n = LoadInt(S);
  for (i = 0; i < n; i++)
    f->upvalues[i].name = LoadString(S);
}


static void LoadFunction (LoadState *S, Proto *f, TString *psource) {
  f->source = LoadString(S);
  if (f->source == NULL)  /* no source in dump? */
    f->source = psource;  /* reuse parent's source */
  f->linedefined = LoadInt(S);
  f->lastlinedefined = LoadInt(S);
  f->numparams = LoadByte(S);
  f->is_vararg = LoadByte(S);
  f->maxstacksize = LoadByte(S);
  LoadCode(S, f);
  LoadConstants(S, f);
  LoadUpvalues(S, f);
  LoadProtos(S, f);
  LoadDebug(S, f);
}


static void checkliteral (LoadState *S, const char *s, const char *msg) {
  char buff[sizeof(LUA_SIGNATURE) + sizeof(LUAC_DATA)]; /* larger than both */
  size_t len = strlen(s);
  LoadVector(S, buff, len);
  if (memcmp(s, buff, len) != 0)
    error(S, msg);
}


static void fchecksize (LoadState *S, size_t size, const char *tname) {
  if (LoadByte(S) != size)
    error(S, luaO_pushfstring(S->L, "%s size mismatch in", tname));
}


#define checksize(S,t)	fchecksize(S,sizeof(t),#t)

static void checkHeader (LoadState *S) {
  checkliteral(S, &LUA_SIGNATURE[1], "not a");
  if (LoadByte(S) != LUAC_VERSION)
    error(S, "version mismatch in");
  if (LoadByte(S) != LUAC_FORMAT)
    error(S, "format mismatch in");
  checkliteral(S, LUAC_DATA, "corrupted");
  checksize(S, int);
  S->sizeof_size_t = LoadByte(S);
  checksize(S, Instruction);
  checksize(S, lua_Integer);
  checksize(S, lua_Number);
  if (LoadInteger(S) != LUAC_INT)
    error(S, "endianness mismatch in");
  if (LoadNumber(S) != LUAC_NUM)
    error(S, "float format mismatch in");
}


/*
** load precompiled chunk (standard format, first byte 0x1B)
*/
LClosure *luaU_undump1(lua_State *L, ZIO *Z, const char *name) {
  LoadState S;
  LClosure *cl;
  if (*name == '@' || *name == '=')
    S.name = name + 1;
  else if (*name == LUA_SIGNATURE[0])
    S.name = "binary string";
  else
    S.name = name;
  S.L = L;
  S.Z = Z;
  S.encrypted = 0;
  checkHeader(&S);
  cl = luaF_newLclosure(L, LoadByte(&S));
  setclLvalue(L, L->top, cl);
  luaD_inctop(L);
  cl->p = luaF_newproto(L);
  LoadFunction(&S, cl->p, NULL);
  lua_assert(cl->nupvalues == cl->p->sizeupvalues);
  luai_verifycode(L, buff, cl->p);
  return cl;
}


/*
** load precompiled chunk (andlua encrypted format, first byte 0x1A/0x1C)
*/
LClosure *luaU_undump2(lua_State *L, ZIO *Z, const char *name) {
  LoadState S;
  LClosure *cl;
  if (*name == '@' || *name == '=')
    S.name = name + 1;
  else if (*name == LUA_SIGNATURE[0])
    S.name = "binary string";
  else
    S.name = name;
  S.L = L;
  S.Z = Z;
  S.encrypted = 1;
  checkHeader(&S);
  cl = luaF_newLclosure(L, LoadByte(&S));
  setclLvalue(L, L->top, cl);
  luaD_inctop(L);
  cl->p = luaF_newproto(L);
  LoadFunction(&S, cl->p, NULL);
  lua_assert(cl->nupvalues == cl->p->sizeupvalues);
  luai_verifycode(L, buff, cl->p);
  return cl;
}


/*
** legacy alias (kept for compatibility)
*/
LClosure *luaU_undump(lua_State *L, ZIO *Z, const char *name) {
  return luaU_undump1(L, Z, name);
}
