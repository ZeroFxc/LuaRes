p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

# Add debug print before the C function call in docall
old = "    else\n      res = {func(table.unpack(args, 1, nargs))}\n    end"
new = """    else
      if func == pcall then print('[DBG] pcall nargs='..nargs..' args='..table.concat({(function() local t={}; for i=1,nargs do t[i]=tostring(args[i]) end; return t end)()}, ',')) end
      res = {func(table.unpack(args, 1, nargs))}
      if func == pcall then print('[DBG] pcall returned #res='..#res..' [1]='..tostring(res[1])..' [2]='..tostring(res[2])) end
    end"""
c = c.replace(old, new, 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('debug injected')
