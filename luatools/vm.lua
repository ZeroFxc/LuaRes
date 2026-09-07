--[[
  vm.lua - Pure Lua 5.3 bytecode VM (register-based)
  Loads custom table-format chunks produced by vm_pack module.

  chunk format:
  {
    num_params, is_vararg, maxstacksize,
    code = { {op, a, b, c, bx, sbx}, ... },  -- 1-based, pre-decoded
    k = { {t, v}, ... },  -- t: "n"=nil, "b"=bool, "i"=int, "f"=flt, "s"=str
    p = { chunk, ... },
    upvalues = { {instack, idx}, ... },
  }
]]

local VM = {}

-- opcode names (0-based)
local OP = {
  MOVE=0, LOADK=1, LOADKX=2, LOADBOOL=3, LOADNIL=4,
  GETUPVAL=5, GETTABUP=6, GETTABLE=7,
  SETTABUP=8, SETUPVAL=9, SETTABLE=10,
  NEWTABLE=11, SELF=12,
  ADD=13, SUB=14, MUL=15, MOD=16, POW=17, DIV=18, IDIV=19,
  BAND=20, BOR=21, BXOR=22, SHL=23, SHR=24,
  UNM=25, BNOT=26, NOT=27, LEN=28, CONCAT=29,
  JMP=30, EQ=31, LT=32, LE=33,
  TEST=34, TESTSET=35,
  CALL=36, TAILCALL=37, RETURN=38,
  FORLOOP=39, FORPREP=40, TFORCALL=41, TFORLOOP=42,
  SETLIST=43, CLOSURE=44, VARARG=45, EXTRAARG=46,
  -- andlua extensions (minimal support)
  TBC=47, NEWARRAY=48, TFOREACH=49, SECTION=50, IS=51, TRY=52, TRYRETURN=53,
}

local BITRK = 0x100

-- helper: RK value
local function rk(frame, x)
  if x < BITRK then return frame.reg[x] end
  return frame.k[x - BITRK + 1]  -- k is 1-based
end

-- arithmetic with metamethod support
local function arith(frame, op, b, c)
  local lb = rk(frame, b)
  local lc = rk(frame, c)
  if op == OP.ADD then return lb + lc
  elseif op == OP.SUB then return lb - lc
  elseif op == OP.MUL then return lb * lc
  elseif op == OP.MOD then return lb % lc
  elseif op == OP.POW then return lb ^ lc
  elseif op == OP.DIV then return lb / lc
  elseif op == OP.IDIV then return lb // lc
  elseif op == OP.BAND then return lb & lc
  elseif op == OP.BOR then return lb | lc
  elseif op == OP.BXOR then return lb ~ lc
  elseif op == OP.SHL then return lb << lc
  elseif op == OP.SHR then return lb >> lc
  end
end

local function concat(frame, b, c)
  local parts = {}
  for i = b, c do
    parts[#parts+1] = tostring(frame.reg[i])
  end
  return table.concat(parts)
end

-- comparison
local function compare(op, b, c)
  if op == OP.EQ then return b == c
  elseif op == OP.LT then return b < c
  elseif op == OP.LE then return b <= c
  end
end

-- length
local function vlen(v)
  if type(v) == "string" then return #v end
  if type(v) == "table" then return #v end
  local mt = getmetatable(v)
  if mt and mt.__len then return mt.__len(v) end
  error("attempt to get length of a " .. type(v) .. " value")
end

-- create a closure from proto
local function make_closure(proto, upvals)
  return {
    proto = proto,
    upvals = upvals or {},
    is_vararg = proto.is_vararg,
    num_params = proto.num_params,
  }
end

-- compile chunk table into executable closure factory
local function compile_chunk(chunk, env)
  -- pre-convert constants
  local k = {}
  for i, kc in ipairs(chunk.k) do
    local t, v = kc.t, kc.v
    if t == "n" then k[i] = nil
    elseif t == "b" then k[i] = v
    elseif t == "i" then k[i] = math.tointeger(v) or v
    elseif t == "f" then k[i] = v + 0.0
    elseif t == "s" then k[i] = v
    end
  end

  -- compile sub-protos
  local sub_protos = {}
  for i, sp in ipairs(chunk.p) do
    sub_protos[i] = compile_chunk(sp, env)
  end

  -- return a factory that creates a closure with given upvalues
  return function(upvals)
    return make_closure({
      code = chunk.code,
      k = k,
      p = sub_protos,
      upvalues = chunk.upvalues,
      num_params = chunk.num_params,
      is_vararg = chunk.is_vararg,
      maxstacksize = chunk.maxstacksize,
    }, upvals)
  end
end

-- execute a closure with given arguments
local function execute(closure, ...)
  local proto = closure.proto
  local args = {...}

  -- build call frame
  local frame = {
    reg = {},
    k = proto.k,
    code = proto.code,
    p = proto.p,
    upvals = closure.upvals,
    pc = 1,  -- 1-based
    top = 0,
    vararg = {},
    closed_upvals = {},  -- for closed upvalues
  }

  -- initialize parameters
  local nparams = proto.num_params
  for i = 1, nparams do
    frame.reg[i-1] = args[i]  -- 0-based registers
  end
  -- varargs
  if proto.is_vararg and #args > nparams then
    for i = nparams+1, #args do
      frame.vararg[#frame.vararg+1] = args[i]
    end
  end
  frame.top = proto.maxstacksize

  -- ensure _ENV upvalue exists for main chunk
  if #closure.upvals == 0 and proto.num_params == 0 then
    -- main chunk: first upvalue is _ENV
    frame.upvals[0] = {kind="closed", val=_ENV or _G}
  end

  local function get_upval(idx)
    local uv = frame.upvals[idx]
    if not uv then return nil end
    if uv.kind == "open" then
      return frame.reg[uv.idx]
    else
      return uv.val
    end
  end

  local function set_upval(idx, val)
    local uv = frame.upvals[idx]
    if not uv then
      uv = {kind="closed", val=val}
      frame.upvals[idx] = uv
      return
    end
    if uv.kind == "open" then
      frame.reg[uv.idx] = val
    else
      uv.val = val
    end
  end

  -- close upvalues >= level
  local function close_upvals(level)
    for idx, uv in pairs(frame.upvals) do
      if uv.kind == "open" and uv.idx >= level then
        uv.kind = "closed"
        uv.val = frame.reg[uv.idx]
      end
    end
  end

  -- main loop
  while true do
    local ins = frame.code[frame.pc]
    if not ins then break end
    local op = ins[1]
    local a = ins[2]
    local b = ins[3]
    local c = ins[4]

    if op == OP.MOVE then
      frame.reg[a] = frame.reg[b]

    elseif op == OP.LOADK then
      frame.reg[a] = frame.k[b + 1]

    elseif op == OP.LOADKX then
      -- next instruction is EXTRAARG with Ax
      local extra = frame.code[frame.pc + 1]
      frame.reg[a] = frame.k[extra[2] + 1]  -- Ax in a field
      frame.pc = frame.pc + 1

    elseif op == OP.LOADBOOL then
      frame.reg[a] = (b ~= 0)
      if c ~= 0 then frame.pc = frame.pc + 1 end

    elseif op == OP.LOADNIL then
      for i = a, a + b do
        frame.reg[i] = nil
      end

    elseif op == OP.GETUPVAL then
      frame.reg[a] = get_upval(b)

    elseif op == OP.GETTABUP then
      local tbl = get_upval(b)
      frame.reg[a] = tbl[rk(frame, c)]

    elseif op == OP.GETTABLE then
      frame.reg[a] = frame.reg[b][rk(frame, c)]

    elseif op == OP.SETTABUP then
      local tbl = get_upval(a)
      tbl[rk(frame, b)] = rk(frame, c)

    elseif op == OP.SETUPVAL then
      set_upval(b, frame.reg[a])

    elseif op == OP.SETTABLE then
      frame.reg[a][rk(frame, b)] = rk(frame, c)

    elseif op == OP.NEWTABLE then
      frame.reg[a] = {}

    elseif op == OP.SELF then
      frame.reg[a+1] = frame.reg[b]
      frame.reg[a] = frame.reg[b][rk(frame, c)]

    elseif op >= OP.ADD and op <= OP.SHR then
      frame.reg[a] = arith(frame, op, b, c)

    elseif op == OP.UNM then
      frame.reg[a] = -frame.reg[b]

    elseif op == OP.BNOT then
      frame.reg[a] = ~frame.reg[b]

    elseif op == OP.NOT then
      frame.reg[a] = not frame.reg[b]

    elseif op == OP.LEN then
      frame.reg[a] = vlen(frame.reg[b])

    elseif op == OP.CONCAT then
      frame.reg[a] = concat(frame, b, c)

    elseif op == OP.JMP then
      if a ~= 0 then
        close_upvals(a - 1)
      end
      frame.pc = frame.pc + ins[6]  -- sbx

    elseif op == OP.EQ or op == OP.LT or op == OP.LE then
      if (compare(op, rk(frame, b), rk(frame, c)) ~= (a ~= 0)) then
        frame.pc = frame.pc + 1
      end

    elseif op == OP.TEST then
      -- this modified Lua: TEST A,C: if (C ? isfalse(R(A)) : !isfalse(R(A))) then skip next
      local ra = frame.reg[a]
      local isfalse = (ra == nil or ra == false)
      local cond
      if c ~= 0 then cond = isfalse else cond = not isfalse end
      if cond then frame.pc = frame.pc + 1 end

    elseif op == OP.TESTSET then
      local rb = frame.reg[b]
      local isfalse = (rb == nil or rb == false)
      local cond
      if c ~= 0 then cond = isfalse else cond = not isfalse end
      if cond then
        frame.reg[a] = rb
      else
        frame.pc = frame.pc + 1
      end

    elseif op == OP.CALL then
      local func = frame.reg[a]
      local nargs
      if b == 0 then
        nargs = frame.top - a - 1
      else
        nargs = b - 1
      end
      local call_args = {}
      for i = 1, nargs do
        call_args[i] = frame.reg[a + i]
      end
      local results
      if type(func) == "table" and func.proto then
        -- VM closure
        results = {execute(func, table.unpack(call_args))}
      else
        results = {func(table.unpack(call_args))}
      end
      local nret
      if c == 0 then
        nret = #results
        frame.top = a + nret
      else
        nret = c - 1
      end
      for i = 1, nret do
        frame.reg[a + i - 1] = results[i]
      end
      for i = nret + 1, frame.top - a do
        frame.reg[a + i - 1] = nil
      end

    elseif op == OP.TAILCALL then
      local func = frame.reg[a]
      local nargs
      if b == 0 then
        nargs = frame.top - a - 1
      else
        nargs = b - 1
      end
      local call_args = {}
      for i = 1, nargs do
        call_args[i] = frame.reg[a + i]
      end
      if type(func) == "table" and func.proto then
        return execute(func, table.unpack(call_args))
      else
        return func(table.unpack(call_args))
      end

    elseif op == OP.RETURN then
      local nret
      if b == 0 then
        nret = frame.top - a
      else
        nret = b - 1
      end
      close_upvals(0)
      local rets = {}
      for i = 1, nret do
        rets[i] = frame.reg[a + i - 1]
      end
      return table.unpack(rets)

    elseif op == OP.FORLOOP then
      local step = frame.reg[a+2]
      local idx = frame.reg[a] + step
      local limit = frame.reg[a+1]
      frame.reg[a] = idx
      if (step >= 0 and idx <= limit) or (step < 0 and idx >= limit) then
        frame.reg[a+3] = idx
        frame.pc = frame.pc + ins[6]  -- sbx (backward)
      end

    elseif op == OP.FORPREP then
      local step = frame.reg[a+2]
      frame.reg[a] = frame.reg[a] - step
      frame.pc = frame.pc + ins[6]  -- sbx (forward to FORLOOP)

    elseif op == OP.TFORCALL then
      local f = frame.reg[a]
      local s = frame.reg[a+1]
      local var = frame.reg[a+2]
      local results = {f(s, var)}
      for i = 1, c do
        frame.reg[a+2+i] = results[i]
      end

    elseif op == OP.TFORLOOP then
      if frame.reg[a+1] ~= nil then
        frame.reg[a] = frame.reg[a+1]
        frame.pc = frame.pc + ins[6]
      end

    elseif op == OP.SETLIST then
      local tbl = frame.reg[a]
      local nelem
      if b == 0 then nelem = frame.top - a - 1 else nelem = b end
      local fpf = 50  -- LFIELDS_PER_FLUSH
      local start
      if c == 0 then
        -- next instruction is EXTRAARG
        local extra = frame.code[frame.pc + 1]
        start = (extra[2] - 1) * fpf
        frame.pc = frame.pc + 1
      else
        start = (c - 1) * fpf
      end
      for i = 1, nelem do
        tbl[start + i] = frame.reg[a + i]
      end

    elseif op == OP.CLOSURE then
      local sub_factory = frame.p[b + 1]
      local upvals = {}
      local uv_defs = proto.upvalues or {}
      for i = 0, #uv_defs - 1 do
        local uv = uv_defs[i+1]
        if uv.instack ~= 0 then
          upvals[i] = {kind="open", idx=uv.idx}
        else
          upvals[i] = {kind="closed", val=get_upval(uv.idx)}
        end
      end
      frame.reg[a] = sub_factory(upvals)

    elseif op == OP.VARARG then
      local n
      if b == 0 then
        n = #frame.vararg
        frame.top = a + n
      else
        n = b - 1
      end
      for i = 1, n do
        frame.reg[a + i - 1] = frame.vararg[i]
      end

    elseif op == OP.EXTRAARG then
      -- handled by LOADKX/SETLIST, skip if encountered standalone
      -- do nothing

    -- andlua extensions: minimal no-op or simple handling
    elseif op == OP.TBC then
      -- to-be-closed: mark for close at scope exit (simplified: no-op)
    elseif op == OP.NEWARRAY then
      frame.reg[a] = {}
    elseif op == OP.TFOREACH then
      -- andlua table foreach: simplified no-op, shouldn't appear in standard output
    elseif op == OP.SECTION then
      -- debug marker, no-op
    elseif op == OP.IS then
      frame.reg[a] = (type(frame.reg[b]) == c)
    elseif op == OP.TRY then
      -- try block: simplified no-op
    elseif op == OP.TRYRETURN then
      -- return from try: simplified as normal return
      local nret = b - 1
      local rets = {}
      for i = 1, nret do rets[i] = frame.reg[a + i - 1] end
      return table.unpack(rets)

    else
      error("VM: unknown opcode " .. tostring(op) .. " at pc=" .. frame.pc)
    end

    frame.pc = frame.pc + 1
  end
end

-- public API
function VM.load(chunk_table, env)
  local factory = compile_chunk(chunk_table, env or _G)
  -- main chunk has 1 upvalue (_ENV)
  local main_uv = {[0] = {kind="closed", val=env or _G}}
  return factory(main_uv)
end

function VM.run(closure, ...)
  return execute(closure, ...)
end

function VM.exec(chunk_table, ...)
  local closure = VM.load(chunk_table)
  return VM.run(closure, ...)
end

return VM
