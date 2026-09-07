p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

old = """      res = {func(table.unpack(args, 1, nargs))}
    end
    local nret = (c == 0) and #res or (c - 1)
    if c == 0 then top = a + nret end
    for i = 1, nret do R[a + i - 1] = res[i] end
    for i = nret + 1, top - a do R[a + i - 1] = nil end
  end"""

new = """      res = {func(table.unpack(args, 1, nargs))}
    end
    local nret = (c == 0) and #res or (c - 1)
    if c == 0 then top = a + nret end
    for i = 1, nret do R[a + i - 1] = res[i] end
    for i = nret + 1, top - a do R[a + i - 1] = nil end
    if func == pcall then
      print('[DBG] a='..a..' c='..c..' top='..top..' nret='..nret..' #res='..#res..' R[a]='..tostring(R[a])..' R[a+1]='..tostring(R[a+1]))
    end
  end"""

c = c.replace(old, new, 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('ok')
