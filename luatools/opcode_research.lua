-- opcode_research.lua - 全面研究 Lua 5.3 opcode 模式、指令依赖、配对关系
local luac = require("luac")

local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL",
  "GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE",
  "NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV",
  "BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT",
  "JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN",
  "FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function decode(ins)
  local op = ins % 64
  local a = math.floor(ins / 64) % 256
  local c = math.floor(ins / 16384) % 512
  local b = math.floor(ins / 8388608) % 512
  local bx = math.floor(ins / 64) % 262144
  local sbx = bx - 131072
  return op, a, b, c, bx, sbx
end

local function fmt(ins)
  local op, a, b, c, bx, sbx = decode(ins)
  local name = opnames[op+1] or ("op"..op)
  if op == 1 or op == 2 then return string.format("%-10s A=%d Bx=%d", name, a, bx) end
  if op == 30 or op == 31 or op == 32 or op == 33 then return string.format("%-10s A=%d B=%d C=%d sbx=%d", name, a, b, c, sbx) end
  if op == 39 or op == 40 or op == 42 then return string.format("%-10s A=%d sbx=%d", name, a, sbx) end
  if op == 44 then return string.format("%-10s A=%d Bx=%d", name, a, bx) end
  return string.format("%-10s A=%d B=%d C=%d", name, a, b, c)
end

-- 分析指令的寄存器读写
local function reads_regs(ins)
  local op, a, b, c = decode(ins)
  local regs = {}
  local function rk(v) if v < 256 then table.insert(regs, v) end end
  if op == 0 then rk(b)  -- MOVE
  elseif op == 7 then rk(b); rk(c)  -- GETTABLE
  elseif op == 9 then rk(b); rk(c)  -- SETTABUP
  elseif op == 11 then rk(a); rk(b); rk(c)  -- SETTABLE
  elseif op == 13 then rk(b); rk(c)  -- SELF
  elseif op >= 14 and op <= 25 then rk(b); rk(c)  -- 算术/位运算
  elseif op >= 26 and op <= 29 then rk(b)  -- UNM/BNOT/NOT/LEN
  elseif op == 30 then for i=b,c do table.insert(regs, i) end  -- CONCAT
  elseif op == 31 or op == 32 or op == 33 then rk(b); rk(c)  -- EQ/LT/LE
  elseif op == 34 then rk(a)  -- TEST
  elseif op == 35 then rk(b)  -- TESTSET
  elseif op == 36 or op == 37 then  -- CALL/TAILCALL
    table.insert(regs, a)  -- 函数寄存器
    for i=a+1, a+b-2 do table.insert(regs, i) end  -- 参数
  elseif op == 38 then for i=a, a+b-2 do table.insert(regs, i) end  -- RETURN
  elseif op == 41 then table.insert(regs, a+1); table.insert(regs, a+2)  -- TFORCALL
  elseif op == 43 then for i=a+1, a+b do table.insert(regs, i) end  -- SETLIST
  end
  return regs
end

local function writes_regs(ins)
  local op, a, b, c = decode(ins)
  local regs = {}
  if op == 0 or op == 1 or op == 2 or op == 3 or op == 4 then table.insert(regs, a)  -- MOVE/LOADK/LOADKX/LOADBOOL/LOADNIL
  elseif op == 5 or op == 6 or op == 7 then table.insert(regs, a)  -- GETUPVAL/GETTABUP/GETTABLE
  elseif op == 12 then table.insert(regs, a)  -- NEWTABLE
  elseif op == 13 then table.insert(regs, a); table.insert(regs, a+1)  -- SELF
  elseif op >= 14 and op <= 29 then table.insert(regs, a)  -- 算术/位运算/UNM/BNOT/NOT/LEN
  elseif op == 30 then table.insert(regs, a)  -- CONCAT
  elseif op == 35 then table.insert(regs, a)  -- TESTSET
  elseif op == 36 then for i=a, a+b-1 do table.insert(regs, i) end  -- CALL 返回值
  elseif op == 39 then table.insert(regs, a)  -- FORLOOP
  elseif op == 42 then for i=a+3, a+2+c do table.insert(regs, i) end  -- TFORLOOP
  elseif op == 44 then table.insert(regs, a)  -- CLOSURE
  elseif op == 45 then for i=a, a+b-2 do table.insert(regs, i) end  -- VARARG
  end
  return regs
end

-- 分析一个 proto 的指令依赖图
local function analyze_deps(p, depth)
  depth = depth or 0
  local indent = string.rep("  ", depth)
  print(indent .. "=== Proto: sizecode=" .. p.sizecode .. " sizek=" .. p.sizek .. " ===")

  -- 统计 opcode 频率
  local opcount = {}
  for i = 1, p.sizecode do
    local op = p.code[i] % 64
    opcount[op] = (opcount[op] or 0) + 1
  end
  print(indent .. "Opcode 分布:")
  for op = 0, 46 do
    if opcount[op] then
      print(indent .. "  " .. opnames[op+1] .. " = " .. opcount[op])
    end
  end

  -- 分析配对关系
  print(indent .. "配对关系:")
  for i = 1, p.sizecode do
    local op = p.code[i] % 64
    if op == 2 then  -- LOADKX
      local next_op = (i < p.sizecode) and (p.code[i+1] % 64) or -1
      print(indent .. "  [" .. (i-1) .. "] LOADKX -> 下一条=" .. opnames[next_op+1] .. (next_op == 46 and " (配对正确)" or " (配对错误!)"))
    elseif op == 43 then  -- SETLIST C=0
      local _, _, _, c = decode(p.code[i])
      if c == 0 then
        local next_op = (i < p.sizecode) and (p.code[i+1] % 64) or -1
        print(indent .. "  [" .. (i-1) .. "] SETLIST C=0 -> 下一条=" .. opnames[next_op+1] .. (next_op == 46 and " (配对正确)" or " (配对错误!)"))
      end
    elseif op >= 31 and op <= 34 then  -- EQ/LT/LE/TEST
      local next_op = (i < p.sizecode) and (p.code[i+1] % 64) or -1
      print(indent .. "  [" .. (i-1) .. "] " .. opnames[op+1] .. " -> 下一条=" .. opnames[next_op+1] .. (next_op == 30 and " (配对正确)" or " (配对错误!)"))
    elseif op == 44 then  -- CLOSURE
      -- 检查后续 upvalue 设置
      local j = i + 1
      local upval_count = 0
      while j <= p.sizecode and j <= i + 10 do
        local jop = p.code[j] % 64
        if jop == 0 or jop == 5 then  -- MOVE or GETUPVAL
          upval_count = upval_count + 1
          j = j + 1
        else
          break
        end
      end
      if upval_count > 0 then
        print(indent .. "  [" .. (i-1) .. "] CLOSURE -> 后续 " .. upval_count .. " 条 upvalue 设置 (MOVE/GETUPVAL)")
      end
    end
  end

  -- 分析 JMP 目标
  print(indent .. "JMP 指令:")
  for i = 1, p.sizecode do
    local op, a, b, c, bx, sbx = decode(p.code[i])
    if op == 30 then  -- JMP
      local target = i + sbx  -- 0-based target
      print(indent .. "  [" .. (i-1) .. "] JMP sbx=" .. sbx .. " -> 目标[" .. target .. "] " .. (target >= 0 and target < p.sizecode and fmt(p.code[target+1]) or "越界!"))
    elseif op == 39 or op == 40 then  -- FORLOOP/FORPREP
      local target = i + sbx
      print(indent .. "  [" .. (i-1) .. "] " .. opnames[op+1] .. " sbx=" .. sbx .. " -> 目标[" .. target .. "]")
    elseif op == 42 then  -- TFORLOOP
      local target = i + sbx
      print(indent .. "  [" .. (i-1) .. "] TFORLOOP sbx=" .. sbx .. " -> 目标[" .. target .. "]")
    end
  end

  -- 递归子 proto
  if p.p then
    for i = 1, p.sizep do
      analyze_deps(p.p[i], depth + 1)
    end
  end
end

-- 测试各种代码结构
local test_cases = {
  {"if-else", "if true then print(1) else print(2) end"},
  {"if-elseif-else", "if false then print(1) elseif true then print(2) else print(3) end"},
  {"while", "local i=0 while i<3 do i=i+1 print(i) end"},
  {"repeat", "local i=0 repeat i=i+1 print(i) until i>=3"},
  {"for-num", "for i=1,3 do print(i) end"},
  {"for-num-step", "for i=10,1,-2 do print(i) end"},
  {"for-generic", "for k,v in pairs({a=1,b=2}) do print(k,v) end"},
  {"闭包", "local x=1 local function f() x=x+1 return x end print(f())"},
  {"upvalue嵌套", "local function outer() local x=1 local function inner() return x end return inner end print(outer()())"},
  {"可变参数", "local function f(...) return select(1,...) end print(f(1,2,3))"},
  {"多返回值", "local function f() return 1,2,3 end local a,b,c=f() print(a,b,c)"},
  {"方法调用", "local t={}; function t:m(x) return x+self.v end t.v=10 print(t:m(5))"},
  {"表构造", "local t = {1, 2, 3, a=4, b=5}"},
  {"大表构造", "local t = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40}"},
  {"字符串连接", 'local a = "a".."b".."c".."d"'},
  {"逻辑and", "local x = true and 1 or 2"},
  {"逻辑or", "local x = false or 1"},
  {"变长返回调用", "local function f(...) return ... end print(f(1,2,3))"},
  {"pcall", "local ok, err = pcall(function() error('test') end) print(ok, err)"},
  {"元方法", "local t = setmetatable({}, {__add = function(a,b) return 42 end}) print(t + 1)"},
  {"环境表", "local _ENV = {print=function(...) return ... end} print('hello')"},
  {"goto", "::start:: print(1) goto start"},
  {"break", "for i=1,10 do if i==5 then break end print(i) end"},
  {"return多值", "local function f() return 1,2,3,4,5 end print(f())"},
  {"嵌套调用", "print(tostring(6)..'')"},
  {"闭包立即调用", "print((function(x) return x*2 end)(21))"},
  {"条件表达式", "local x = 1; local y = x > 0 and 'pos' or 'neg'"},
  {"数字运算链", "local x = 1 + 2 * 3 - 4 / 2 % 3"},
  {"位运算", "local x = 0xFF & 0x0F | 0xF0 ~ 0xAA"},
  {"幂运算", "local x = 2 ^ 10"},
  {"取反", "local x = ~0"},
  {"长度运算", 'local x = #"hello"'},
  {"表索引链", "local t = {a={b={c=1}}} print(t.a.b.c)"},
  {"self语法糖", "local t = {}; function t:m(x) return x end; t:m(1)"},
  {"vararg传递", "local function f(...) return g(...) end"},
  {"闭包upvalue修改", "local function counter() local n=0 return function() n=n+1 return n end end local c=counter() print(c()) print(c())"},
}

print("========================================")
print("Lua 5.3 Opcode 全面研究")
print("========================================")

for _, tc in ipairs(test_cases) do
  local name, src = tc[1], tc[2]
  print("\n" .. string.rep("#", 60))
  print("# 测试: " .. name)
  print("# 代码: " .. src:sub(1, 70))
  print(string.rep("#", 60))
  local ok, bc = pcall(function() return string.dec(string.dump(load(src), false)) end)
  if not ok then
    print("  编译失败: " .. tostring(bc))
    goto continue
  end
  local p = luac.undump(bc, false)
  analyze_deps(p, 0)
  ::continue::
end

print("\n========================================")
print("研究完成")
print("========================================")
