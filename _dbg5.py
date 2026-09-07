p = r'E:\LuaRes\luatools\prod_dbg.lua'
with open(p, encoding='utf-8') as f:
    c = f.read()

old = "      res = {func(table.unpack(args, 1, nargs))}\n    end"
new = """      res = {func(table.unpack(args, 1, nargs))}
      if func == pcall then
        print('[DBG] a='..a..' b='..b..' c='..c..' top='..top..' nargs='..nargs..' #res='..#res)
      end
    end
    local nret = (c == 0) and #res or (c - 1)
    if c == 0 then top = a + nret end
    for i = 1, nret do R[a + i - 1] = res[i] end
    for i = nret + 1, top - a do R[a + i - 1] = nil end
    if func == pcall then
      print('[DBG] after: nret='..nret..' R[a]='..tostring(R[a])..' R[a+1]='..tostring(R[a+1]))
    end"""
# The old string includes the "end" that closes the if/elseif/else block.
# We need to be careful. Let me find the exact text.
print('searching...')
idx = c.find('res = {func(table.unpack(args, 1, nargs))}')
print('found at', idx)
print(repr(c[idx:idx+100]))
