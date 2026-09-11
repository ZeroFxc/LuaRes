local luac=require('luac')
local antidec=require('forward.antidec')
local src='local a=1+2 local s="hello" return a..s'
local bc=string.dec(string.dump(load(src)))
local p=luac.undump(bc,false)
antidec.protect(p, {junk_constants=true})
local enc=luac.dump(p)
print('dump size:', #enc)
local f,err=load(enc)
print('load:', f~=nil, err)
if f then local ok,r=pcall(f) print('run:', ok, r) end
