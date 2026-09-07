p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

old = """    for i = 1, nret do R[a + i - 1] = res[i] end
    for i = nret + 1, top - a do R[a + i - 1] = nil end"""

new = """    for i = 1, nret do
      R[a + i - 1] = res[i]
      if func == pcall then print('[DBG loop] i='..i..' res[i]='..tostring(res[i])..' R['..(a+i-1)..']='..tostring(R[a+i-1])..' R='..tostring(R)) end
    end
    for i = nret + 1, top - a do R[a + i - 1] = nil end"""

c = c.replace(old, new, 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('ok')
