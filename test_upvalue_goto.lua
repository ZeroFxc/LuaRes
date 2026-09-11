-- upvalue counters with goto (exact copy from testLuaClosure__.lua)
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

    print("up1:", up1, "up2:", up2)
    if up1 ~= 23 or up2 ~= 33 then
        print("UPVALUE GOTO TEST FAILED")
    else
        print("UPVALUE GOTO TEST PASSED")
    end
end

print("done")
