-- Combined test (similar to Complex vararg/closure/tailcall/upvalue test)
do
    -- upvalue counters
    local function makeCounters()
        local counters = {}
        for i = 1, 3 do
            local count = 0
            counters[i] = function(inc)
                if inc then count = count + inc end
                return count
            end
        end
        return counters
    end

    local counters = makeCounters()
    counters[1](10)
    counters[1](13)
    local up1 = counters[1]()
    counters[2](20)
    counters[2](13)
    local up2 = counters[2]()

    -- vararg tests
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
    local function multi(a, b, c)
        return a, b, c
    end
    local function tailB0(...)
        return multi(...)
    end
    local t1, t2, t3 = tailB0(100, 200, 300)

    -- recursive tailcall
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

    print("up1:", up1, "up2:", up2)
    print("v1-v4:", v1, v2, v3, v4)
    print("v5:", v5, "v6-v7:", v6, v7)
    print("c1-c3:", c1, c2, c3)
    print("t1-t3:", t1, t2, t3)
    print("sum:", sum, "closureResult:", closureResult)

    if up1 ~= 23 or up2 ~= 33 or
       v1 ~= 3 or v2 ~= 10 or v3 ~= 20 or v4 ~= 30 or
       v5 ~= 100 or v6 ~= 10 or v7 ~= 20 or
       c1 ~= 1 or c2 ~= 2 or c3 ~= 3 or
       t1 ~= 100 or t2 ~= 200 or t3 ~= 300 or
       sum ~= 15 or closureResult ~= 12 then
        print("COMBINED TEST FAILED")
    else
        print("COMBINED TEST PASSED")
    end
end

print("done")
