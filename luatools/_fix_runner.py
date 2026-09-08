p = r'E:\LuaRes\luatools\single_step_runner.lua'
s = open(p, encoding='utf-8').read()

# 1. Add environment field to VM.new
old_init = """  local self = setmetatable({
    proto = proto,
    pc = 1,  -- 1-based index into code array
    regs = {},  -- registers (1-based, R0=regs[1])
    stack = {},  -- Lua stack for function calls
    top = 0,
    constants = {},  -- resolved constants
    protos = {},  -- sub-protos (resolved closures)
    upvalues = {},  -- upvalue storage
    output = {},  -- captured print output
    trace = {},  -- execution trace
    running = false,
    steps = 0,
    max_steps = 1000000,  -- safety limit
    call_stack = {},  -- call stack for nested functions
  }, VM)"""

new_init = """  local env = {print = print, tostring = tostring, pairs = pairs, ipairs = ipairs,
    type = type, error = error, pcall = pcall, select = select, math = math,
    string = string, table = table, tonumber = tonumber, _VERSION = _VERSION}
  local self = setmetatable({
    proto = proto,
    pc = 1,  -- 1-based index into code array
    regs = {},  -- registers (1-based, R0=regs[1])
    stack = {},  -- Lua stack for function calls
    top = 0,
    constants = {},  -- resolved constants
    protos = {},  -- sub-protos (resolved closures)
    upvalues = {env},  -- upvalue storage (upvalue 0 is _ENV)
    env = env,  -- global environment
    output = {},  -- captured print output
    trace = {},  -- execution trace
    running = false,
    steps = 0,
    max_steps = 1000000,  -- safety limit
    call_stack = {},  -- call stack for nested functions
  }, VM)"""

s = s.replace(old_init, new_init, 1)

# 2. Add GETUPVAL and GETTABUP handling in step()
# Find the MOVE handling and add after it
old_move = """  if op == 0 then  -- MOVE
    self:set_reg(a, self:get_reg(b))
  elseif op == 1 then  -- LOADK"""

new_move = """  if op == 0 then  -- MOVE
    self:set_reg(a, self:get_reg(b))
  elseif op == 5 then  -- GETUPVAL
    self:set_reg(a, self.upvalues[b + 1])  -- upvalue index b (0-based)
  elseif op == 6 then  -- GETTABUP: R(A) = Upval(B)[RK(C)] (usually _ENV[k])
    local upval = self.upvalues[b + 1]
    local key = self:rk(c)
    if type(upval) == "table" then
      self:set_reg(a, upval[key])
    else
      self:set_reg(a, nil)
    end
  elseif op == 8 then  -- SETTABUP: Upval(B)[RK(C)] = R(A)
    local upval = self.upvalues[b + 1]
    local key = self:rk(c)
    if type(upval) == "table" then
      upval[key] = self:get_reg(a)
    end
  elseif op == 9 then  -- SETUPVAL
    self.upvalues[b + 1] = self:get_reg(a)
  elseif op == 10 then  -- SETTABLE: R(A)[RK(B)] = RK(C)
    local tbl = self:get_reg(a)
    local key = self:rk(b)
    local val = self:rk(c)
    if type(tbl) == "table" then
      tbl[key] = val
    end
  elseif op == 7 then  -- GETTABLE: R(A) = R(B)[RK(C)]
    local tbl = self:get_reg(b)
    local key = self:rk(c)
    if type(tbl) == "table" then
      self:set_reg(a, tbl[key])
    else
      self:set_reg(a, nil)
    end
  elseif op == 1 then  -- LOADK"""

s = s.replace(old_move, new_move, 1)

# 3. Fix new_from_proto to inherit environment
old_newfrom = """  local self = setmetatable({
    proto = proto,
    pc = 1,
    regs = {},
    stack = {},
    top = 0,
    constants = {},
    protos = {},
    upvalues = {},
    output = parent and parent.output or {},
    trace = {},
    running = true,
    steps = 0,
    max_steps = 1000000,
    parent = parent,
  }, VM)"""

new_newfrom = """  local self = setmetatable({
    proto = proto,
    pc = 1,
    regs = {},
    stack = {},
    top = 0,
    constants = {},
    protos = {},
    upvalues = parent and parent.upvalues or {},
    env = parent and parent.env or {},
    output = parent and parent.output or {},
    trace = {},
    running = true,
    steps = 0,
    max_steps = 1000000,
    parent = parent,
  }, VM)"""

s = s.replace(old_newfrom, new_newfrom, 1)

open(p, 'w', encoding='utf-8').write(s)
print('Fixed GETTABUP/GETUPVAL and environment')
