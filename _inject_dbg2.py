p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

# Remove old debug, add simpler debug
old = """    else
      if func == pcall then print('[DBG] pcall nargs='..nargs..' args='..table.concat({(function() local t={}; for i=1,nargs do t[i]=tostring(args[i]) end; return t end)()}, ',')) end
      res = {func(table.unpack(args, 1, nargs))}
      if func == pcall then print('[DBG] pcall returned #res='..#res..' [1]='..tostring(res[1])..' [2]='..tostring(res[2])) end
    end"""
new = """    else
      res = {func(table.unpack(args, 1, nargs))}
      if c > 0 and c < 5 then
        local dbg = {}
        for i = 1, nret do dbg[i] = tostring(res[i]) end
      end
    end"""
# Actually just add a simple print for all C function calls
c = c.replace(old, """    else
      res = {func(table.unpack(args, 1, nargs))}
      if nret > 0 and res[1] == nil and res[2] ~= nil then
        print('[DBG] func='..tostring(func)..' nargs='..nargs..' nret='..nret..' res[1]=nil res[2]='..tostring(res[2]))
      end
    end""", 1)
with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('debug injected v2')
