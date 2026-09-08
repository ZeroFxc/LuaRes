-- Lua 5.3 opcode 结构分析脚本
local luac = require("luac")

local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function decode_ins(ins)
    local op = ins % 64
    local a = math.floor(ins / 64) % 256
    local c = math.floor(ins / 16384) % 512
    local b = math.floor(ins / 8388608) % 512
    local bx = math.floor(ins / 64) % 262144
    local sbx = bx - 131072
    return op, a, b, c, bx, sbx
end

local function analyze_proto(p, indent)
    indent = indent or ""
    print(string.format("%ssizek=%d sizecode=%d numparams=%d is_vararg=%d maxstacksize=%d",
        indent, p.sizek, p.sizecode, p.numparams, p.is_vararg, p.maxstacksize))
    -- 常量池
    local k = p.k
    for i = 1, p.sizek do
        local v = k[i]
        print(string.format("%s  k[%d] %s", indent, i-1, tostring(v)))
    end
    -- 指令
    local code = p.code
    for i = 1, p.sizecode do
        local ins = code[i]
        local op, a, b, c, bx, sbx = decode_ins(ins)
        local name = opnames[op+1] or ("OP"..op)
        local detail
        if name == "JMP" or name == "FORLOOP" or name == "FORPREP" or name == "TFORLOOP" then
            detail = string.format("A=%d sBx=%d (->%d)", a, sbx, i+sbx)
        elseif name == "LOADK" or name == "GETTABUP" or name == "SETTABUP" or name == "CLOSURE" then
            detail = string.format("A=%d Bx=%d", a, bx)
        elseif name == "LOADKX" or name == "EXTRAARG" then
            detail = string.format("Ax=%d", math.floor(ins/64))
        else
            detail = string.format("A=%d B=%d C=%d", a, b, c)
        end
        print(string.format("%s  [%03d] %-10s %s", indent, i-1, name, detail))
    end
    -- 子函数
    local pp = p.p
    for i = 1, p.sizep do
        print(string.format("%s--- subproto[%d] ---", indent, i-1))
        analyze_proto(pp[i], indent .. "  ")
    end
end

local function analyze(name, src)
    print("=== " .. name .. " ===")
    local bc = string.dec(string.dump(load(src), true))
    local p = luac.undump(bc, false)
    analyze_proto(p)
    print()
end

analyze("简单赋值", "local a = 1")
analyze("算术运算", "local a = 1 + 2 * 3")
analyze("if-else", "if true then print(1) else print(2) end")
analyze("while循环", "local i=0 while i<3 do i=i+1 end")
analyze("for循环", "for i=1,3 do print(i) end")
analyze("函数定义", "local function f(x) return x+1 end")
analyze("闭包", "local function f() local x=1 return function() x=x+1 return x end end")
analyze("可变参数", "local function f(...) return select(1,...) end")
analyze("逻辑运算", "local a = true and false or true")
analyze("方法调用", "local t={}; function t:m(x) return x end; t:m(1)")
analyze("repeat-until", "local i=0 repeat i=i+1 until i>=3")
analyze("表构造", "local t = {1, 2, 3}")
analyze("字符串连接", 'local a = "hello" .. "world"')
