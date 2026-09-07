local luac = require("luac")

local f = io.open("E:/LuaRes/web/loops_test.luac", "rb")
local data = f:read("*a")
f:close()

local proto = luac.undump(data)

local opnames = {
  [0]="MOVE",[1]="LOADK",[2]="LOADKX",[3]="LOADBOOL",[4]="LOADNIL",
  [5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",[9]="SETUPVAL",
  [10]="SETTABLE",[11]="NEWTABLE",[12]="SELF",[13]="ADD",[14]="SUB",
  [15]="MUL",[16]="MOD",[17]="POW",[18]="DIV",[19]="IDIV",
  [20]="BAND",[21]="BOR",[22]="BXOR",[23]="SHL",[24]="SHR",
  [25]="UNM",[26]="BNOT",[27]="NOT",[28]="LEN",[29]="CONCAT",
  [30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",
  [35]="TESTSET",[36]="CALL",[37]="TAILCALL",[38]="RETURN",[39]="FORLOOP",
  [40]="FORPREP",[41]="TFORCALL",[42]="TFORLOOP",[43]="SETLIST",
  [44]="CLOSURE",[45]="VARARG",[46]="EXTRAARG"
}

local function disasm(p, depth)
  local indent = string.rep("  ", depth)
  print(string.format("%s=== Proto (sizecode=%d, sizek=%d, sizep=%d, numparams=%d, is_vararg=%d, maxstack=%d) ===",
    indent, p.sizecode, p.sizek, p.sizep, p.numparams, p.is_vararg, p.maxstacksize))
  
  print(indent .. "--- constants ---")
  for i = 1, p.sizek do
    local c = p.k[i]
    local typ = type(c)
    local val = tostring(c)
    if typ == "string" and #val > 30 then val = val:sub(1,30).."..." end
    print(string.format("%s  k[%d] = %s: %s", indent, i-1, typ, val))
  end
  
  print(indent .. "--- code ---")
  for i = 1, p.sizecode do
    local pc = i - 1
    local inst = p.code[i]
    local op = inst & 0x3F
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local name = opnames[op] or ("OP"..op)
    
    local desc
    if op == 30 or op == 39 or op == 40 or op == 42 then
      desc = string.format("A=%d sBx=%d (target=%d)", a, sbx, pc+1+sbx)
    elseif op == 1 or op == 2 then
      desc = string.format("A=%d Bx=%d (k[%d])", a, bx, bx)
    elseif op == 46 then
      desc = string.format("Ax=%d", inst >> 6)
    elseif op == 36 or op == 37 or op == 38 then
      desc = string.format("A=%d B=%d C=%d", a, b, c)
    else
      desc = string.format("A=%d B=%d C=%d", a, b, c)
    end
    print(string.format("%s  [%3d] %-10s %s", indent, pc, name, desc))
  end
  
  for i = 1, p.sizep do
    disasm(p.p[i], depth + 1)
  end
end

disasm(proto, 0)
