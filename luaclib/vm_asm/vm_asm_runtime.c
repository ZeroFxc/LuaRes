/*
** vm_asm_runtime.c - Runtime helper generators
** Generates: frame setup, upvalue cells, closure, call/return, vararg,
**            for-loop helpers, coroutine yield/resume, pcall.
*/
#include "vm_asm.h"
#include <stdlib.h>
#include <string.h>

char *vm_gen_runtime(const char *R, const char *K, const char *UV,
                     const char *PC, const char *TOP, const char *PROTO,
                     int include_coroutine, int luajit_compat, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    vmbuf_puts(&b, "-- Runtime helpers (generated)\n");
    vmbuf_puts(&b,
        "  local function _pack(...)\n"
        "    return {n = select('#', ...), ...}\n"
        "  end\n"
        "  local _unpack = table.unpack or unpack\n");

    /* ---- LuaJIT compat: bitwise ops via bit library ---- */
    if (luajit_compat) {
        vmbuf_puts(&b,
            "  local _bit = bit or bit32 or (function() local ok,m=pcall(require,'bit'); return ok and m end)()\n"
            "  local function _band(a,b) return _bit.band(a,b) end\n"
            "  local function _bor(a,b) return _bit.bor(a,b) end\n"
            "  local function _bxor(a,b) return _bit.bxor(a,b) end\n"
            "  local function _shl(a,b) return _bit.lshift(a,b) end\n"
            "  local function _shr(a,b) return _bit.rshift(a,b) end\n"
            "  local function _bnot(a) return _bit.bnot(a) end\n"
            "  local function _idiv(a,b) return math.floor(a/b) end\n");
    }

    /* ---- upvalue cells ---- */
    vmbuf_printf(&b,
        "  local cells = {}\n"
        "  local function getuv(i)\n"
        "    local u = %s[i]\n"
        "    if not u then return nil end\n"
        "    if u.cell then\n"
        "      if u.cell.reg then return u.cell.reg[u.cell.idx] end\n"
        "      return u.cell.val\n"
        "    end\n"
        "    return u.val\n"
        "  end\n"
        "  local function setuv(i, v)\n"
        "    local u = %s[i]\n"
        "    if not u then u = {val = v}; %s[i] = u; return end\n"
        "    if u.cell then\n"
        "      if u.cell.reg then u.cell.reg[u.cell.idx] = v\n"
        "      else u.cell.val = v end\n"
        "    else u.val = v end\n"
        "  end\n"
        "  local function closeuv(lvl)\n"
        "    for idx, cell in pairs(cells) do\n"
        "      if idx >= lvl and cell.reg then\n"
        "        cell.val = cell.reg[cell.idx]\n"
        "        cell.reg = nil\n"
        "      end\n"
        "    end\n"
        "  end\n", UV, UV, UV);

    /* ---- closure wrapper: real function with proto field ---- */
    vmbuf_printf(&b,
        "  local function wrap(cl)\n"
        "    local f = function(...) return execute(cl, ...) end\n"
        "    closure_map[f] = cl\n"
        "    return f\n"
        "  end\n");

    /* ---- closure ---- */
    vmbuf_printf(&b,
        "  local function makeclosure(bx)\n"
        "    local factory = %s.p[bx + 1]\n"
        "    local uv_defs = %s.sub_uvs[bx + 1] or {}\n"
        "    local uv = {}\n"
        "    for i = 0, #uv_defs - 1 do\n"
        "      local d = uv_defs[i + 1]\n"
        "      if d.instack ~= 0 then\n"
        "        if not cells[d.idx] then cells[d.idx] = {reg = %s, idx = d.idx} end\n"
        "        uv[i] = {cell = cells[d.idx]}\n"

        "      else\n"
        "        uv[i] = {val = getuv(d.idx)}\n"
        "      end\n"
        "    end\n"
        "    return wrap(factory(uv))\n"
        "  end\n", PROTO, PROTO, R);

    /* ---- call / return ---- */
    vmbuf_printf(&b,
        "  local function docall(a, b, c)\n"
        "    local func = %s[a]\n"
        "    local nargs = (b == 0) and (%s - a - 1) or (b - 1)\n"
        "    local args = {}\n"
        "    for i = 1, nargs do args[i] = %s[a + i] end\n"
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
        "    if c == 0 then %s = a + nret end\n"
        "    for i = 1, nret do %s[a + i - 1] = res[i] end\n"
        "  end\n", R, TOP, R, TOP, R);

    vmbuf_printf(&b,
        "  local function dotailcall(a, b)\n"
        "    local func = %s[a]\n"
        "    local nargs = (b == 0) and (%s - a - 1) or (b - 1)\n"
        "    local args = {}\n"
        "    for i = 1, nargs do args[i] = %s[a + i] end\n"
        "    closeuv(0)\n"
        "    local vcl = closure_map[func]\n"
        "    if not vcl and type(func) == 'table' and func.proto then vcl = func end\n"
        "    if vcl then\n"
        "      return execute(vcl, _unpack(args, 1, nargs))\n"
        "    else\n"
        "      return func(_unpack(args, 1, nargs))\n"
        "    end\n"
        "  end\n", R, TOP, R);

    vmbuf_printf(&b,
        "  local function doreturn(a, b)\n"
        "    local nret = (b == 0) and (%s - a) or (b - 1)\n"
        "    closeuv(0)\n"
        "    local r = {}\n"
        "    for i = 1, nret do r[i] = %s[a + i - 1] end\n"
        "    return _unpack(r, 1, nret)\n"
        "  end\n", TOP, R);

    /* ---- vararg ---- */
    vmbuf_printf(&b,
        "  local function dovararg(a, b)\n"
        "    local nret = (b == 0) and (vararg.n or #vararg) or (b - 1)\n"
        "    if b == 0 then %s = a + nret end\n"
        "    for i = 1, nret do %s[a + i - 1] = vararg[i] end\n"
        "    for i = nret + 1, %s - a do %s[a + i - 1] = nil end\n"
        "  end\n", TOP, R, TOP, R);

    /* ---- setlist ---- */
    vmbuf_printf(&b,
        "  local function dosetlist(a, b, c)\n"
        "    local t = %s[a]\n"
        "    local n = (b == 0) and (%s - a - 1) or b\n"
        "    local base = (c - 1) * 50\n"
        "    for i = 1, n do t[base + i] = %s[a + i] end\n"
        "  end\n", R, TOP, R);

    /* ---- tforcall ---- */
    vmbuf_printf(&b,
        "  local function dotforcall(a, c)\n"
        "    local f = %s[a]; local s = %s[a + 1]; local var = %s[a + 2]\n"
        "    local res = _pack(f(s, var))\n"
        "    for i = 1, c do %s[a + 2 + i] = res[i] end\n"
        "  end\n", R, R, R, R);

    /* ---- coroutine support ---- */
    if (include_coroutine) {
        vmbuf_puts(&b,
            "  -- Coroutine: yield saves frame state, resume restores\n"
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
            "      -- restore and continue\n"
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
