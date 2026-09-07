p = r"E:\LuaRes\luatools\vm_gen.lua"
with open(p, encoding="utf-8") as f:
    c = f.read()

# Add trace to GETTABLE
old = "    elseif op == 7 then  -- GETTABLE\n      R[a] = R[b][(c<256 and R[c] or K[c-255])]"
new = '''    elseif op == 7 then  -- GETTABLE
      if R[b] == nil then
        print(string.format("GETTABLE NIL: pc=%d a=%d b=%d c=%d R[b]=nil R[a]=%s", pc, a, b, c, tostring(R[a])))
        error("GETTABLE nil", 0)
      end
      R[a] = R[b][(c<256 and R[c] or K[c-255])]'''
c = c.replace(old, new)

with open(p, "w", encoding="utf-8") as f:
    f.write(c)
print("trace added")
