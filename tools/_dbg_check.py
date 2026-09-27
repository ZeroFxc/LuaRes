# -*- coding: utf-8 -*-
for f in ["lapi.c", "ldo.c", "lstate.c", "ldebug.c", "lauxlib.c", "linit.c"]:
    t = open(r"E:\LuaRes\luasafe\\" + f, encoding="utf-8", errors="replace").read()
    has_inc = '#include "luacapi_log.h"' in t
    cnt = t.count("LUACAPI_LOG")
    print("%-10s include=%s blocks=%d" % (f, has_inc, cnt))
