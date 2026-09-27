local log = require("log")
log.set_dir("tools/_lua_logout")
log.log("minimal")
local function f(x) return x * 2 end
print(f(21))
log.close()
