/*
** $Id: lauxlib.c,v 1.286 2016/01/08 15:33:09 roberto Exp $
** Auxiliary functions for building Lua libraries
** See Copyright Notice in lua.h
*/

#define lauxlib_c
#define LUA_LIB

#include "lprefix.h"
#include "luacapi_log.h"


#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>


/*
** This file uses only the official API of Lua.
** Any function declared here could be written as an application function.
*/

#include "lua.h"

#include "lauxlib.h"


/*
** {======================================================
** Traceback
** =======================================================
*/


#define LEVELS1	10	/* size of the first part of the stack */
#define LEVELS2	11	/* size of the second part of the stack */



/*
** search for 'objidx' in table at index -1.
** return 1 + string at top if find a good name.
*/
static int findfield (lua_State *L, int objidx, int level) {
  if (level == 0 || !lua_istable(L, -1))
    return 0;  /* not found */
  lua_pushnil(L);  /* start 'next' loop */
  while (lua_next(L, -2)) {  /* for each pair in table */
    if (lua_type(L, -2) == LUA_TSTRING) {  /* ignore non-string keys */
      if (lua_rawequal(L, objidx, -1)) {  /* found object? */
        lua_pop(L, 1);  /* remove value (but keep name) */
        return 1;
      }
      else if (findfield(L, objidx, level - 1)) {  /* try recursively */
        lua_remove(L, -2);  /* remove table (but keep name) */
        lua_pushliteral(L, ".");
        lua_insert(L, -2);  /* place '.' between the two names */
        lua_concat(L, 3);
        return 1;
      }
    }
    lua_pop(L, 1);  /* remove value */
  }
  return 0;  /* not found */
}


/*
** Search for a name for a function in all loaded modules
** (registry._LOADED).
*/
static int pushglobalfuncname (lua_State *L, lua_Debug *ar) {
  int top = lua_gettop(L);
  lua_getinfo(L, "f", ar);  /* push function */
  lua_getfield(L, LUA_REGISTRYINDEX, "_LOADED");
  if (findfield(L, top + 1, 2)) {
    const char *name = lua_tostring(L, -1);
    if (strncmp(name, "_G.", 3) == 0) {  /* name start with '_G.'? */
      lua_pushstring(L, name + 3);  /* push name without prefix */
      lua_remove(L, -2);  /* remove original name */
    }
    lua_copy(L, -1, top + 1);  /* move name to proper place */
    lua_pop(L, 2);  /* remove pushed values */
    return 1;
  }
  else {
    lua_settop(L, top);  /* remove function and global table */
    return 0;
  }
}


static void pushfuncname (lua_State *L, lua_Debug *ar) {
  if (pushglobalfuncname(L, ar)) {  /* try first a global name */
    lua_pushfstring(L, "function '%s'", lua_tostring(L, -1));
    lua_remove(L, -2);  /* remove name */
  }
  else if (*ar->namewhat != '\0')  /* is there a name from code? */
    lua_pushfstring(L, "%s '%s'", ar->namewhat, ar->name);  /* use it */
  else if (*ar->what == 'm')  /* main? */
      lua_pushliteral(L, "main chunk");
  else if (*ar->what != 'C')  /* for Lua functions, use <file:line> */
    lua_pushfstring(L, "function <%s:%d>", ar->short_src, ar->linedefined);
  else  /* nothing left... */
    lua_pushliteral(L, "?");
}


static int lastlevel (lua_State *L) {
  lua_Debug ar;
  int li = 1, le = 1;
  /* find an upper bound */
  while (lua_getstack(L, le, &ar)) { li = le; le *= 2; }
  /* do a binary search */
  while (li < le) {
    int m = (li + le)/2;
    if (lua_getstack(L, m, &ar)) li = m + 1;
    else le = m;
  }
  return le - 1;
}


LUALIB_API void luaL_traceback (lua_State *L, lua_State *L1,
                                const char *msg, int level) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_traceback");
      luacapi_log_state("L", L);
      luacapi_log_state("L1", L1);
      luacapi_log_str("msg", msg);
      luacapi_log_int("level", (long long)(level));
      luacapi_log_end();
}
  lua_Debug ar;
  int top = lua_gettop(L);
  int last = lastlevel(L1);
  int n1 = (last - level > LEVELS1 + LEVELS2) ? LEVELS1 : -1;
  if (msg)
    lua_pushfstring(L, "%s\n", msg);
  luaL_checkstack(L, 10, NULL);
  lua_pushliteral(L, "stack traceback:");
  while (lua_getstack(L1, level++, &ar)) {
    if (n1-- == 0) {  /* too many levels? */
      lua_pushliteral(L, "\n\t...");  /* add a '...' */
      level = last - LEVELS2 + 1;  /* and skip to last ones */
    }
    else {
      lua_getinfo(L1, "Slnt", &ar);
      lua_pushfstring(L, "\n\t%s:", ar.short_src);
      if (ar.currentline > 0)
        lua_pushfstring(L, "%d:", ar.currentline);
      lua_pushliteral(L, " in ");
      pushfuncname(L, &ar);
      if (ar.istailcall)
        lua_pushliteral(L, "\n\t(...tail calls...)");
      lua_concat(L, lua_gettop(L) - top);
    }
  }
  lua_concat(L, lua_gettop(L) - top);
}

/* }====================================================== */


/*
** {======================================================
** Error-report functions
** =======================================================
*/

LUALIB_API int luaL_argerror (lua_State *L, int arg, const char *extramsg) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_argerror");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_str("extramsg", extramsg);
      luacapi_log_end();
}
  lua_Debug ar;
  if (!lua_getstack(L, 0, &ar))  /* no stack frame? */
    return luaL_error(L, "bad argument #%d (%s)", arg, extramsg);
  lua_getinfo(L, "n", &ar);
  if (strcmp(ar.namewhat, "method") == 0) {
    arg--;  /* do not count 'self' */
    if (arg == 0)  /* error is in the self argument itself? */
      return luaL_error(L, "calling '%s' on bad self (%s)",
                           ar.name, extramsg);
  }
  if (ar.name == NULL)
    ar.name = (pushglobalfuncname(L, &ar)) ? lua_tostring(L, -1) : "?";
  return luaL_error(L, "bad argument #%d to '%s' (%s)",
                        arg, ar.name, extramsg);
}


static int typeerror (lua_State *L, int arg, const char *tname) {
  const char *msg;
  const char *typearg;  /* name for the type of the actual argument */
  if (luaL_getmetafield(L, arg, "__name") == LUA_TSTRING)
    typearg = lua_tostring(L, -1);  /* use the given type name */
  else if (lua_type(L, arg) == LUA_TLIGHTUSERDATA)
    typearg = "light userdata";  /* special name for messages */
  else
    typearg = luaL_typename(L, arg);  /* standard name */
  msg = lua_pushfstring(L, "%s expected, got %s", tname, typearg);
  return luaL_argerror(L, arg, msg);
}


static void tag_error (lua_State *L, int arg, int tag) {
  typeerror(L, arg, lua_typename(L, tag));
}


/*
** The use of 'lua_pushfstring' ensures this function does not
** need reserved stack space when called.
*/
LUALIB_API void luaL_where (lua_State *L, int level) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_where");
      luacapi_log_state("L", L);
      luacapi_log_int("level", (long long)(level));
      luacapi_log_end();
}
  lua_Debug ar;
  if (lua_getstack(L, level, &ar)) {  /* check function at level */
    lua_getinfo(L, "Sl", &ar);  /* get info about it */
    if (ar.currentline > 0) {  /* is there info? */
      lua_pushfstring(L, "%s:%d: ", ar.short_src, ar.currentline);
      return;
    }
  }
  lua_pushfstring(L, "");  /* else, no information available... */
}


/*
** Again, the use of 'lua_pushvfstring' ensures this function does
** not need reserved stack space when called. (At worst, it generates
** an error with "stack overflow" instead of the given message.)
*/
LUALIB_API int luaL_error (lua_State *L, const char *fmt, ...) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_error");
      luacapi_log_state("L", L);
      luacapi_log_str("fmt", fmt);
      luacapi_log_end();
}
  va_list argp;
  va_start(argp, fmt);
  luaL_where(L, 1);
  lua_pushvfstring(L, fmt, argp);
  va_end(argp);
  lua_concat(L, 2);
  return lua_error(L);
}


LUALIB_API int luaL_fileresult (lua_State *L, int stat, const char *fname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_fileresult");
      luacapi_log_state("L", L);
      luacapi_log_int("stat", (long long)(stat));
      luacapi_log_str("fname", fname);
      luacapi_log_end();
}
  int en = errno;  /* calls to Lua API may change this value */
  if (stat) {
    lua_pushboolean(L, 1);
    return 1;
  }
  else {
    lua_pushnil(L);
    if (fname)
      lua_pushfstring(L, "%s: %s", fname, strerror(en));
    else
      lua_pushstring(L, strerror(en));
    lua_pushinteger(L, en);
    return 3;
  }
}


#if !defined(l_inspectstat)	/* { */

#if defined(LUA_USE_POSIX)

#include <sys/wait.h>

/*
** use appropriate macros to interpret 'pclose' return status
*/
#define l_inspectstat(stat,what)  \
   if (WIFEXITED(stat)) { stat = WEXITSTATUS(stat); } \
   else if (WIFSIGNALED(stat)) { stat = WTERMSIG(stat); what = "signal"; }

#else

#define l_inspectstat(stat,what)  /* no op */

#endif

#endif				/* } */


LUALIB_API int luaL_execresult (lua_State *L, int stat) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_execresult");
      luacapi_log_state("L", L);
      luacapi_log_int("stat", (long long)(stat));
      luacapi_log_end();
}
  const char *what = "exit";  /* type of termination */
  if (stat == -1)  /* error? */
    return luaL_fileresult(L, 0, NULL);
  else {
    l_inspectstat(stat, what);  /* interpret result */
    if (*what == 'e' && stat == 0)  /* successful termination? */
      lua_pushboolean(L, 1);
    else
      lua_pushnil(L);
    lua_pushstring(L, what);
    lua_pushinteger(L, stat);
    return 3;  /* return true/nil,what,code */
  }
}

/* }====================================================== */


/*
** {======================================================
** Userdata's metatable manipulation
** =======================================================
*/

LUALIB_API int luaL_newmetatable (lua_State *L, const char *tname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_newmetatable");
      luacapi_log_state("L", L);
      luacapi_log_str("tname", tname);
      luacapi_log_end();
}
  if (luaL_getmetatable(L, tname) != LUA_TNIL)  /* name already in use? */
    return 0;  /* leave previous value on top, but return 0 */
  lua_pop(L, 1);
  lua_createtable(L, 0, 2);  /* create metatable */
  lua_pushstring(L, tname);
  lua_setfield(L, -2, "__name");  /* metatable.__name = tname */
  lua_pushvalue(L, -1);
  lua_setfield(L, LUA_REGISTRYINDEX, tname);  /* registry.name = metatable */
  return 1;
}


LUALIB_API void luaL_setmetatable (lua_State *L, const char *tname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_setmetatable");
      luacapi_log_state("L", L);
      luacapi_log_str("tname", tname);
      luacapi_log_end();
}
  luaL_getmetatable(L, tname);
  lua_setmetatable(L, -2);
}


LUALIB_API void *luaL_testudata (lua_State *L, int ud, const char *tname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_testudata");
      luacapi_log_state("L", L);
      luacapi_log_int("ud", (long long)(ud));
      luacapi_log_str("tname", tname);
      luacapi_log_end();
}
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      luaL_getmetatable(L, tname);  /* get correct metatable */
      if (!lua_rawequal(L, -1, -2))  /* not the same? */
        p = NULL;  /* value is a userdata with wrong metatable */
      lua_pop(L, 2);  /* remove both metatables */
      return p;
    }
  }
  return NULL;  /* value is not a userdata with a metatable */
}


LUALIB_API void *luaL_checkudata (lua_State *L, int ud, const char *tname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkudata");
      luacapi_log_state("L", L);
      luacapi_log_int("ud", (long long)(ud));
      luacapi_log_str("tname", tname);
      luacapi_log_end();
}
  void *p = luaL_testudata(L, ud, tname);
  if (p == NULL) typeerror(L, ud, tname);
  return p;
}

/* }====================================================== */


/*
** {======================================================
** Argument check functions
** =======================================================
*/

LUALIB_API int luaL_checkoption (lua_State *L, int arg, const char *def,
                                 const char *const lst[]) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkoption");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_str("def", def);
      luacapi_log_end();
}
  const char *name = (def) ? luaL_optstring(L, arg, def) :
                             luaL_checkstring(L, arg);
  int i;
  for (i=0; lst[i]; i++)
    if (strcmp(lst[i], name) == 0)
      return i;
  return luaL_argerror(L, arg,
                       lua_pushfstring(L, "invalid option '%s'", name));
}


/*
** Ensures the stack has at least 'space' extra slots, raising an error
** if it cannot fulfill the request. (The error handling needs a few
** extra slots to format the error message. In case of an error without
** this extra space, Lua will generate the same 'stack overflow' error,
** but without 'msg'.)
*/
LUALIB_API void luaL_checkstack (lua_State *L, int space, const char *msg) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkstack");
      luacapi_log_state("L", L);
      luacapi_log_int("space", (long long)(space));
      luacapi_log_str("msg", msg);
      luacapi_log_end();
}
  if (!lua_checkstack(L, space)) {
    if (msg)
      luaL_error(L, "stack overflow (%s)", msg);
    else
      luaL_error(L, "stack overflow");
  }
}


LUALIB_API void luaL_checktype (lua_State *L, int arg, int t) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checktype");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_int("t", (long long)(t));
      luacapi_log_end();
}
  if (lua_type(L, arg) != t)
    tag_error(L, arg, t);
}


LUALIB_API void luaL_checkany (lua_State *L, int arg) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkany");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_end();
}
  if (lua_type(L, arg) == LUA_TNONE)
    luaL_argerror(L, arg, "value expected");
}


LUALIB_API const char *luaL_checklstring (lua_State *L, int arg, size_t *len) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checklstring");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_ptr("len", (const void *)(len));
      luacapi_log_end();
}
  const char *s = lua_tolstring(L, arg, len);
  if (!s) tag_error(L, arg, LUA_TSTRING);
  return s;
}


LUALIB_API const char *luaL_optlstring (lua_State *L, int arg,
                                        const char *def, size_t *len) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_optlstring");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_str("def", def);
      luacapi_log_ptr("len", (const void *)(len));
      luacapi_log_end();
}
  if (lua_isnoneornil(L, arg)) {
    if (len)
      *len = (def ? strlen(def) : 0);
    return def;
  }
  else return luaL_checklstring(L, arg, len);
}


LUALIB_API lua_Number luaL_checknumber (lua_State *L, int arg) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checknumber");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_end();
}
  int isnum;
  lua_Number d = lua_tonumberx(L, arg, &isnum);
  if (!isnum)
    tag_error(L, arg, LUA_TNUMBER);
  return d;
}


LUALIB_API lua_Number luaL_optnumber (lua_State *L, int arg, lua_Number def) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_optnumber");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_num("def", (double)(def));
      luacapi_log_end();
}
  return luaL_opt(L, luaL_checknumber, arg, def);
}


static void interror (lua_State *L, int arg) {
  if (lua_isnumber(L, arg))
    luaL_argerror(L, arg, "number has no integer representation");
  else
    tag_error(L, arg, LUA_TNUMBER);
}


LUALIB_API lua_Integer luaL_checkinteger (lua_State *L, int arg) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkinteger");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_end();
}
  int isnum;
  lua_Integer d = lua_tointegerx(L, arg, &isnum);
  if (!isnum) {
    interror(L, arg);
  }
  return d;
}


LUALIB_API lua_Integer luaL_optinteger (lua_State *L, int arg,
                                                      lua_Integer def) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_optinteger");
      luacapi_log_state("L", L);
      luacapi_log_int("arg", (long long)(arg));
      luacapi_log_int("def", (long long)(def));
      luacapi_log_end();
}
  return luaL_opt(L, luaL_checkinteger, arg, def);
}

/* }====================================================== */


/*
** {======================================================
** Generic Buffer manipulation
** =======================================================
*/

/* userdata to box arbitrary data */
typedef struct UBox {
  void *box;
  size_t bsize;
} UBox;


static void *resizebox (lua_State *L, int idx, size_t newsize) {
  void *ud;
  lua_Alloc allocf = lua_getallocf(L, &ud);
  UBox *box = (UBox *)lua_touserdata(L, idx);
  void *temp = allocf(ud, box->box, box->bsize, newsize);
  if (temp == NULL && newsize > 0) {  /* allocation error? */
    resizebox(L, idx, 0);  /* free buffer */
    luaL_error(L, "not enough memory for buffer allocation");
  }
  box->box = temp;
  box->bsize = newsize;
  return temp;
}


static int boxgc (lua_State *L) {
  resizebox(L, 1, 0);
  return 0;
}


static void *newbox (lua_State *L, size_t newsize) {
  UBox *box = (UBox *)lua_newuserdata(L, sizeof(UBox));
  box->box = NULL;
  box->bsize = 0;
  if (luaL_newmetatable(L, "LUABOX")) {  /* creating metatable? */
    lua_pushcfunction(L, boxgc);
    lua_setfield(L, -2, "__gc");  /* metatable.__gc = boxgc */
  }
  lua_setmetatable(L, -2);
  return resizebox(L, -1, newsize);
}


/*
** check whether buffer is using a userdata on the stack as a temporary
** buffer
*/
#define buffonstack(B)	((B)->b != (B)->initb)


/*
** returns a pointer to a free area with at least 'sz' bytes
*/
LUALIB_API char *luaL_prepbuffsize (luaL_Buffer *B, size_t sz) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_prepbuffsize");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_uint("sz", (unsigned long long)(sz));
      luacapi_log_end();
}
  lua_State *L = B->L;
  if (B->size - B->n < sz) {  /* not enough space? */
    char *newbuff;
    size_t newsize = B->size * 2;  /* double buffer size */
    if (newsize - B->n < sz)  /* not big enough? */
      newsize = B->n + sz;
    if (newsize < B->n || newsize - B->n < sz)
      luaL_error(L, "buffer too large");
    /* create larger buffer */
    if (buffonstack(B))
      newbuff = (char *)resizebox(L, -1, newsize);
    else {  /* no buffer yet */
      newbuff = (char *)newbox(L, newsize);
      memcpy(newbuff, B->b, B->n * sizeof(char));  /* copy original content */
    }
    B->b = newbuff;
    B->size = newsize;
  }
  return &B->b[B->n];
}


LUALIB_API void luaL_addlstring (luaL_Buffer *B, const char *s, size_t l) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_addlstring");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_strn("s", s, (size_t)(l));
      luacapi_log_uint("l", (unsigned long long)(l));
      luacapi_log_end();
}
  if (l > 0) {  /* avoid 'memcpy' when 's' can be NULL */
    char *b = luaL_prepbuffsize(B, l);
    memcpy(b, s, l * sizeof(char));
    luaL_addsize(B, l);
  }
}


LUALIB_API void luaL_addstring (luaL_Buffer *B, const char *s) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_addstring");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_str("s", s);
      luacapi_log_end();
}
  luaL_addlstring(B, s, strlen(s));
}


LUALIB_API void luaL_pushresult (luaL_Buffer *B) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_pushresult");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_end();
}
  lua_State *L = B->L;
  lua_pushlstring(L, B->b, B->n);
  if (buffonstack(B)) {
    resizebox(L, -2, 0);  /* delete old buffer */
    lua_remove(L, -2);  /* remove its header from the stack */
  }
}


LUALIB_API void luaL_pushresultsize (luaL_Buffer *B, size_t sz) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_pushresultsize");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_uint("sz", (unsigned long long)(sz));
      luacapi_log_end();
}
  luaL_addsize(B, sz);
  luaL_pushresult(B);
}


LUALIB_API const char *luaL_resultBuffer (luaL_Buffer *B) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_resultBuffer");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_end();
}
  lua_State *L = B->L;
  const char *s = lua_pushlstring(L, B->b, B->n);
  if (buffonstack(B)) {
    resizebox(L, -2, 0);  /* delete old buffer */
    lua_remove(L, -2);  /* remove its header from the stack */
  }
  lua_pop(L, 1);  /* andlua: pop the string, return only data pointer */
  return s;
}


LUALIB_API void luaL_addvalue (luaL_Buffer *B) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_addvalue");
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_end();
}
  lua_State *L = B->L;
  size_t l;
  const char *s = lua_tolstring(L, -1, &l);
  if (buffonstack(B))
    lua_insert(L, -2);  /* put value below buffer */
  luaL_addlstring(B, s, l);
  lua_remove(L, (buffonstack(B)) ? -2 : -1);  /* remove value */
}


LUALIB_API void luaL_buffinit (lua_State *L, luaL_Buffer *B) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_buffinit");
      luacapi_log_state("L", L);
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_end();
}
  B->L = L;
  B->b = B->initb;
  B->n = 0;
  B->size = LUAL_BUFFERSIZE;
}


LUALIB_API char *luaL_buffinitsize (lua_State *L, luaL_Buffer *B, size_t sz) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_buffinitsize");
      luacapi_log_state("L", L);
      luacapi_log_ptr("B", (const void *)(B));
      luacapi_log_uint("sz", (unsigned long long)(sz));
      luacapi_log_end();
}
  luaL_buffinit(L, B);
  return luaL_prepbuffsize(B, sz);
}

/* }====================================================== */


/*
** {======================================================
** Reference system
** =======================================================
*/

/* index of free-list header */
#define freelist	0


LUALIB_API int luaL_ref (lua_State *L, int t) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_ref");
      luacapi_log_state("L", L);
      luacapi_log_int("t", (long long)(t));
      luacapi_log_end();
}
  int ref;
  if (lua_isnil(L, -1)) {
    lua_pop(L, 1);  /* remove from stack */
    return LUA_REFNIL;  /* 'nil' has a unique fixed reference */
  }
  t = lua_absindex(L, t);
  lua_rawgeti(L, t, freelist);  /* get first free element */
  ref = (int)lua_tointeger(L, -1);  /* ref = t[freelist] */
  lua_pop(L, 1);  /* remove it from stack */
  if (ref != 0) {  /* any free element? */
    lua_rawgeti(L, t, ref);  /* remove it from list */
    lua_rawseti(L, t, freelist);  /* (t[freelist] = t[ref]) */
  }
  else  /* no free elements */
    ref = (int)lua_rawlen(L, t) + 1;  /* get a new reference */
  lua_rawseti(L, t, ref);
  return ref;
}


LUALIB_API void luaL_unref (lua_State *L, int t, int ref) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_unref");
      luacapi_log_state("L", L);
      luacapi_log_int("t", (long long)(t));
      luacapi_log_int("ref", (long long)(ref));
      luacapi_log_end();
}
  if (ref >= 0) {
    t = lua_absindex(L, t);
    lua_rawgeti(L, t, freelist);
    lua_rawseti(L, t, ref);  /* t[ref] = t[freelist] */
    lua_pushinteger(L, ref);
    lua_rawseti(L, t, freelist);  /* t[freelist] = ref */
  }
}

/* }====================================================== */


/*
** {======================================================
** Load functions
** =======================================================
*/

typedef struct LoadF {
  int n;  /* number of pre-read characters */
  FILE *f;  /* file being read */
  char buff[BUFSIZ];  /* area for reading file */
} LoadF;


static const char *getF (lua_State *L, void *ud, size_t *size) {
  LoadF *lf = (LoadF *)ud;
  (void)L;  /* not used */
  if (lf->n > 0) {  /* are there pre-read characters to be read? */
    *size = lf->n;  /* return them (chars already in buffer) */
    lf->n = 0;  /* no more pre-read characters */
  }
  else {  /* read a block from file */
    /* 'fread' can return > 0 *and* set the EOF flag. If next call to
       'getF' called 'fread', it might still wait for user input.
       The next check avoids this problem. */
    if (feof(lf->f)) return NULL;
    *size = fread(lf->buff, 1, sizeof(lf->buff), lf->f);  /* read block */
  }
  return lf->buff;
}


static int errfile (lua_State *L, const char *what, int fnameindex) {
  const char *serr = strerror(errno);
  const char *filename = lua_tostring(L, fnameindex) + 1;
  lua_pushfstring(L, "cannot %s %s: %s", what, filename, serr);
  lua_remove(L, fnameindex);
  return LUA_ERRFILE;
}


static int skipBOM (LoadF *lf) {
  const char *p = "\xEF\xBB\xBF";  /* UTF-8 BOM mark */
  int c;
  lf->n = 0;
  do {
    c = getc(lf->f);
    if (c == EOF || c != *(const unsigned char *)p++) return c;
    lf->buff[lf->n++] = c;  /* to be read by the parser */
  } while (*p != '\0');
  lf->n = 0;  /* prefix matched; discard it */
  return getc(lf->f);  /* return next character */
}


/*
** reads the first character of file 'f' and skips an optional BOM mark
** in its beginning plus its first line if it starts with '#'. Returns
** true if it skipped the first line.  In any case, '*cp' has the
** first "valid" character of the file (after the optional BOM and
** a first-line comment).
*/
static int skipcomment (LoadF *lf, int *cp) {
  int c = *cp = skipBOM(lf);
  if (c == '#') {  /* first line is a comment (Unix exec. file)? */
    do {  /* skip first line */
      c = getc(lf->f);
    } while (c != EOF && c != '\n');
    *cp = getc(lf->f);  /* skip end-of-line, if present */
    return 1;  /* there was a comment */
  }
  else return 0;  /* no comment */
}

static luaL_Buffer read_all (lua_State *L, FILE *f) {
    size_t nr;
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    do {  /* read file in chunks of LUAL_BUFFERSIZE bytes */
        char *p = luaL_prepbuffer(&b);
        nr = fread(p, sizeof(char), LUAL_BUFFERSIZE, f);
        luaL_addsize(&b, nr);
    } while (nr == LUAL_BUFFERSIZE);
    return b;
}


LUALIB_API int luaL_loadfilex (lua_State *L, const char *filename,
                                             const char *mode) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_loadfilex");
      luacapi_log_state("L", L);
      luacapi_log_str("filename", filename);
      luacapi_log_str("mode", mode);
      luacapi_log_end();
}
  LoadF lf;
  int status, readstatus;
  int c;
  int fnameindex = lua_gettop(L) + 1;  /* index of filename on the stack */
  if (filename == NULL) {
    lua_pushliteral(L, "=stdin");
    lf.f = stdin;
  }
  else {
    lua_pushfstring(L, "@%s", filename);
    lf.f = fopen(filename, "r");
    if (lf.f == NULL) return errfile(L, "open", fnameindex);
  }
  if (skipcomment(&lf, &c))  /* read initial portion */
    lf.buff[lf.n++] = '\n';  /* add line to correct line numbers */
  /* andlua: binary (0x1B/0x1A), encrypted (0x1C), base64 ('=') shells —
     read whole file and delegate to luaL_loadbufferx for decryption */
  if (filename && (c == LUA_SIGNATURE[0] || c == 0x1A || c == 0x1C || c == '=')) {
      long fsize;
      lf.f = freopen(filename, "rb", lf.f);
      if (lf.f == NULL) return errfile(L, "reopen", fnameindex);
      fseek(lf.f, 0, SEEK_END);
      fsize = ftell(lf.f);
      fseek(lf.f, 0, SEEK_SET);
      if (fsize < 0) fsize = 0;
      {
        char *dat = (char *)malloc((size_t)fsize + 1);
        size_t sz = fread(dat, 1, (size_t)fsize, lf.f);
        const char *name;
        fclose(lf.f);
        name = lua_tolstring(L, -1, NULL);  /* stack top = chunkname */
        status = luaL_loadbufferx(L, dat, sz, name, mode);
        free(dat);
      }
      lua_remove(L, -2);  /* drop chunkname, keep result/error on top */
      return status;
  }
  if (c != EOF)
    lf.buff[lf.n++] = c;  /* 'c' is the first character of the stream */
  status = lua_load(L, getF, &lf, lua_tostring(L, -1), mode);
  readstatus = ferror(lf.f);
  if (filename) fclose(lf.f);  /* close file (even in case of errors) */
  if (readstatus) {
    lua_settop(L, fnameindex);  /* ignore results from 'lua_load' */
    return errfile(L, "read", fnameindex);
  }
  lua_remove(L, fnameindex);
  return status;
}


/*
** {======================================================
** andlua base64 / XOR / zlib shell
** =======================================================
*/

static int andlua_b64val (unsigned char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  if (c == '=') return -2;
  return -1;
}

/* first input char is the '=' marker, treated as base64 value 7 */
static unsigned char *andlua_b64decode (const char *in, size_t inlen, size_t *outlen) {
  size_t cap = (inlen / 4 + 1) * 3 + 4;
  unsigned char *out = (unsigned char *)malloc(cap);
  size_t pos = 0;
  int vals[4];
  int nv = 0, npad = 0;
  size_t i;
  if (!out) return NULL;
  for (i = 0; i < inlen; i++) {
    int v;
    if (i == 0) { v = 7; }  /* '=' prefix -> value 7 */
    else {
      v = andlua_b64val((unsigned char)in[i]);
      if (v == -1) continue;
      if (v == -2) { npad++; v = 0; }
    }
    vals[nv++] = v;
    if (nv == 4) {
      out[pos++] = (unsigned char)((vals[0] << 2) | (vals[1] >> 4));
      if (npad < 2) out[pos++] = (unsigned char)((vals[1] << 4) | (vals[2] >> 2));
      if (npad < 1) out[pos++] = (unsigned char)((vals[2] << 6) | vals[3]);
      nv = 0; npad = 0;
    }
  }
  /* handle remaining chars (no padding) */
  if (nv >= 2) {
    out[pos++] = (unsigned char)((vals[0] << 2) | (vals[1] >> 4));
    if (nv >= 3) out[pos++] = (unsigned char)((vals[1] << 4) | (vals[2] >> 2));
  }
  *outlen = pos;
  return out;
}

/* running-XOR CBC decrypt: out[i] = xor of in[0..i] */
static void andlua_xor_decrypt (unsigned char *data, size_t size) {
  unsigned char key = 0;
  size_t i;
  for (i = 0; i < size; i++) {
    key ^= data[i];
    data[i] = key;
  }
}

static unsigned char *andlua_inflate (const unsigned char *in, size_t inlen, size_t *outlen) {
  z_stream strm;
  size_t cap = inlen * 2 + 4096;
  unsigned char *out;
  int ret;
  memset(&strm, 0, sizeof(strm));
  if (inflateInit(&strm) != Z_OK) return NULL;
  out = (unsigned char *)malloc(cap);
  if (!out) { inflateEnd(&strm); return NULL; }
  strm.next_in = (Bytef *)in;
  strm.avail_in = (uInt)inlen;
  strm.next_out = out;
  strm.avail_out = (uInt)cap;
  for (;;) {
    ret = inflate(&strm, Z_FINISH);
    if (ret == Z_STREAM_END) break;
    if (ret != Z_OK && ret != Z_BUF_ERROR) {
      free(out); inflateEnd(&strm); return NULL;
    }
    if (strm.avail_out != 0) {
      /* 无输出空间耗尽却未结束：流损坏 */
      free(out); inflateEnd(&strm); return NULL;
    }
    /* 输出缓冲耗尽，翻倍扩容继续 */
    {
      size_t used = strm.total_out;
      cap *= 2;
      unsigned char *tmp = (unsigned char *)realloc(out, cap);
      if (!tmp) { free(out); inflateEnd(&strm); return NULL; }
      out = tmp;
      strm.next_out = out + used;
      strm.avail_out = (uInt)(cap - used);
    }
  }
  *outlen = strm.total_out;
  inflateEnd(&strm);
  return out;
}

/* ---- encryption side (str_dump) ---- */

static unsigned char *andlua_deflate (const unsigned char *in, size_t inlen, size_t *outlen) {
  z_stream strm;
  size_t cap = inlen + (inlen >> 4) + 64;
  unsigned char *out;
  int ret;
  memset(&strm, 0, sizeof(strm));
  if (deflateInit(&strm, Z_DEFAULT_COMPRESSION) != Z_OK) return NULL;
  out = (unsigned char *)malloc(cap);
  if (!out) { deflateEnd(&strm); return NULL; }
  strm.next_in = (Bytef *)in;
  strm.avail_in = (uInt)inlen;
  strm.next_out = out;
  strm.avail_out = (uInt)cap;
  ret = deflate(&strm, Z_FINISH);
  if (ret != Z_STREAM_END) {
    free(out); deflateEnd(&strm); return NULL;
  }
  *outlen = strm.total_out;
  deflateEnd(&strm);
  return out;
}

/* andlua XOR encrypt: out[i] = in[i] ^ in[i-1] (uses ORIGINAL previous byte) */
static void andlua_xor_encrypt (unsigned char *data, size_t size) {
  size_t i;
  unsigned char prev = data[0];
  for (i = 1; i < size; i++) {
    unsigned char cur = data[i];
    data[i] = cur ^ prev;
    prev = cur;
  }
}

static const char andlua_b64chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char *andlua_b64encode (const unsigned char *in, size_t inlen, size_t *outlen) {
  size_t cap = ((inlen + 2) / 3) * 4 + 1;
  char *out = (char *)malloc(cap);
  size_t pos = 0;
  size_t i;
  if (!out) return NULL;
  for (i = 0; i + 2 < inlen; i += 3) {
    unsigned int v = ((unsigned int)in[i] << 16) | ((unsigned int)in[i+1] << 8) | in[i+2];
    out[pos++] = andlua_b64chars[(v >> 18) & 0x3F];
    out[pos++] = andlua_b64chars[(v >> 12) & 0x3F];
    out[pos++] = andlua_b64chars[(v >> 6) & 0x3F];
    out[pos++] = andlua_b64chars[v & 0x3F];
  }
  if (i < inlen) {
    unsigned int v = (unsigned int)in[i] << 16;
    if (i + 1 < inlen) v |= (unsigned int)in[i+1] << 8;
    out[pos++] = andlua_b64chars[(v >> 18) & 0x3F];
    out[pos++] = andlua_b64chars[(v >> 12) & 0x3F];
    out[pos++] = (i + 1 < inlen) ? andlua_b64chars[(v >> 6) & 0x3F] : '=';
    out[pos++] = '=';
  }
  out[pos] = '\0';
  *outlen = pos;
  return out;
}

/* writer for lua_dump: appends to dynamic buffer */
typedef struct DumpBuf {
  unsigned char *data;
  size_t size;
  size_t cap;
} DumpBuf;

static int andlua_dump_writer (lua_State *L, const void *p, size_t sz, void *ud) {
  DumpBuf *db = (DumpBuf *)ud;
  (void)L;
  if (db->size + sz > db->cap) {
    size_t ncap = db->cap ? db->cap * 2 : 1024;
    unsigned char *nd;
    while (ncap < db->size + sz) ncap *= 2;
    nd = (unsigned char *)realloc(db->data, ncap);
    if (!nd) return 1;
    db->data = nd; db->cap = ncap;
  }
  memcpy(db->data + db->size, p, sz);
  db->size += sz;
  return 0;
}

/* str_dump(function, strip?) -> base64-encoded andlua encrypted bytecode */
LUALIB_API int luaL_strdump (lua_State *L) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_strdump");
      luacapi_log_state("L", L);
      luacapi_log_end();
}
  int strip = lua_toboolean(L, 2);
  DumpBuf db;
  unsigned char *deflated = NULL;
  char *b64 = NULL;
  size_t dlen, blen;
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_settop(L, 1);
  db.data = NULL; db.size = 0; db.cap = 0;
  if (lua_dump(L, andlua_dump_writer, &db, strip) != 0)
    luaL_error(L, "unable to dump given function");
  if (db.size == 0) {
    free(db.data);
    lua_pushlstring(L, "", 0);
    return 1;
  }
  db.data[0] = 0x1C;  /* andlua marker before deflate */
  deflated = andlua_deflate(db.data, db.size, &dlen);
  free(db.data);
  if (!deflated || dlen == 0) {
    free(deflated);
    luaL_error(L, "dump error");
  }
  deflated[0] = 0x1C;  /* andlua marker after deflate */
  andlua_xor_encrypt(deflated, dlen);
  deflated[0] = 0x1C;
  b64 = andlua_b64encode(deflated, dlen, &blen);
  free(deflated);
  if (!b64) luaL_error(L, "dump error");
  b64[0] = '=';  /* andlua base64 shell marker */
  lua_pushlstring(L, b64, blen);
  free(b64);
  return 1;
}

/* }====================================================== */


typedef struct LoadS {
  const char *s;
  size_t size;
} LoadS;


static const char *getS (lua_State *L, void *ud, size_t *size) {
  LoadS *ls = (LoadS *)ud;
  (void)L;  /* not used */
  if (ls->size == 0) return NULL;
  *size = ls->size;
  ls->size = 0;
  return ls->s;
}


LUALIB_API int luaL_loadbufferx (lua_State *L, const char *buff, size_t size,
                                 const char *name, const char *mode) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_loadbufferx");
      luacapi_log_state("L", L);
      luacapi_log_strn("buff", buff, (size_t)(size));
      luacapi_log_uint("size", (unsigned long long)(size));
      luacapi_log_str("name", name);
      luacapi_log_str("mode", mode);
      luacapi_log_end();
}
  LoadS ls;
  unsigned char *b64out = NULL;
  unsigned char *xored = NULL;
  unsigned char *inflated = NULL;
  int status;
  unsigned char first;

  if (size == 0) {
    ls.s = buff; ls.size = size;
    return lua_load(L, getS, &ls, name, mode);
  }
  first = (unsigned char)buff[0];

  /* '=' prefix: base64-encoded andlua shell (XOR-CBC + zlib) */
  if (first == '=') {
    size_t dlen, ilen;
    size_t i;
    b64out = andlua_b64decode(buff, size, &dlen);
    if (!b64out || dlen == 0) {
      free(b64out);
      ls.s = buff; ls.size = size;
      return lua_load(L, getS, &ls, name, mode);
    }
    if (b64out[0] != 0x1C) {
      /* base64 but not andlua-encrypted: load raw */
      ls.s = (const char *)b64out; ls.size = dlen;
      status = lua_load(L, getS, &ls, name, mode);
      free(b64out);
      return status;
    }
    /* XOR-CBC is self-inverse: forward pass data[i] ^= data[i-1] */
    for (i = 1; i < dlen; i++) {
      b64out[i] ^= b64out[i - 1];
    }
    b64out[0] = 0x78;  /* restore zlib header */
    inflated = andlua_inflate(b64out, dlen, &ilen);
    free(b64out);
    if (!inflated || ilen == 0) {
      free(inflated);
      ls.s = buff; ls.size = size;
      return lua_load(L, getS, &ls, name, mode);
    }
    inflated[0] = 0x1C;  /* andlua encrypted bytecode marker */
    ls.s = (const char *)inflated; ls.size = ilen;
    status = lua_load(L, getS, &ls, name, mode);
    free(inflated);
    return status;
  }

  /* 0x1B but not "Lua": andlua XOR-scrambled standard bytecode */
  if (first == 0x1B && size >= 2 && (unsigned char)buff[1] != 'L') {
    size_t i;
    xored = (unsigned char *)malloc(size);
    if (!xored) {
      free(b64out);
      ls.s = buff; ls.size = size;
      return lua_load(L, getS, &ls, name, mode);
    }
    memcpy(xored, buff, size);
    for (i = 1; i < size; i++) {
      unsigned int x = (unsigned int)(i * size);
      unsigned int key = x + (x * 3) / 256;
      xored[i] ^= (unsigned char)(key & 0xFF);
    }
    ls.s = (const char *)xored; ls.size = size;
    status = lua_load(L, getS, &ls, name, mode);
    free(xored); free(b64out);
    return status;
  }

  /* 0x1C: andlua encrypted bytecode (XOR-CBC + zlib) */
  if (first == 0x1C) {
    size_t ilen;
    xored = (unsigned char *)malloc(size);
    if (!xored) {
      free(b64out);
      ls.s = buff; ls.size = size;
      return lua_load(L, getS, &ls, name, mode);
    }
    memcpy(xored, buff, size);
    andlua_xor_decrypt(xored, size);
    xored[0] = 0x78;  /* zlib header 'x' */
    inflated = andlua_inflate(xored, size, &ilen);
    free(xored);
    if (!inflated || ilen == 0) {
      free(inflated); free(b64out);
      ls.s = buff; ls.size = size;
      return lua_load(L, getS, &ls, name, mode);
    }
    inflated[0] = 0x1C;  /* andlua encrypted bytecode marker */
    ls.s = (const char *)inflated; ls.size = ilen;
    status = lua_load(L, getS, &ls, name, mode);
    free(inflated); free(b64out);
    return status;
  }

  /* standard path */
  ls.s = buff; ls.size = size;
  return lua_load(L, getS, &ls, name, mode);
}


/*
** andlua: decrypt '=' shell to 0x1C bytecode.
** Returns malloc'd buffer (caller must free), or NULL on failure.
*/
LUALIB_API unsigned char *luaL_andlua_dec (const char *buff, size_t size,
                                            size_t *outlen) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_andlua_dec");
      luacapi_log_strn("buff", buff, (size_t)(size));
      luacapi_log_uint("size", (unsigned long long)(size));
      luacapi_log_ptr("outlen", (const void *)(outlen));
      luacapi_log_end();
}
  unsigned char *b64out;
  unsigned char *inflated;
  size_t dlen, ilen;
  size_t i;

  if (size == 0 || buff[0] != '=') {
    *outlen = 0;
    return NULL;
  }
  b64out = andlua_b64decode(buff, size, &dlen);
  if (!b64out || dlen == 0 || b64out[0] != 0x1C) {
    free(b64out);
    *outlen = 0;
    return NULL;
  }
  /* XOR-CBC self-inverse */
  for (i = 1; i < dlen; i++)
    b64out[i] ^= b64out[i - 1];
  b64out[0] = 0x78;  /* restore zlib header */
  inflated = andlua_inflate(b64out, dlen, &ilen);
  free(b64out);
  if (!inflated || ilen == 0) {
    free(inflated);
    *outlen = 0;
    return NULL;
  }
  inflated[0] = 0x1A;  /* andlua encrypted marker; undump2 decrypts strings */
  *outlen = ilen;
  return inflated;
}


LUALIB_API int luaL_loadstring (lua_State *L, const char *s) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_loadstring");
      luacapi_log_state("L", L);
      luacapi_log_str("s", s);
      luacapi_log_end();
}
  return luaL_loadbuffer(L, s, strlen(s), s);
}

/* }====================================================== */



LUALIB_API int luaL_getmetafield (lua_State *L, int obj, const char *event) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_getmetafield");
      luacapi_log_state("L", L);
      luacapi_log_int("obj", (long long)(obj));
      luacapi_log_str("event", event);
      luacapi_log_end();
}
  if (!lua_getmetatable(L, obj))  /* no metatable? */
    return LUA_TNIL;
  else {
    int tt;
    lua_pushstring(L, event);
    tt = lua_rawget(L, -2);
    if (tt == LUA_TNIL)  /* is metafield nil? */
      lua_pop(L, 2);  /* remove metatable and metafield */
    else
      lua_remove(L, -2);  /* remove only metatable */
    return tt;  /* return metafield type */
  }
}


LUALIB_API int luaL_callmeta (lua_State *L, int obj, const char *event) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_callmeta");
      luacapi_log_state("L", L);
      luacapi_log_int("obj", (long long)(obj));
      luacapi_log_str("event", event);
      luacapi_log_end();
}
  obj = lua_absindex(L, obj);
  if (luaL_getmetafield(L, obj, event) == LUA_TNIL)  /* no metafield? */
    return 0;
  lua_pushvalue(L, obj);
  lua_call(L, 1, 1);
  return 1;
}


LUALIB_API lua_Integer luaL_len (lua_State *L, int idx) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_len");
      luacapi_log_state("L", L);
      luacapi_log_int("idx", (long long)(idx));
      luacapi_log_end();
}
  lua_Integer l;
  int isnum;
  lua_len(L, idx);
  l = lua_tointegerx(L, -1, &isnum);
  if (!isnum)
    luaL_error(L, "object length is not an integer");
  lua_pop(L, 1);  /* remove object */
  return l;
}


LUALIB_API const char *luaL_tolstring (lua_State *L, int idx, size_t *len) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_tolstring");
      luacapi_log_state("L", L);
      luacapi_log_int("idx", (long long)(idx));
      luacapi_log_ptr("len", (const void *)(len));
      luacapi_log_end();
}
  if (!luaL_callmeta(L, idx, "__tostring")) {  /* no metafield? */
    switch (lua_type(L, idx)) {
      case LUA_TNUMBER: {
        if (lua_isinteger(L, idx))
          lua_pushfstring(L, "%I", lua_tointeger(L, idx));
        else
          lua_pushfstring(L, "%f", lua_tonumber(L, idx));
        break;
      }
      case LUA_TSTRING:
        lua_pushvalue(L, idx);
        break;
      case LUA_TBOOLEAN:
        lua_pushstring(L, (lua_toboolean(L, idx) ? "true" : "false"));
        break;
      case LUA_TNIL:
        lua_pushliteral(L, "nil");
        break;
      default:
        lua_pushfstring(L, "%s: %p", luaL_typename(L, idx),
                                            lua_topointer(L, idx));
        break;
    }
  }
  return lua_tolstring(L, -1, len);
}


/*
** {======================================================
** Compatibility with 5.1 module functions
** =======================================================
*/
#if defined(LUA_COMPAT_MODULE)
//mod by nirenr
LUALIB_API int luaL_typerror (lua_State *L, int narg, const char *tname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_typerror");
      luacapi_log_state("L", L);
      luacapi_log_int("narg", (long long)(narg));
      luacapi_log_str("tname", tname);
      luacapi_log_end();
}
    return typeerror(L, narg, tname);
}

LUALIB_API const char *luaL_findtable (lua_State *L, int idx,
                                   const char *fname, int szhint) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_findtable");
      luacapi_log_state("L", L);
      luacapi_log_int("idx", (long long)(idx));
      luacapi_log_str("fname", fname);
      luacapi_log_int("szhint", (long long)(szhint));
      luacapi_log_end();
}
  const char *e;
  if (idx) lua_pushvalue(L, idx);
  do {
    e = strchr(fname, '.');
    if (e == NULL) e = fname + strlen(fname);
    lua_pushlstring(L, fname, e - fname);
    if (lua_rawget(L, -2) == LUA_TNIL) {  /* no such field? */
      lua_pop(L, 1);  /* remove this nil */
      lua_createtable(L, 0, (*e == '.' ? 1 : szhint)); /* new table for field */
      lua_pushlstring(L, fname, e - fname);
      lua_pushvalue(L, -2);
      lua_settable(L, -4);  /* set new table into field */
    }
    else if (!lua_istable(L, -1)) {  /* field has a non-table value? */
      lua_pop(L, 2);  /* remove table and value */
      return fname;  /* return problematic part of the name */
    }
    lua_remove(L, -2);  /* remove previous table */
    fname = e + 1;
  } while (*e == '.');
  return NULL;
}


/*
** Count number of elements in a luaL_Reg list.
*/
static int libsize (const luaL_Reg *l) {
  int size = 0;
  for (; l && l->name; l++) size++;
  return size;
}


/*
** Find or create a module table with a given name. The function
** first looks at the _LOADED table and, if that fails, try a
** global variable with that name. In any case, leaves on the stack
** the module table.
*/
//mod by nirenr
LUALIB_API void luaL_pushmodule (lua_State *L, const char *modname,
                                 int sizehint) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_pushmodule");
      luacapi_log_state("L", L);
      luacapi_log_str("modname", modname);
      luacapi_log_int("sizehint", (long long)(sizehint));
      luacapi_log_end();
}
  luaL_findtable(L, LUA_REGISTRYINDEX, "_LOADED", 1);  /* get _LOADED table */
  if (lua_getfield(L, -1, modname) != LUA_TTABLE) {  /* no _LOADED[modname]? */
    lua_pop(L, 1);  /* remove previous result */
    /* try global variable (and create one if it does not exist) */
    /*lua_pushglobaltable(L);
    if (luaL_findtable(L, 0, modname, sizehint) != NULL)
      luaL_error(L, "name conflict for module '%s'", modname);*/
	lua_newtable(L);
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, modname);  /* _LOADED[modname] = new table */
  }
  lua_remove(L, -2);  /* remove _LOADED table */
}


LUALIB_API void luaL_openlib (lua_State *L, const char *libname,
                               const luaL_Reg *l, int nup) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_openlib");
      luacapi_log_state("L", L);
      luacapi_log_str("libname", libname);
      luacapi_log_ptr("l", (const void *)(l));
      luacapi_log_int("nup", (long long)(nup));
      luacapi_log_end();
}
  luaL_checkversion(L);
  if (libname) {
    luaL_pushmodule(L, libname, libsize(l));  /* get/create library table */
    lua_insert(L, -(nup + 1));  /* move library table to below upvalues */
  }
  if (l)
    luaL_setfuncs(L, l, nup);
  else
    lua_pop(L, nup);  /* remove upvalues */
}

#endif
/* }====================================================== */

/*
** set functions from list 'l' into table at top - 'nup'; each
** function gets the 'nup' elements at the top as upvalues.
** Returns with only the table at the stack.
*/
LUALIB_API void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_setfuncs");
      luacapi_log_state("L", L);
      luacapi_log_ptr("l", (const void *)(l));
      luacapi_log_int("nup", (long long)(nup));
      luacapi_log_end();
}
  luaL_checkstack(L, nup, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_setfield(L, -(nup + 2), l->name);
  }
  lua_pop(L, nup);  /* remove upvalues */
}


/*
** ensure that stack[idx][fname] has a table and push that table
** into the stack
*/
LUALIB_API int luaL_getsubtable (lua_State *L, int idx, const char *fname) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_getsubtable");
      luacapi_log_state("L", L);
      luacapi_log_int("idx", (long long)(idx));
      luacapi_log_str("fname", fname);
      luacapi_log_end();
}
  if (lua_getfield(L, idx, fname) == LUA_TTABLE)
    return 1;  /* table already there */
  else {
    lua_pop(L, 1);  /* remove previous result */
    idx = lua_absindex(L, idx);
    lua_newtable(L);
    lua_pushvalue(L, -1);  /* copy to be left at top */
    lua_setfield(L, idx, fname);  /* assign new table to field */
    return 0;  /* false, because did not find table there */
  }
}


/*
** Stripped-down 'require': After checking "loaded" table, calls 'openf'
** to open a module, registers the result in 'package.loaded' table and,
** if 'glb' is true, also registers the result in the global table.
** Leaves resulting module on the top.
*/
LUALIB_API void luaL_requiref (lua_State *L, const char *modname,
                               lua_CFunction openf, int glb) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_requiref");
      luacapi_log_state("L", L);
      luacapi_log_str("modname", modname);
      luacapi_log_ptr("openf", (const void *)(openf));
      luacapi_log_int("glb", (long long)(glb));
      luacapi_log_end();
}
  luaL_getsubtable(L, LUA_REGISTRYINDEX, "_LOADED");
  lua_getfield(L, -1, modname);  /* _LOADED[modname] */
  if (!lua_toboolean(L, -1)) {  /* package not already loaded? */
    lua_pop(L, 1);  /* remove field */
    lua_pushcfunction(L, openf);
    lua_pushstring(L, modname);  /* argument to open function */
    lua_call(L, 1, 1);  /* call 'openf' to open module */
    lua_pushvalue(L, -1);  /* make copy of module (call result) */
    lua_setfield(L, -3, modname);  /* _LOADED[modname] = module */
  }
  lua_remove(L, -2);  /* remove _LOADED table */
  if (glb) {
    lua_pushvalue(L, -1);  /* copy of module */
    lua_setglobal(L, modname);  /* _G[modname] = module */
  }
}


LUALIB_API const char *luaL_gsub (lua_State *L, const char *s, const char *p,
                                                               const char *r) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_gsub");
      luacapi_log_state("L", L);
      luacapi_log_str("s", s);
      luacapi_log_str("p", p);
      luacapi_log_str("r", r);
      luacapi_log_end();
}
  const char *wild;
  size_t l = strlen(p);
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  while ((wild = strstr(s, p)) != NULL) {
    luaL_addlstring(&b, s, wild - s);  /* push prefix */
    luaL_addstring(&b, r);  /* push replacement in place of pattern */
    s = wild + l;  /* continue after 'p' */
  }
  luaL_addstring(&b, s);  /* push last suffix */
  luaL_pushresult(&b);
  return lua_tostring(L, -1);
}


static void *l_alloc (void *ud, void *ptr, size_t osize, size_t nsize) {
  (void)ud; (void)osize;  /* not used */
  if (nsize == 0) {
    free(ptr);
    return NULL;
  }
  else
    return realloc(ptr, nsize);
}


static int panic (lua_State *L) {
  lua_writestringerror("PANIC: unprotected error in call to Lua API (%s)\n",
                        lua_tostring(L, -1));
  return 0;  /* return to Lua to abort */
}


LUALIB_API lua_State *luaL_newstate (void) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_newstate");
      luacapi_log_end();
}
  lua_State *L = lua_newstate(l_alloc, NULL);
  if (L) lua_atpanic(L, &panic);
  return L;
}


LUALIB_API void luaL_checkversion_ (lua_State *L, lua_Number ver, size_t sz) {
{ /* LUACAPI_LOG */
      luacapi_log_begin("lauxlib", "luaL_checkversion_");
      luacapi_log_state("L", L);
      luacapi_log_num("ver", (double)(ver));
      luacapi_log_uint("sz", (unsigned long long)(sz));
      luacapi_log_end();
}
  const lua_Number *v = lua_version(L);
  if (sz != LUAL_NUMSIZES)  /* check numeric types */
    luaL_error(L, "core and library have incompatible numeric types");
  if (v != lua_version(NULL))
    luaL_error(L, "multiple Lua VMs detected");
  else if (*v != ver)
    luaL_error(L, "version mismatch: app. needs %f, Lua core provides %f",
                  ver, *v);
}

