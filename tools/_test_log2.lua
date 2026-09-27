local log = require("log")
log.set_dir("tools/_lua_logout")
log.set_enabled(true)
log.log("=== test start ===")
log.set_fn("lua_getglobal", false)   -- 单独关掉 lua_getglobal
print("hello")                       -- GETGLOBAL print 走 lua_getglobal
log.set_fn("lua_getglobal", true)    -- 重新打开
log.set_group("lvm", false)          -- 关 lvm 组（luaV_* 入口）
local function add(a, b) return a + b end
print(add(3, 4))                     -- add 是 Lua 函数，走 luaV_execute
log.set_group("lvm", true)
log.log("=== test end ===")
log.close()
print("script done")
