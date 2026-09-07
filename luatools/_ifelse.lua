local function classify(x)
    if x > 0 then
        if x > 10 then
            return "big positive"
        else
            return "small positive"
        end
    elseif x < 0 then
        return "negative"
    else
        return "zero"
    end
end
print(classify(5))
print(classify(-3))
print(classify(0))
print(classify(15))
