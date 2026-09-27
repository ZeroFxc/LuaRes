#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_luacapi_log.py
==================
给 luasafe 中所有 Lua C API 定义（LUA_API / LUALIB_API）自动注入调用日志。

对每个 API 函数，在函数体开头插入：
    { /* LUACAPI_LOG */
      luacapi_log_begin("lua_xxx");
      luacapi_log_state("L", L);
      ...
      luacapi_log_end();
    }
并在文件头部补 #include "luacapi_log.h"。

特性：
  - 幂等：已含 LUACAPI_LOG 标记的函数跳过，可反复运行。
  - 参数类型安全映射：lua_State* -> log_state（附带栈深度），
    char* -> log_str（NULL 安全、转义、截断），
    (char*, size_t) 非 NUL 结尾缓冲区 -> log_strn（lua_pushlstring / luaL_loadbufferx），
    函数指针/其他指针 -> log_ptr，整数 -> log_int/log_uint，浮点 -> log_num。
  - 未知类型会告警并跳过该参数，不会生成错误代码。

用法：python tools/gen_luacapi_log.py
"""

import os
import re
import sys

ROOT = r"E:\LuaRes"
FILES = ["lapi.c", "ldo.c", "lstate.c", "ldebug.c", "lauxlib.c", "linit.c",
         "lvm.c"]

GROUPS = {"lapi.c": "lapi", "ldo.c": "ldo", "lstate.c": "lstate",
          "ldebug.c": "ldebug", "lauxlib.c": "lauxlib", "linit.c": "linit",
          "lvm.c": "lvm"}

API_RE = re.compile(r'^(LUA_API|LUALIB_API)\b(.*)$')
# lvm.c 内部函数（luaV_*）无 LUA_API 前缀
LVM_RE = re.compile(r'^((?:void|int|lua_Integer)\s+luaV_\w+\s*\()')

FUNC_PTR_TYPES = ("lua_CFunction", "lua_Alloc", "lua_Reader", "lua_Writer",
                  "lua_Hook", "lua_KFunction")

# 需要按长度截断的 (函数名, 参数名) -> 长度参数名（缓冲区可能不带 NUL）
STRN_PARAMS = {
    ("lua_pushlstring", "s"): "len",
    ("luaL_loadbufferx", "buff"): "size",
    ("luaL_andlua_dec", "buff"): "size",
    ("luaL_addlstring", "s"): "l",
}


def emit_arg(fn, name, ptype):
    """按参数类型生成对应的日志调用；返回 None 表示跳过。"""
    t = ptype.strip()
    if t in ("", "...", "void"):
        return None
    # 函数指针 typedef（无 *）
    if t in FUNC_PTR_TYPES:
        return 'luacapi_log_ptr("%s", (const void *)(%s))' % (name, name)
    if t.endswith("*"):
        if "lua_State" in t:
            return 'luacapi_log_state("%s", %s)' % (name, name)
        if "char" in t:
            if (fn, name) in STRN_PARAMS:
                lenp = STRN_PARAMS[(fn, name)]
                return 'luacapi_log_strn("%s", %s, (size_t)(%s))' % (name, name, lenp)
            return 'luacapi_log_str("%s", %s)' % (name, name)
        return 'luacapi_log_ptr("%s", (const void *)(%s))' % (name, name)
    if "lua_Number" in t:
        return 'luacapi_log_num("%s", (double)(%s))' % (name, name)
    if t in ("StkId",):  # TValue* 的 typedef
        return 'luacapi_log_ptr("%s", (const void *)(%s))' % (name, name)
    if "va_list" in t:
        # va_list 在 arm64 下是结构体类型，不能强转 void*；只打标记
        return 'luacapi_log_str("%s", "(va_list)")' % (name,)
    if "size_t" in t or "unsigned" in t or "Instruction" in t:
        return 'luacapi_log_uint("%s", (unsigned long long)(%s))' % (name, name)
    if ("lua_Integer" in t or "lua_KContext" in t or "ptrdiff_t" in t
            or "long" in t or "int" in t or "short" in t or "char" in t):
        return 'luacapi_log_int("%s", (long long)(%s))' % (name, name)
    return None  # 未知类型


DECL_RE = re.compile(r'^(.*?)([A-Za-z_]\w*)\s*$')


def parse_params(fn, param_text):
    """
    解析参数列表文本，返回 [(name, type), ...]。

    兼容 luasafe 的声明风格：
      lua_State *L    -> type='lua_State *'  name='L'
      const char *s   -> type='const char *' name='s'
      int n           -> type='int'          name='n'
      void **ud       -> type='void **'      name='ud'
    """
    out = []
    parts = [p.strip() for p in param_text.split(",")]
    for p in parts:
        if p in ("", "...", "void"):
            continue
        m = DECL_RE.match(p)
        if not m:
            continue
        ptype = m.group(1).strip()
        name = m.group(2)
        out.append((name, ptype))
    return out


def detect_eol(text):
    """检测文件主导换行符，保持原文件风格。"""
    crlf = text.count("\r\n")
    lf = text.count("\n")
    return "\r\n" if crlf >= lf and crlf > 0 else "\n"


def normalize_eol(text, eol):
    return text.replace("\r\n", "\n").replace("\n", eol)


def instrument_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    eol = detect_eol("".join(lines))

    out_lines = []
    i = 0
    n_total = 0
    n_added = 0
    n_skipped = 0
    warnings = []
    base = os.path.basename(path)
    group = GROUPS.get(base, base[:-2] if base.endswith(".c") else base)
    use_lvm = base == "lvm.c"

    while i < len(lines):
        line = lines[i]
        m = LVM_RE.match(line) if use_lvm else API_RE.match(line)
        if not m:
            out_lines.append(line)
            i += 1
            continue

        n_total += 1
        # 收集完整签名（可能跨多行），直到一行以 '{' 结尾
        sig_lines = [line]
        j = i
        while not sig_lines[-1].rstrip().endswith("{"):
            j += 1
            if j >= len(lines):
                warnings.append("%s:%d: 签名未找到函数体 '{'" % (path, i + 1))
                break
            sig_lines.append(lines[j])
        sig = " ".join(s.rstrip() for s in sig_lines)
        # 取函数名：第一个 '(' 之前的最后一个标识符
        paren = sig.find("(")
        if paren < 0:
            warnings.append("%s:%d: 未找到参数括号" % (path, i + 1))
            out_lines.extend(sig_lines)
            i = j + 1
            continue
        name_m = re.search(r'(\w+)\s*$', sig[:paren])
        fn = name_m.group(1) if name_m else "?"
        # 匹配右括号（统计括号深度）
        depth = 0
        k = paren
        while k < len(sig):
            if sig[k] == "(":
                depth += 1
            elif sig[k] == ")":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        param_text = sig[paren + 1:k]

        # 已插桩则跳过
        body_next = lines[j + 1] if j + 1 < len(lines) else ""
        if "LUACAPI_LOG" in body_next or "LUACAPI_LOG" in sig:
            n_skipped += 1
            out_lines.extend(sig_lines)
            i = j + 1
            continue

        # 生成参数日志
        args = []
        for name, ptype in parse_params(fn, param_text):
            call = emit_arg(fn, name, ptype)
            if call is None:
                warnings.append("%s:%d: %s 参数 %s (%s) 类型未识别，已跳过"
                                % (path, i + 1, fn, name, ptype))
            else:
                args.append(call)

        block = ['    luacapi_log_begin("%s", "%s");' % (group, fn)]
        block += ["    " + a + ";" for a in args]
        block.append("    luacapi_log_end();")

        indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
        ins = ["%s{ /* LUACAPI_LOG */\n" % indent] + \
              ["%s  %s\n" % (indent, b) for b in block] + \
              ["%s}\n" % indent]

        out_lines.extend(sig_lines)
        out_lines.extend(ins)
        n_added += 1
        i = j + 1

    text = "".join(out_lines)

    # 补 #include "luacapi_log.h"：紧跟 lprefix.h 之后（若存在），
    # 否则插到文件顶部第一个 include 块之后。
    # 注意：不能插到"最后一个 include"之后——文件中部可能有条件编译的 include
    # （如 lauxlib.c 里的 <sys/wait.h>），会破坏头文件可见性。
    if '#include "luacapi_log.h"' not in text:
        m = re.search(r'^#include "lprefix\.h".*$', text, re.M)
        if m:
            line_end = text.find("\n", m.start()) + 1
            text = (text[:line_end] +
                    '#include "luacapi_log.h"\n' + text[line_end:])
        else:
            inc_positions = [m.start() for m in re.finditer(r'^#include.*$', text, re.M)]
            if inc_positions:
                # 只考虑文件前 60 行内的 include（顶部 include 块）
                top_incs = [p for p in inc_positions if text.count("\n", 0, p) < 60]
                anchor = top_incs[-1] if top_incs else inc_positions[0]
                last_inc_end = text.find("\n", anchor) + 1
                text = (text[:last_inc_end] +
                        '\n#include "luacapi_log.h"\n' + text[last_inc_end:])
            else:
                text = '#include "luacapi_log.h"\n' + text

    text = normalize_eol(text, eol)

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)

    return n_total, n_added, n_skipped, warnings


def revert_file(path):
    """移除之前插入的 LUACAPI_LOG 插桩块与 #include（回滚用）。"""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    eol = detect_eol(text)

    # 移除插桩块：{ /* LUACAPI_LOG */ ... }
    text = re.sub(r'[ \t]*\{ /\* LUACAPI_LOG \*/\n(?:[ \t]*.*\n)*?[ \t]*\}\n', '', text)

    # 移除 include（可能带前导空行）
    text = re.sub(r'\n+#include "luacapi_log\.h"\n', '\n', text)
    text = text.replace('#include "luacapi_log.h"\n', '')

    text = normalize_eol(text, eol)

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return text.count("LUACAPI_LOG")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--revert":
        for f in FILES:
            p = os.path.join(ROOT, "luasafe", f)
            left = revert_file(p)
            print("[revert] %s 剩余标记=%d" % (f, left))
        return 0

    total_defs = 0
    total_added = 0
    total_skipped = 0
    for f in FILES:
        p = os.path.join(ROOT, "luasafe", f)
        n_total, n_added, n_skipped, warnings = instrument_file(p)
        total_defs += n_total
        total_added += n_added
        total_skipped += n_skipped
        print("[%s] 定义=%d 新增=%d 跳过=%d" % (f, n_total, n_added, n_skipped))
        for w in warnings:
            print("  WARN: " + w)
    print("----")
    print("合计: 定义=%d 新增=%d 跳过=%d" % (total_defs, total_added, total_skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
