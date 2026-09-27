#include "luacapi_log.h"
const char *luac_funcnamefromcode (struct lua_State *L, struct CallInfo *ci,
                                   const char **name) {
  (void)L; (void)ci;
  if (name) *name = NULL;
  return NULL;
}
