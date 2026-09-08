local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.instruction_mutate_c(p); luac.num_obfuscate_c(p); luac.str_split_c(p); luac.bool_obfuscate_c(p); luac.table_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local c = p.code
local overflow = 0
for i = 1, #c do
    local ins = c[i]
    local op = ins % 64
    local a = math.floor(ins / 64) % 256
    local cfield = math.floor(ins / 16384) % 512
    local bfield = math.floor(ins / 8388608) % 512
    -- iABC opcodes that use B/C as RK
    if op <= 25 or op == 27 or op == 28 or op == 29 or (op >= 31 and op <= 35) or op == 43 then
        if bfield >= 512 or cfield >= 512 then
            -- can't happen since we mask to 512, check if original value >= 512
        end
        -- check if constant reference >= 256 (bfield/cfield >= 256 means constant, index = field-256)
        local bk = bfield >= 256 and (bfield - 256) or nil
        local ck = cfield >= 256 and (cfield - 256) or nil
        if (bk and bk >= 256) or (ck and ck >= 256) then
            overflow = overflow + 1
            if overflow <= 10 then
                print(string.format("[%d] op=%d a=%d b=%d(k%d) c=%d(k%d)", i-1, op, a, bfield, bk or -1, cfield, ck or -1))
            end
        end
    end
end
print("total overflow instructions: "..overflow)
print("sizek="..tostring(p.sizek))
