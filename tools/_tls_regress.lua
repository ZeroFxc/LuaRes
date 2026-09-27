-- TLS 改造后单线程回归：确认 lua 侧正常出日志
local log = require("log")
log.set_file("tools\\_tls_regress.log")
local sum = 0
for i = 1, 100 do sum = sum + i end
local t = { "a", "b" }
print("sum=" .. sum .. " len=" .. #t)
log.close()
