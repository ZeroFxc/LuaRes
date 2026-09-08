local luac = require("luac")
local f = io.open("_complex.lua", "r")
local code = f:read("*a")
f:close()
luac.srand(42)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
local mods = {
  {"const_hide", luac.const_hide_c},
  {"const_shuffle", luac.const_shuffle_c},
  {"str_encrypt", luac.str_encrypt_c},
  {"instruction_mutate", luac.instruction_mutate_c},
  {"num_obfuscate", luac.num_obfuscate_c},
  {"str_split", luac.str_split_c},
  {"bool_obfuscate", luac.bool_obfuscate_c},
  {"table_obfuscate", luac.table_obfuscate_c},
  {"opaque_predicate", luac.opaque_predicate_c},
  {"const_poison", luac.const_poison_c},
  {"opaque_junk", luac.opaque_junk_c},
  {"junk_jmp", luac.junk_jmp_c},
  {"junk_loadk", luac.junk_loadk_c},
  {"junk_move", luac.junk_move_c},
  {"luac_obfuscate", luac.luac_obfuscate_c},
  {"luac_flatten", luac.luac_flatten_c},
  {"debug_strip", luac.debug_strip_c},
  {"antidec", luac.antidec_c},
  {"proto_shuffle", luac.proto_shuffle_c},
  {"live_range_split", luac.live_range_split_c},
  {"op48_junk", luac.op48_junk_c},
}
for i, m in ipairs(mods) do
  m[2](p)
  -- test after each module
  local bc = luac.dump(p, true)
  local ok, func = pcall(load, bc)
  if ok and func then
    local ok2, err = pcall(func)
    if not ok2 then
      io.write("FAIL after "..m[1]..": "..tostring(err).."\n"); io.flush()
      os.exit(1)
    end
  else
    io.write("LOAD FAIL after "..m[1]..": "..tostring(func).."\n"); io.flush()
    os.exit(1)
  end
  io.write("ok: "..m[1].."\n"); io.flush()
end
io.write("ALL OK\n"); io.flush()
