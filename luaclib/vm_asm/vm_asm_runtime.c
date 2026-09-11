/*
** vm_asm_runtime.c - Runtime helper generators
** Generates: frame setup, upvalue cells, closure, call/return, vararg,
**            for-loop helpers, coroutine yield/resume, pcall.
*/
#include "vm_asm.h"
#include <stdlib.h>
#include <string.h>

/* UV debug macro: compile with -DVM_ASM_UV_DEBUG=1 to enable */
#ifndef VM_ASM_UV_DEBUG
#define VM_ASM_UV_DEBUG 0
#endif

char *vm_gen_runtime(const char *R, const char *K, const char *UV,
                     const char *PC, const char *TOP, const char *PROTO,
                     int include_coroutine, int luajit_compat, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    vmbuf_puts(&b,
        "  local function _pack(...)\n"
        "    return {n = select('#', ...), ...}\n"
        "  end\n"
        "  local _unpack = table.unpack or unpack\n");

    /* ---- LuaJIT compat: bitwise ops via bit library ---- */
    if (luajit_compat) {
        vmbuf_puts(&b,
            "  local _bit = {}\n"
            "  local _src = bit or bit32\n"
            "  if not _src then local ok,m=pcall(require,'bit'); if ok and m then _src=m end end\n"
            "  if not _src then local ok,m=pcall(require,'bit32'); if ok and m then _src=m end end\n"
            "  if _src then for _,fn in ipairs({'band','bor','bxor','lshift','rshift','bnot'}) do if _src[fn] then _bit[fn]=_src[fn] end end end\n"
            "  local function _to32(x) return math.floor(x % 4294967296) end\n"
            "  if not _bit.band then function _bit.band(a,b) a=_to32(a);b=_to32(b);local r=0;local p=1;while a>0 or b>0 do if a%2==1 and b%2==1 then r=r+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end;return r end end\n"
            "  if not _bit.bor then function _bit.bor(a,b) a=_to32(a);b=_to32(b);local r=0;local p=1;while a>0 or b>0 do if a%2==1 or b%2==1 then r=r+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end;return r end end\n"
            "  if not _bit.bxor then function _bit.bxor(a,b) a=_to32(a);b=_to32(b);local r=0;local p=1;while a>0 or b>0 do if (a%2)~=(b%2) then r=r+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end;return r end end\n"
            "  if not _bit.lshift then function _bit.lshift(a,b) a=_to32(a);b=math.floor(b);return _to32(a*(2^b)) end end\n"
            "  if not _bit.rshift then function _bit.rshift(a,b) a=_to32(a);b=math.floor(b);return math.floor(a/(2^b)) end end\n"
            "  if not _bit.bnot then function _bit.bnot(a) a=_to32(a);return _to32(4294967295-a) end end\n"
            "  local function _s32(x) x=x%4294967296; if x>=2147483648 then return x-4294967296 end; return x end\n"
            "  local function _band(a,b) return _s32(_bit.band(a,b)) end\n"
            "  local function _bor(a,b) return _s32(_bit.bor(a,b)) end\n"
            "  local function _bxor(a,b) return _s32(_bit.bxor(a,b)) end\n"
            "  local function _shl(a,b) return _s32(_bit.lshift(a,b)) end\n"
            "  local function _shr(a,b) return _bit.rshift(a,b) end\n"
            "  local function _bnot(a) return _s32(_bit.bnot(a)) end\n"
            "  local function _idiv(a,b) return math.floor(a/b) end\n");
    }

    /* ---- upvalue cells ---- */
    vmbuf_printf(&b,
        "  local cells = {}\n"
        "  local function getuv(i, UVN)\n"
        "    local u = UVN[i]\n"
        "    if not u then return nil end\n"
        "    if u.cell then\n"
        "      if u.cell.reg then return u.cell.reg[u.cell.idx] end\n"
        "      return u.cell.val\n"
        "    end\n"
        "    return u.val\n"
        "  end\n"
        "  local function setuv(i, v, UVN)\n"
        "    local u = UVN[i]\n"
        "    if not u then u = {val = v}; UVN[i] = u; return end\n"
        "    if u.cell then\n"
        "      if u.cell.reg then u.cell.reg[u.cell.idx] = v\n"
        "      else u.cell.val = v end\n"
        "    else u.val = v end\n"
        "  end\n"
        "  local function closeuv(lvl, R)\n"
        "    local _cs = cells[R] or {}\n"
        "    for idx, cell in pairs(_cs) do\n"
        "      if idx >= lvl and cell.reg then\n"
        "        cell.val = cell.reg[cell.idx]\n"
        "        cell.reg = nil\n"
        "      end\n"
        "    end\n"
        "  end\n");

    /* ---- closure wrapper: real function with proto field ---- */
    vmbuf_printf(&b,
        "  local function wrap(cl, execute)\n"
        "    local f = function(...) return execute(cl, ...) end\n"
        "    closure_map[f] = cl\n"
        "    return f\n"
        "  end\n");

    /* ---- closure ---- */
    vmbuf_printf(&b,
        "  local function makeclosure(bx, PROTO, R, UV, execute)\n"
        "    local factory = PROTO.p[bx + 1]\n"
        "    local uv_defs = PROTO.sub_uvs[bx + 1] or {}\n"
        "    local uv = {}\n"
        "    for i = 0, #uv_defs - 1 do\n"
        "      local d = uv_defs[i + 1]\n"
        "      if d.instack ~= 0 then\n"
        "        local _cs = cells[R]\n"
"        if not _cs then _cs = {}; cells[R] = _cs end\n"
"        local _c = _cs[d.idx]\n"
"        if not _c or not _c.reg then _c = {reg = R, idx = d.idx}; _cs[d.idx] = _c end\n"
        "        uv[i] = {cell = _c}\n"

        "      else\n"
        "        uv[i] = UV[d.idx] or {val = nil}\n"
        "      end\n"
        "    end\n"
        "    return wrap(factory(uv), execute)\n"
        "  end\n");

    /* ---- call / return ---- */
    vmbuf_printf(&b,
        "  local function docall(a, b, c, R, top, execute)\n"
        "    local func = R[a]\n"
        "    local nargs = (b == 0) and (top - a - 1) or (b - 1)\n"
        "    local args = {}\n"
        "    for i = 1, nargs do args[i] = R[a + i] end\n"
        "    local res\n"
        "    local vcl = closure_map[func]\n"
        "    if not vcl and type(func) == 'table' and func.proto then vcl = func end\n"
        "    if vcl then\n"
        "      res = _pack(execute(vcl, _unpack(args, 1, nargs)))\n"
        "    elseif type(func) == 'thread' then\n"
        "      res = _pack(coroutine.resume(func, _unpack(args, 1, nargs)))\n"
        "      if not res[1] then error(res[2], 0) end\n"
        "      table.remove(res, 1)\n"
        "    else\n"
        "      res = _pack(func(_unpack(args, 1, nargs)))\n"
        "    end\n"
        "    local nret = (c == 0) and res.n or (c - 1)\n"
        "    if c == 0 then top = a + nret end\n"
        "    for i = 1, nret do R[a + i - 1] = res[i] end\n"
        "    return top\n"
        "  end\n");

    vmbuf_printf(&b,
        "  local function dotailcall(a, b, R, top, execute)\n"
        "    local func = R[a]\n"
        "    local nargs = (b == 0) and (top - a - 1) or (b - 1)\n"
        "    local args = {}\n"
        "    for i = 1, nargs do args[i] = R[a + i] end\n"
        "    closeuv(0, R)\n"
        "    local vcl = closure_map[func]\n"
        "    if not vcl and type(func) == 'table' and func.proto then vcl = func end\n"
        "    if vcl then\n"
        "      return execute(vcl, _unpack(args, 1, nargs))\n"
        "    else\n"
        "      return func(_unpack(args, 1, nargs))\n"
        "    end\n"
        "  end\n");

    vmbuf_printf(&b,
        "  local function doreturn(a, b, top, R)\n"
        "    local nret = (b == 0) and (top - a) or (b - 1)\n"
        "    closeuv(0, R)\n"
        "    local r = {}\n"
        "    for i = 1, nret do r[i] = R[a + i - 1] end\n"
        "    return _unpack(r, 1, nret)\n"
        "  end\n");

    /* ---- vararg ---- */
    vmbuf_printf(&b,
        "  local function dovararg(a, b, top, R, vararg)\n"
        "    local nret = (b == 0) and (vararg.n or #vararg) or (b - 1)\n"
        "    if b == 0 then top = a + nret end\n"
        "    for i = 1, nret do R[a + i - 1] = vararg[i] end\n"
        "    for i = nret + 1, top - a do R[a + i - 1] = nil end\n"
        "    return top\n"
        "  end\n");

    /* ---- setlist ---- */
    vmbuf_printf(&b,
        "  local function dosetlist(a, b, c, R, top)\n"
        "    local t = R[a]\n"
        "    local n = (b == 0) and (top - a - 1) or b\n"
        "    local base = (c - 1) * 50\n"
        "    for i = 1, n do t[base + i] = R[a + i] end\n"
        "  end\n");

    /* ---- tforcall ---- */
    vmbuf_printf(&b,
        "  local function dotforcall(a, c, R)\n"
        "    local f = R[a]; local s = R[a + 1]; local var = R[a + 2]\n"
        "    local res = _pack(f(s, var))\n"
        "    for i = 1, c do R[a + 2 + i] = res[i] end\n"
        "  end\n");

    /* ---- coroutine support ---- */
    if (include_coroutine) {
        vmbuf_puts(&b,
            "  local co_state = nil\n"
            "  local function vm_yield(...)\n"
            "    if not co_state then error('attempt to yield from outside a coroutine', 2) end\n"
            "    co_state.pc = pc\n"
            "    co_state.R = R\n"
            "    co_state.top = top\n"
            "    co_state.cells = cells\n"
            "    co_state.retvals = _pack(...)\n"
            "    error('__VM_YIELD__', 0)\n"
            "  end\n"
            "  local function vm_resume(co, ...)\n"
            "    local args = {...}\n"
            "    if co.status == 'suspended' then\n"
            "      co.frame.pc = co.frame.pc\n"
            "      local ok, err = pcall(function()\n"
            "        execute_restore(co.frame, args)\n"
            "      end)\n"
            "      if not ok then\n"
            "        if err == '__VM_YIELD__' then\n"
            "          return true, _unpack(co.frame.retvals, 1, co.frame.retvals.n)\n"
            "        end\n"
            "        return false, err\n"
            "      end\n"
            "      co.status = 'dead'\n"
            "      return true\n"
            "    end\n"
            "    return false, 'cannot resume ' .. co.status .. ' coroutine'\n"
            "  end\n");
    }

    return vmbuf_detach(&b, len);
}


