-- The testset is not tested.

-- QQ : 3580131529

local printf = print or io.write or error("不存在打印函数。")

local error = error or function (errorStr)
    return printf(errorStr)
end

-- loadk
do
    local a = 1 -- load int
    local b = 1.2 -- load Float
    local c = "hello。" -- load string
    -- Implies jmp, call, eq
    if a ~= 1 or b ~= 1.2 or c ~= "hello。" then
        error("LOADK test error。")
    end
end

printf(1)

--loadbool and loadnil
--The case where C ~= 0 is not tested
do
    local a = true
    local b = false
    local c,d
    if a ~= true or b ~= false or c ~= nil or d ~= nil then
        error("LOADBOOL test error。")
    end
end

printf(2)

-- table
-- newtable, settable, gettable, setlist, gettabup, settabup
do
    local closure = function ()
        return 4
    end -- its closure
    local closure2 = function ()
        return 1, 2, 3
    end -- its closure
    local a = {} -- newtable
    a[1] = 1 -- settable
    a['test'] = 2 -- settable
    local b = a[1] -- gettable
    local c = { -- setlist and b>=0
        1,
        2,
        3,
        closure()
    }
    local d = { -- c = 0 ( setlist )
        closure2()
    }
    local e = _ENV.printf -- gettabup
    _ENV[1] = 'test' -- settabup
    if a[1] ~= 1 or a['test'] ~= 2 or c[4] ~= 4 or d[1] ~= 1 or d[2] ~= 2 or d[3] ~= 3 then
        error('Table or closure test error。')
    end
    _ENV[1] = nil
end

printf(3)

--。vararg, closure, call, tailcall, and upvalue (jmp)
do
    local function multi(a, b, c)
        return a, b, c
    end

    -- closure upvalues test (jmp a>1)
    local function makeCounters()
        local shared = 0
        local a = {}
        local i = 1
        ::again::
        local unshared
        if i > 2 then goto done end
        a[i] = function(x)
            if x then
                unshared = x
            else
                return unshared + shared
            end
        end
        i = i + 1
        goto again
        ::done::
        a[0] = function(y) shared = y end
        return a
    end

    local counters = makeCounters()
    counters[1](10)
    counters[2](20)
    counters[0](13)
    local up1 = counters[1]()
    local up2 = counters[2]()

    -- vararg tests (B=0, B=2, B=3)
    local function varargB0(a, ...)
        local t = {...}
        return #t, t[1], t[2], t[3]
    end

    local function varargB2(a, ...)
        local x = ...
        return x
    end

    local function varargB3(a, ...)
        local x, y = ...
        return x, y
    end

    local v1, v2, v3, v4 = varargB0(1, 10, 20, 30)
    local v5 = varargB2(1, 100)
    local v6, v7 = varargB3(1, 10, 20)

    -- call with c=0
    local function callC0()
        return 1, 2, 3
    end
    local c1, c2, c3 = callC0()

    -- tailcall with b=0
    local function tailB0(...)
        return multi(...)
    end
    local t1, t2, t3 = tailB0(100, 200, 300)

    -- tailcall with fixed args
    local function tailSum(n, acc)
        if n <= 0 then return acc end
        return tailSum(n - 1, acc + n)
    end
    local sum = tailSum(5, 0)

    -- closure call
    local function makeAdder(x)
        return function(y) return x + y end
    end
    local add5 = makeAdder(5)
    local closureResult = add5(7)

    if up1 ~= 23 or up2 ~= 33 or
       v1 ~= 3 or v2 ~= 10 or v3 ~= 20 or v4 ~= 30 or
       v5 ~= 100 or v6 ~= 10 or v7 ~= 20 or
       c1 ~= 1 or c2 ~= 2 or c3 ~= 3 or
       t1 ~= 100 or t2 ~= 200 or t3 ~= 300 or
       sum ~= 15 or closureResult ~= 12 then
        error('Complex vararg/closure/tailcall/upvalue test error。')
    end
end

printf(3)

-- arithmetic and bitwise and self
do
    -- arithmetic (add, sub, mul, div, mod, pow, idiv)
    local a1 = 1 + 2 -- add
    local a2 = 5 - 3 -- sub
    local a3 = 2 * 3 -- mul
    local a4 = 10 / 2 -- div
    local a5 = 10 % 3 -- mod
    local a6 = 2 ^ 3 -- pow
    local a7 = 10 // 3 -- idiv
    
    -- unary (unm, not, len)
    local u1 = -5 -- unm
    local u2 = not true -- not
    local u3 = #"hello" -- len
    
    -- bitwise (band, bor, bxor, shl, shr, bnot)
    local b1 = 3 & 1 -- band (3 & 1 = 1)
    local b2 = 1 | 2 -- bor (1 | 2 = 3)
    local b3 = 3 ~ 1 -- bxor (3 ~ 1 = 2)
    local b4 = 1 << 3 -- shl (1 << 3 = 8)
    local b5 = 8 >> 2 -- shr (8 >> 2 = 2)
    local b6 = ~0 -- bnot (~0 = -1)
    
    -- concat
    local c1 = "hello" .. " " .. "world"  -- concat
    local c2 = "a" .. "b" .. "c" .. "d" .. "e"  -- concat multiple
    
    -- move (implicit in assignments)
    local m1 = 100
    local m2 = m1           -- move
    
    -- self
    local t = {x = 10}
    function t:get() return self.x end
    local s1 = t:get()      -- self
    
    if a1 ~= 3 or a2 ~= 2 or a3 ~= 6 or a4 ~= 5 or a5 ~= 1 or a6 ~= 8 or a7 ~= 3 then
        error('Arithmetic test error。')
    end
    if u1 ~= -5 or u2 ~= false or u3 ~= 5 then
        error('Unary test error。')
    end
    if b1 ~= 1 or b2 ~= 3 or b3 ~= 2 or b4 ~= 8 or b5 ~= 2 or b6 ~= -1 then
        error('Bitwise test error。')
    end
    if c1 ~= "hello world" or c2 ~= "abcde" then
        error('CONCAT test error。')
    end
    if m2 ~= 100 then
        error('MOVE test error。')
    end
    if s1 ~= 10 then
        error('SELF test error。')
    end
end

printf(4)

-- all for ops test
do
    -- numeric for (forprep, forloop) with positive step
    local sum1 = 0
    for i = 1, 5 do -- forprep + forloop
        sum1 = sum1 + i
    end
    
    -- numeric for with negative step
    local sum2 = 0
    for i = 5, 1, -1 do -- forprep negative step
        sum2 = sum2 + i
    end
    
    -- numeric for with zero step (no iteration)
    local count3 = 0
    for i = 1, 5, 0 do -- step = 0, should not loop
        count3 = count3 + 1
    end
    
    -- numeric for with limit less than start (positive step, no loop)
    local count4 = 0
    for i = 5, 1 do -- start > limit, no loop
        count4 = count4 + 1
    end
    
    -- numeric for with variable bounds
    local start, limit, step = 2, 8, 2
    local sum5 = 0
    for i = start, limit, step do
        sum5 = sum5 + i
    end
    
    -- generic for (tforcall, tforloop) with pairs
    local t6 = {a = 1, b = 2, c = 3}
    local count6 = 0
    local sum6 = 0
    for k, v in pairs(t6) do
        count6 = count6 + 1
        sum6 = sum6 + v
    end
    
    -- generic for with empty table
    local count7 = 0
    for _ in pairs({}) do
        count7 = count7 + 1
    end
    
    -- generic for with iterator that returns nil first
    local function emptyIter()
        return nil
    end
    local count8 = 0
    for _ in emptyIter do
        count8 = count8 + 1
    end
    
    -- generic for with multi return iterator
    local function triples()
        return 1, 2, 3
    end
    local a9, b9, c9
    for x, y, z in triples do
        a9, b9, c9 = x, y, z
        break
    end
    
    if sum1 ~= 15 then
        error('FORLOOP positive step test error。')
    end
    if sum2 ~= 15 then
        error('FORLOOP negative step test error。')
    end
    if count3 ~= 0 then
        error('FORLOOP zero step test error。')
    end
    if count4 ~= 0 then
        error('FORLOOP no iteration test error。')
    end
    if sum5 ~= 20 then
        error('FORLOOP variable bounds test error。')
    end
    if count6 ~= 3 or sum6 ~= 6 then
        error('TFORLOOP pairs test error。')
    end
    if count7 ~= 0 then
        error('TFORLOOP empty table test error。')
    end
    if count8 ~= 0 then
        error('TFORLOOP nil first return test error。')
    end
    if a9 ~= 1 or b9 ~= 2 or c9 ~= 3 then
        error('TFORLOOP multi-return test error。')
    end
end

printf(5)

-- EQ, LT, LE
do
    local a = 1 == 1 -- EQ 1 1 1
    local b = 1 == 2 -- EQ 1 2 0
    local c = "a" == "a" -- EQ string equal
    local d = "a" == "b" -- EQ string not equal
    local e = true == true -- EQ boolean equal
    local f = true == false -- EQ boolean not equal
    local g = nil == nil -- EQ nil equal
    local h = nil == false -- EQ nil vs false
    local i = 1 == "1" -- EQ number vs string
    local j = 0 == false -- EQ number vs boolean
    local t1 = {}
    local t2 = {}
    local k = t1 == t1 -- EQ same table
    local l = t1 == t2 -- EQ different tables
    local m = {} == nil -- EQ table vs nil
    local n = 1 < 2 -- LT 1 2 1
    local o = 2 < 1 -- LT 2 1 0
    local p = 1 < 1 -- LT 1 1 0
    local q = -5 < -2 -- LT negative
    local r = "a" < "b" -- LT string
    local s = 1 <= 2 -- LE 1 2 1
    local t = 2 <= 1 -- LE 2 1 0
    local u = 1 <= 1 -- LE 1 1 1
    local v = "a" <= "b" -- LE string
    if a ~= true or b ~= false or k ~= true or l ~= false or n ~= true or o ~= false or s ~= true or t ~= false then
        error('Comparison test error。')
    end
end

printf(6)

-- return tests
do
    -- RETURN B=1 (no return values)
    local function retB1()
        return -- RETURN B=1
    end
    local r1 = retB1()
    
    -- RETURN B=0 (return from A to top)
    local function retB0()
        local a = 1
        local b = 2
        local c = 3
        return a, b, c -- RETURN B=0
    end
    local r2, r3, r4 = retB0()
    
    -- RETURN B>1 (fixed number of returns)
    local function retB3()
        local a = 10
        local b = 20
        local c = 30
        local d = 40
        return a, b -- RETURN B=3 (returns 2 values)
    end
    local r5, r6 = retB3()
    
    -- RETURN B=0 with no values (top == A)
    local function retB0Empty()
        do return end -- RETURN B=0, top == A
    end
    local r7 = retB0Empty()
    
    -- RETURN B=0 with varargs
    local function retB0Vararg(...)
        return ... -- RETURN B=0 with varargs
    end
    local r8, r9, r10 = retB0Vararg(100, 200, 300)
    
    -- RETURN B=0 after CALL C=0
    local function inner()
        return 1, 2, 3
    end
    local function retB0Call()
        return inner() -- RETURN B=0 after CALL C=0
    end
    local r11, r12, r13 = retB0Call()
    
    if r1 ~= nil then
        error('RETURN B=1 test error。')
    end
    if r2 ~= 1 or r3 ~= 2 or r4 ~= 3 then
        error('RETURN B=0 test error。')
    end
    if r5 ~= 10 or r6 ~= 20 then
        error('RETURN B>1 test error。')
    end
    if r7 ~= nil then
        error('RETURN B=0 empty test error。')
    end
    if r8 ~= 100 or r9 ~= 200 or r10 ~= 300 then
        error('RETURN B=0 vararg test error。')
    end
    if r11 ~= 1 or r12 ~= 2 or r13 ~= 3 then
        error('RETURN B=0 call test error。')
    end
end

-- 三层嵌套 upvalue（跨层级共享）
do
    local counter = 0
    local function createCounter()
        local secret = 100
        return function()
            counter = counter + 1
            return counter + secret
        end
    end
    local c1 = createCounter()
    local r1 = c1()
    local r2 = c1()
    if r1 ~= 101 or r2 ~= 102 then
        error('三层嵌套 upvalue 测试失败。')
    end
end

printf(8)

-- 递归闭包自引用 前向引用。
do
    local function fib()
        local cache = {[0]=0, [1]=1}
        local function calc(n)
            if cache[n] == nil then
                cache[n] = calc(n-1) + calc(n-2)
            end
            return cache[n]
        end
        return calc
    end
    local fibCalc = fib()
    local r = fibCalc(10)
    if r ~= 55 then
        error('递归闭包自引用测试失败。')
    end
end

printf(9)

-- 多层嵌套 close 后修改共享 upvalue。
do
    local a = {}
    local k = 0
    do
        local x1 = 10
        a[1] = function(y)
            if y then x1 = y else return x1 + k end
        end
    end  -- 第一次 close：x1 被固化
    do
        local x2 = 20
        a[2] = function(y)
            if y then x2 = y else return x2 + k end
        end
    end  -- 第二次 close：x2 被固化
    a[0] = function(y) k = y end  -- k 没被 close，直接穿透

    a[0](13)
    local r1 = a[1]()
    local r2 = a[2]()
    if r1 ~= 23 or r2 ~= 33 then
        error('多次 close 后修改共享 upvalue 测试失败。')
    end
end

printf(10)

-- goto 跳转导致的不同 close 时序。
do
    local a = {}
    local k = 0
    local i = 1
    ::l1::
    if i > 2 then goto l2 end
    do
        local x
        a[i] = function(y)
            if y then x = y else return x + k end
        end
    end  -- 每次循环结束 close 当前的 x。
    i = i + 1
    goto l1
    ::l2::
    a[0] = function(y) k = y end

    a[1](10)
    a[2](20)
    a[0](13)
    local r1 = a[1]()
    local r2 = a[2]()
    if r1 ~= 23 or r2 ~= 33 then
        error('goto 跳转 close 时序测试失败。')
    end
end

printf(11)

-- vararg 展开为 table 存储在 upvalue 中。
do
    local function wrap(...)
        local args = {...}
        return function()
            return #args, args[1], args[2], args[3]
        end
    end
    local f = wrap(10, 20, 30)
    local n, v1, v2, v3 = f()
    if n ~= 3 or v1 ~= 10 or v2 ~= 20 or v3 ~= 30 then
        error('vararg upvalue 测试失败。')
    end
end

printf(12)

-- 同一函数创建的多个闭包，各自独立 upvalue 且互不干扰。
do
    local function create(x)
        return function(v)
            if v then x = v else return x end
        end
    end
    local c1 = create(10)
    local c2 = create(20)
    local c3 = create(30)
    local r1 = c1()
    local r2 = c2()
    local r3 = c3()
    c1(100)
    c3(300)
    local r4 = c1()
    local r5 = c2()
    local r6 = c3()
    if r1 ~= 10 or r2 ~= 20 or r3 ~= 30 then
        error('多实例独立 upvalue 初始值测试失败。')
    end
    if r4 ~= 100 or r5 ~= 20 or r6 ~= 300 then
        error('多实例独立 upvalue 修改后测试失败。')
    end
end

printf(13)

-- close 后闭包被再次赋值为新闭包，旧 upvalue 不受影响。
do
    local f
    do
        local x = 10
        f = function() return x end
    end  -- close，x 被固化到 f 的 nuCloseMap。
    local r1 = f()
    -- 重新给 f 赋值为新闭包。
    do
        local x = 20
        f = function() return x end
    end  -- 新闭包被 close。
    local r2 = f()
    if r1 ~= 10 or r2 ~= 20 then
        error('close 后闭包重赋值测试失败。')
    end
end

printf(14)

printf("测试通过了。")