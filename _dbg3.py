p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

old = "      res = {func(table.unpack(args, 1, nargs))}\n    end"
new = """      res = {func(table.unpack(args, 1, nargs))}
      if tostring(func):find('pcall') then print('[DBG] pcall res1='..tostring(res[1])..' res2='..tostring(res[2])..' #res='..#res) end
    end"""
c = c.replace(old, new, 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('ok')
