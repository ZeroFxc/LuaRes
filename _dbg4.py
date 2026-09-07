p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

old = "      res = {func(table.unpack(args, 1, nargs))}\n    end"
new = """      res = {func(table.unpack(args, 1, nargs))}
      if func == pcall then
        local parts = {}
        for i = 1, #res do parts[i] = tostring(res[i]) end
        print('[DBG pcall] #res='..#res..' vals='..table.concat(parts, '|'))
      end
    end"""
c = c.replace(old, new, 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('ok')
