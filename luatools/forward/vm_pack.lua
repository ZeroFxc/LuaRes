-- vm_pack.lua - Convert standard luac proto to VM table format
-- This module runs LAST in the pipeline, producing custom VM bytecode.
local luac = require("luac")

local function decode_ins(ins)
  local op = ins & 0x3F
  local a = (ins >> 6) & 0xFF
  local c = (ins >> 14) & 0x1FF
  local b = (ins >> 23) & 0x1FF
  local bx = ins >> 14
  local sbx = bx - 131071
  return {op, a, b, c, bx, sbx}
end

local function pack_const(v)
  local t = type(v)
  if t == "nil" then return {t="n"}
  elseif t == "boolean" then return {t="b", v=v}
  elseif t == "number" then
    if math.tointeger(v) == v then return {t="i", v=v}
    else return {t="f", v=v} end
  elseif t == "string" then return {t="s", v=v}
  else return {t="n"} end
end

local function pack_proto(proto)
  local chunk = {
    num_params = proto.numparams or 0,
    is_vararg = proto.is_vararg or 0,
    maxstacksize = proto.maxstacksize or 2,
    code = {},
    k = {},
    p = {},
    upvalues = {},
  }

  -- code
  for i = 1, proto.sizecode do
    chunk.code[i] = decode_ins(proto.code[i])
  end

  -- constants
  for i = 1, proto.sizek do
    chunk.k[i] = pack_const(proto.k[i])
  end

  -- sub protos
  for i = 1, proto.sizep do
    chunk.p[i] = pack_proto(proto.p[i])
  end

  -- upvalues
  if proto.upvalues then
    for i = 1, #proto.upvalues do
      local uv = proto.upvalues[i]
      chunk.upvalues[i] = {instack = uv.instack or 0, idx = uv.idx or 0}
    end
  end

  return chunk
end

-- serialize chunk table to a string that can be loaded back
-- use Lua table literal via string.dump of a loader function
local function serialize_chunk(chunk)
  local parts = {}
  local function ser(val, depth)
    local t = type(val)
    if t == "nil" then parts[#parts+1] = "nil"
    elseif t == "boolean" then parts[#parts+1] = val and "true" or "false"
    elseif t == "number" then parts[#parts+1] = tostring(val)
    elseif t == "string" then
      parts[#parts+1] = string.format("%q", val)
    elseif t == "table" then
      parts[#parts+1] = "{"
      local arr = true
      for k, v in pairs(val) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
          arr = false
          break
        end
      end
      if arr then
        for i = 1, #val do
          if i > 1 then parts[#parts+1] = "," end
          ser(val[i], depth+1)
        end
      else
        local first = true
        for k, v in pairs(val) do
          if not first then parts[#parts+1] = "," end
          first = false
          if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            parts[#parts+1] = k .. "="
          else
            parts[#parts+1] = "["
            ser(k, depth+1)
            parts[#parts+1] = "]="
          end
          ser(v, depth+1)
        end
      end
      parts[#parts+1] = "}"
    end
  end
  ser(chunk, 0)
  return table.concat(parts)
end

-- Main entry: takes proto, returns packed chunk table
local function pack(proto)
  if type(proto) == "string" then
    proto = luac.undump(proto, true)
  end
  return pack_proto(proto)
end

-- Pack and produce a runnable Lua chunk that embeds the VM + bytecode
local function pack_to_lua_source(proto, vm_source)
  local chunk = pack(proto)
  local serialized = serialize_chunk(chunk)
  return string.format(
    "local VM = ...\n" ..
    "local chunk = %s\n" ..
    "return VM.exec(chunk, ...)\n",
    serialized
  )
end

return {
  pack = pack,
  pack_proto = pack_proto,
  serialize_chunk = serialize_chunk,
  pack_to_lua_source = pack_to_lua_source,
}
