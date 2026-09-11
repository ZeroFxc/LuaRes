local luac=require('luac')
local antidec=require('forward.antidec')
local src='local a=1+2 local s="hello" return a..s'
local bc=string.dec(string.dump(load(src)))

local function test(name, opts)
    local p=luac.undump(bc,false)
    antidec.protect(p, opts)
    local enc=luac.dump(p)
    local f,err=load(enc)
    local runres = "n/a"
    if f then local ok,r=pcall(f) runres = ok and tostring(r) or "RUNERR:"..tostring(r):sub(1,40) end
    print(string.format("%-25s load=%s run=%s", name, tostring(f~=nil), runres))
end

test("all-default", {})
test("poison_header only", {poison_header=true, strip_lineinfo=false, junk_source=false, junk_upvalues=false, junk_constants=false})
test("strip_lineinfo only", {poison_header=false, strip_lineinfo=true, junk_source=false, junk_upvalues=false, junk_constants=false})
test("junk_source only", {poison_header=false, strip_lineinfo=false, junk_source=true, junk_upvalues=false, junk_constants=false})
test("junk_upvalues only", {poison_header=false, strip_lineinfo=false, junk_source=false, junk_upvalues=true, junk_constants=false})
test("junk_constants only", {poison_header=false, strip_lineinfo=false, junk_source=false, junk_upvalues=false, junk_constants=true})
test("no junk_upvalues", {junk_upvalues=false, junk_constants=true})
test("no poison_header", {poison_header=false, junk_constants=true})
