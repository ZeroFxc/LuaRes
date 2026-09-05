# AndLua libluajava.so 符号映射表
# 目标: E:\LuaRes\anewluia\libluajava.so (md5=174d6bbb6f684072861e3549f9476cbf)
# 参考源码: E:\LuaRes\androlua\ (Lua 5.3.3) + E:\LuaRes\androluajava\luajava.c

## lvm.c - Lua 虚拟机

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x39964 | 10400 | sub_39964 | luaV_execute | 最大函数, while+switch opcode分发, 68KB反编译输出 |

## ldo.c - 函数调用与栈管理

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1B488 | 232 | sub_1B488 | luaD_throw | noreturn, _longjmp, 错误码6=LUA_ERRERR输出"error in error handling" |
| 0x1BA88 | 1392 | sub_1BA88 | luaD_precall | 被luaD_call调用, 返回0表示Lua函数(需调用luaV_execute) |
| 0x1BFF8 | 448 | sub_1BFF8 | luaD_poscall | 被luaD_precall调用, C函数返回后处理 |
| 0x1c1b8 | 128 | sub_1C1B8 | luaD_call | Ci深度++ → luaD_precall → luaV_execute → Ci深度-- |
| 0x1c238 | 152 | sub_1C238 | luaD_callnoyield | 类似luaD_call, 额外nny计数++/-- |
| 0x1c590 | 552 | sub_1C590 | (待确认) | 也调用luaV_execute, 无外部调用者, 可能是finishCcall或resume辅助 |

## lundump.c - 字节码加载 (andlua双路径)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x32284 | 1552 | sub_32284 | luaU_undump (undump1) | 检查"Lua"签名+版本0x53+格式0+6字节头, 标准0x1B格式 |
| 0x32D38 | 1552 | sub_32D38 | luaU_undump2 (undump2) | 和undump1对称, 处理0x1A/0x1C加密格式 |
| 0x32bf0 | 56 | sub_32BF0 | error (undump1) | noreturn, 输出"%s: %s precompiled chunk", 调用luaD_throw |
| 0x336a4 | 56 | sub_336A4 | error2 (undump2) | 和error对称, undump2专用 |
| 0x325e0 | 1552 | sub_325E0 | LoadFunction (undump1) | 读取Proto字段+code+constants+protos+upvalues+debug, 调用luaF_newproto |
| 0x33094 | 1552 | sub_33094 | LoadFunction2 (undump2) | 和LoadFunction对称, undump2专用 |
| 0x336dc | 1732 | sub_336DC | LoadString2 (undump2) | 加载字符串, 处理andlua字符串解密, SIMD优化, 调用luaZ_read和luaS_newlstr |

## lfunc.c - 函数操作

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x32C28 | 272 | sub_32C28 | luaF_newproto | 被LoadFunction调用, 创建Proto对象 |
| 0x1d66c | 104 | sub_1D66C | luaF_newCclosure (待确认) | 创建C闭包, tt=6=LUA_TFUNCTION, 初始化upvalues |
| 0x1d6d4 | 120 | sub_1D6D4 | luaF_newLclosure (待确认) | 创建Lua闭包, 分配upvalues |
| 0x1d974 | 188 | sub_1D974 | luaF_freeproto (待确认) | 释放Proto对象, 调用luaM_realloc_释放code/constants/upvalues/debug |

## lzio.c - IO 流

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3C2E4 | 待查 | sub_3C2E4 | luaZ_read | 被LoadFunction/luaU_undump调用读取字节 |

## lmem.c - 内存管理

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2297C | 待查 | sub_2297C | luaM_realloc_ | 被LoadFunction调用分配code内存 |

## lgc.c - 垃圾回收

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1E950 | 336 | sub_1E950 | luaC_fullgc | 被lua_gc的LUA_GCCOLLECT调用 |
| 0x1E7E8 | 360 | sub_1E7E8 | luaC_checkGC | 检查GCdebt, 被lua_createtable/lua_gc等多处调用 |
| 0x1DC68 | 80 | sub_1DC68 | luaC_newobj | 被luaH_new调用创建GCObject, tt=5=LUA_TTABLE |
| 0x2aa30 | 36 | sub_2AA30 | luaC_setdebt (待确认) | 设置GCdebt, 被lua_gc的LUA_GCRESTART/LUA_GCSTEP调用 |
| 0x1f474 | 440 | sub_1F474 | propagatemark (待确认) | 遍历GC对象链表, 标记白色/灰色/黑色对象 |
| 0x1e0a4 | 1860 | sub_1E0A4 | sweepstep (待确认) | 大函数, GC扫描阶段 |
| 0x1ec40 | 1812 | sub_1EC40 | atomic (待确认) | 大函数, GC原子阶段 |

## lstate.c - 状态管理

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2b148 | 196 | sub_2B148 | lua_close (待确认) | 释放所有资源, 调用free释放global_State |
| 0x2af68 | 480 | sub_2AF68 | luaE_freeCI (待确认) | 释放CallInfo链表 |

## ltable.c - 表操作

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2FBF8 | 68 | sub_2FBF8 | luaH_new | 创建空表, 调用luaC_newobj, 初始化Table字段 |
| 0x2F650 | 832 | sub_2F650 | luaH_resize (待确认) | 被lua_createtable调用调整表大小 |
| 0x2fcb4 | 1048 | sub_2FCB4 | luaH_set (待确认) | 设置表项, 处理"table index is nil"错误, 调用luaH_resize重新哈希 |
| 0x2fa90 | 216 | sub_2FA90 | luaH_getint (待确认) | 按整数索引查找表项 |
| 0x2fb68 | 100 | sub_2FB68 | luaH_get (待确认) | 获取表中的值, 如果不存在则调用luaH_set |
| 0x2fc3c | 120 | sub_2FC3C | luaH_free (待确认) | 释放表, 调用luaM_realloc_ |
| 0x30438 | 516 | sub_30438 | mainposition (待确认) | 表的主位置函数, 被luaH_get调用 |

## lstring.c - 字符串操作

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2B4D0 | 464 | sub_2B4D0 | luaS_newlstr | 短字符串<=40字节哈希+缓存查找, 被lua_pushlstring调用 |
| 0x2B730 | 196 | sub_2B730 | luaS_new (待确认) | 获取空字符串, 被lua_pushlstring调用 |
| 0x2b464 | 108 | sub_2B464 | luaS_resize (待确认) | 调整字符串哈希表大小 |

## lobject.c - 对象操作

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x24738 | 232 | sub_24738 | luaO_tostring | 数字转字符串: 整数%lld, 浮点数%.14g+.0后缀, 调用luaS_newlstr |
| 0x24820 | 1168 | sub_24820 | luaO_pushfstring (待确认) | "invalid option '%c' to 'lua_pushfstring'" |
| 0x2403c | 728 | sub_2403C | luaO_arith (待确认) | 算术运算, 处理double和整数 |
| 0x24cb0 | 152 | sub_24CB0 | lua_pushvfstring (待确认) | 可变参数版本, 调用luaO_pushfstring |

## ldebug.c - 调试

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x190c8 | 436 | sub_190C8 | hookf (待确认) | "external hook" |
| 0x193e0 | 1088 | sub_193E0 | lua_getinfo (待确认) | "invalid option" |
| 0x19a80 | 276 | sub_19A80 | lua_getupvalue (待确认) | "invalid upvalue index" |
| 0x19b94 | 128 | sub_19B94 | lua_setupvalue (待确认) | "invalid upvalue index" |
| 0x19080 | 72 | sub_19080 | luaB_getuservalue (待确认) | 获取userdata的uservalue |
| 0x19ff0 | 96 | sub_19FF0 | luaB_setuservalue (待确认) | 设置userdata的uservalue, 检查"nil or table expected" |
| 0x1927c | 164 | sub_1927C | luaB_getlocal (待确认) | 获取局部变量, 调用lua_getstack/lua_getinfo/lua_getlocal |
| 0x19320 | 192 | sub_19320 | luaB_setlocal (待确认) | 设置局部变量, 调用lua_getstack/lua_getinfo/lua_setlocal |

## lstrlib.c - 字符串库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x20b1c | 1840 | sub_20B1C | str_format (待确认) | "invalid format" |
| 0x2bf90 | 1756 | sub_2BF90 | str_format (待确认) | "invalid option '%c' to 'format'" / "invalid format" |
| 0x2c7b4 | 1236 | sub_2C7B4 | str_gsub (待确认) | "invalid replacement value" / "invalid use of '%c'" |
| 0x2e048 | 2604 | sub_2E048 | match (待确认) | "invalid pattern capture" / "invalid capture index" |
| 0x2eb68 | 200 | sub_2EB68 | check_capture (待确认) | "invalid capture index" |

## lutf8lib.c - UTF8库 (andlua扩展)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3646c | 1120 | sub_3646C | Lutf8_gsub (待确认) | "invalid replacement value" / "invalid use of '%c'" |
| 0x372c4 | 1624 | sub_372C4 | utf8_match (待确认) | "invalid pattern capture" / "invalid capture index" |

## ltablib.c - 表库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x308f4 | 444 | sub_308F4 | tconcat (待确认) | "invalid value at index" |
| 0x31834 | 1000 | sub_31834 | sort (待确认) | "invalid order function for sorting" |

## lbaselib.c - 基础库 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1b11c | 876 | sub_1B11C | luaB_load (待确认) | "global" / "constant" |
| 0x17eec | 388 | sub_17EEC | luaB_load2 (待确认) | 处理load函数, 调用lua_load/luaL_loadbufferx, 支持upvalue设置 |
| 0x17cf0 | 144 | sub_17CF0 | luaB_module (待确认) | 处理module函数, 调用luaL_findtable |
| 0x17a94 | 604 | sub_17A94 | luaB_collectgarbage (待确认) | "collect" / "restart" |
| 0x182b8 | 380 | sub_182B8 | luaB_print (待确认) | "'tostring' must return a string to 'print'" |
| 0x18484 | 96 | sub_18484 | luaB_tostring (待确认) | "table or string expected" |
| 0x18b34 | 120 | sub_18B34 | luaB_tonumber (待确认) | "value expected" |
| 0x1821c | 156 | sub_1821C | luaB_pcall (待确认) | 保护调用, 调用lua_pcallk |
| 0x18bac | 176 | sub_18BAC | luaB_xpcall (待确认) | 保护调用, 支持错误处理函数, 调用lua_pcallk |
| 0x18ef4 | 396 | sub_18EF4 | luaB_debug (待确认) | 调试交互, 显示"lua_debug> "提示符, 读取并执行命令 |

## lauxlib.c - 辅助库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x17878 | 80 | sub_17878 | luaL_panic (待确认) | "PANIC: unprotected error in call to Lua API" |
| 0x15ab0 | 188 | sub_15AB0 | luaL_buffinit (待确认) | "not enough memory for buffer allocation" |
| 0x22628 | 440 | sub_22628 | luaL_error (待确认) | "wrong number of arguments" |
| 0x22874 | 264 | sub_22874 | luaL_error2 (待确认) | "too many %s (limit is %d)" |

## lvm.c / lobject.c - 错误处理

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1aac8 | 76 | sub_1AAC8 | luaG_typeerror (待确认) | "attempt to %s a %s value" |
| 0x1adec | 108 | sub_1ADEC | luaG_tointerror (待确认) | "number has no integer representation" |
| 0x1ae58 | 108 | sub_1AE58 | luaG_compareerror (待确认) | "attempt to compare two %s values" |
| 0x1ab14 | 292 | sub_1AB14 | luaG_runerror (待确认) | 运行时错误, 可变参数版本, 调用luaO_pushfstring |
| 0x1a0d8 | 200 | sub_1A0D8 | luaB_resume (待确认) | 恢复协程, 检查thread类型 |
| 0x1afb0 | 364 | sub_1AFB0 | luaD_poscall2 (待确认) | 处理调用返回, 调整栈 |

## ldo.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1eaa0 | 400 | sub_1EAA0 | luaD_throw2 (待确认) | "no message" |

## loadlib.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x231c0 | 432 | sub_231C0 | searchpath2 (待确认) | "no file '%s'" |
| 0x23618 | 364 | sub_23618 | searchpath3 (待确认) | "no module '%s' in file '%s'" |

## lstrlib.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2ba64 | 244 | sub_2BA64 | str_char (待确认) | "value out of range" |
| 0x2dd30 | 792 | sub_2DD30 | push_captures (待确认) | "too many captures" |
| 0x2ec30 | 788 | sub_2EC30 | push_captures2 (待确认) | "too many captures" |
| 0x3791c | 280 | sub_3791C | match_error (待确认) | "malformed pattern" |
| 0x2bb58 | 1072 | sub_2BB58 | str_dump (已确认) | string.dump, 调用lua_dump→deflate压缩→XOR加密(0x1C)→base64编码 |
| 0x2cce8 | 188 | sub_2CCE8 | str_lower (待确认) | 转换为小写, 调用tolower |
| 0x2d0d4 | 188 | sub_2D0D4 | str_upper (待确认) | 转换为大写, 调用toupper |

## ltablib.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x30f44 | 256 | sub_30F44 | tinsert (待确认) | "position out of bounds" / "wrong number of arguments to 'insert'" |
| 0x311cc | 236 | sub_311CC | tremove (待确认) | "position out of bounds" |

## llex.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x41cf8 | 1140 | sub_41CF8 | read_numeral (待确认) | "malformed number" |
| 0x41950 | 936 | sub_41950 | read_long_string (待确认) | 读取长字符串/注释, 处理[[...]]语法 |

## lmathlib.c - 数学库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x22040 | 156 | sub_22040 | math_log (待确认) | 调用log, 支持两个参数log(x)和log(x,base) |
| 0x22538 | 108 | sub_22538 | math_frexp (待确认) | 调用frexp, 返回两个值 |
| 0x21f1c | 220 | sub_21F1C | math_fmod (待确认) | 取模运算, 支持整数和浮点数, 调用fmod |
| 0x22234 | 184 | sub_22234 | math_modf (待确认) | 处理整数和浮点数, 调用modf |

## loslib.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x25964 | 244 | sub_25964 | os_date (待确认) | "field '%s' missing in date table" |
| 0x203ac | 308 | sub_203AC | os_time (待确认) | "atime" / "ctime" / "mtime" |
| 0x22cfc | 252 | sub_22CFC | os_getenv (待确认) | 调用getenv, 检查LUA_NOENV |
| 0x25780 | 140 | sub_25780 | os_tmpname (待确认) | 创建临时文件名, "/tmp/lua_XXXXXX" |
| 0x2580c | 344 | sub_2580C | os_date_setfield (待确认) | 设置日期表字段, "sec"/"min"/"hour"等 |
| 0x204e0 | 116 | sub_204E0 | os_mkdir (待确认) | 创建目录, 调用mkdir |
| 0x20690 | 184 | sub_20690 | os_dir (待确认) | 遍历目录, 调用opendir/readdir |
| 0x2080c | 156 | sub_2080C | io_open (待确认) | 打开文件, 创建userdata |

## loadlib.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x231c0 | 432 | sub_231C0 | searchpath2 (待确认) | "no file '%s'" |
| 0x23618 | 364 | sub_23618 | searchpath3 (待确认) | "no module '%s' in file '%s'" |
| 0x22df8 | 104 | sub_22DF8 | package_gc (待确认) | 调用dlclose卸载库 |
| 0x23050 | 368 | sub_23050 | lookforfunc (待确认) | 加载动态库, 调用dlopen/dlsym |

## lgc.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1f474 | 440 | sub_1F474 | propagatemark (待确认) | 遍历GC对象链表, 标记白色/灰色/黑色对象 |
| 0x1e0a4 | 1860 | sub_1E0A4 | sweepstep (待确认) | 大函数, GC扫描阶段 |
| 0x1ec40 | 1812 | sub_1EC40 | atomic (待确认) | 大函数, GC原子阶段 |

## ldo.c - 续

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1c590 | 552 | sub_1C590 | lua_resume (待确认) | "cannot resume non-suspended coroutine" / "cannot resume dead coroutine" |
| 0x1b570 | 156 | sub_1B570 | luaD_rawrunprotected (待确认) | 设置jmp_buf, 调用setjmp, 执行受保护函数 |
| 0x1b60c | 304 | sub_1B60C | luaD_reallocstack (待确认) | 重新分配Lua栈 |
| 0x1b930 | 344 | sub_1B930 | luaD_growstack (待确认) | 增长Lua栈 |

## andlua 扩展 - 字符串加密/序列化

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1d464 | 468 | sub_1D464 | andlua_encrypt_string (待确认) | andlua字符串加密/解密算法, 递推密钥v6=(v3+v5+v6)%255 |
| 0x1cf40 | 1316 | sub_1CF40 | andlua_DumpFunction (待确认) | 递归序列化Proto, 调用andlua_encrypt_string加密字符串, 写入code/constants/upvalues/debug |

## lmem.c - 内存管理 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x22a18 | 20 | sub_22A18 | luaM_toobig (待确认) | "memory allocation error: block too big" |

## loadlib.c / lauxlib.c - 模块加载

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x23370 | 112 | sub_23370 | findloader (待确认) | "no field package.preload['%s']" |
| 0x2384c | 892 | sub_2384C | luaL_requiref (待确认) | "_PACKAGE" |
| 0x23bc8 | 608 | sub_23BC8 | searchpath (待确认) | "'package.searchers' must be a table" |

## lcorolib.c - 协程库 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3f5bc | 176 | sub_3F5BC | luaB_cocreate (待确认) | "thread expected" |
| 0x3f69c | 240 | sub_3F69C | luaB_costatus (待确认) | "thread expected" / "suspended" / "normal" |

## lstrlib.c - 字符串库 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x2d190 | 1488 | sub_2D190 | str_pack (待确认) | "string length does not fit in given size" |
| 0x2d760 | 284 | sub_2D760 | str_packsize (待确认) | "variable-length format" |
| 0x2d87c | 1176 | sub_2D87C | str_rep (待确认) | "too many results" |
| 0x2b910 | 340 | sub_2B910 | str_byte (待确认) | string.byte, 将字符串转换为字节序列 |

## lvm.c - 虚拟机 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x39350 | 792 | sub_39350 | luaV_concat (待确认) | "string length overflow" |
| 0x39668 | 452 | sub_39668 | luaV_objlen (待确认) | "get length of" |

## liolib.c - IO库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1fbec | 196 | sub_1FBEC | io_close (待确认) | "attempt to use a closed file" |
| 0x1fd58 | 256 | sub_1FD58 | io_read (待确认) | "attempt to use a closed file" |
| 0x20748 | 196 | sub_20748 | io_write (待确认) | "attempt to use a closed file" |
| 0x20974 | 424 | sub_20974 | io_close2 (待确认) | "file is already closed" / "too many arguments" |
| 0x218d4 | 96 | sub_218D4 | io_tostring (待确认) | "file (closed)" |
| 0x21934 | 128 | sub_21934 | dir_close (待确认) | "closed directory" |
| 0x21a38 | 84 | sub_21A38 | io_close3 (待确认) | "cannot close standard file" |

## lparser.c - 解析器 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x276d8 | 152 | sub_276D8 | check (待确认) | "%s expected (to close %s at line %d)" |
| 0x26700 | 2252 | sub_26700 | parser_func (待确认) | "<name> or '...' expected" / "too many %s" |
| 0x27a78 | 396 | sub_27A78 | parser_func2 (待确认) | "<name> or '...' expected" |
| 0x28920 | 436 | sub_28920 | parser_goto (待确认) | "labels/gotos" |
| 0x28c60 | 976 | sub_28C60 | parser_goto2 (待确认) | "labels/gotos" |
| 0x2a888 | 424 | sub_2A888 | parser_args (待确认) | "function arguments expected" |

## lbitlib.c - 位运算库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x32104 | 280 | sub_32104 | b_and (待确认) | "perform bitwise operation on" |
| 0x3c6a0 | 212 | sub_3C6A0 | b_extract (待确认) | "width must be positive" / "trying to access non-existent bits" |
| 0x3c850 | 256 | sub_3C850 | b_replace (待确认) | "width must be positive" / "trying to access non-existent bits" |

## loslib.c - OS库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x25964 | 244 | sub_25964 | os_date (待确认) | "field '%s' missing in date table" |
| 0x203ac | 308 | sub_203AC | os_time (待确认) | "atime" / "ctime" / "mtime" |

## ltm.c / lvm.c - 元表操作

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x387c0 | 312 | sub_387C0 | luaV_gettable (待确认) | "'__index' chain too long; possible loop" |
| 0x388f8 | 472 | sub_388F8 | luaV_settable (待确认) | "'__newindex' chain too long; possible loop" |

## llex.c - 词法分析 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3596c | 1348 | sub_3596C | luaX_next (待确认) | "number/string expected, got %s" |

## llex.c - 词法分析

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x33e60 | 6720 | sub_33E60 | llex (待确认) | "invalid escape sequence" / "invalid escape '%c'" |
| 0x3fd74 | 6520 | sub_3FD74 | llex2 (待确认) | "invalid escape sequence" / "invalid long string delimiter" |

## lparser.c - 解析器

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x18d80 | 204 | sub_18D80 | enterlevel (待确认) | "too many nested functions" |
| 0x274cc | 524 | sub_274CC | error_expected (待确认) | "unexpected symbol" |
| 0x27c04 | 3356 | sub_27C04 | luaX_syntaxerror (待确认) | "syntax error" |
| 0x41714 | 196 | sub_41714 | checklimit (待确认) | "chunk has too many lines" |

## lcode.c - 代码生成

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3e6bc | 908 | sub_3E6BC | luaK_exp2anyreg (待确认) | "function or expression needs too many registers" |
| 0x3e0f0 | 316 | sub_3E0F0 | luaK_checkstack (待确认) | "function or expression needs too many registers" |
| 0x25fd0 | 516 | sub_25FD0 | registerlocal (待确认) | 注册局部变量, 处理"local variables"限制 |
| 0x279a0 | 216 | sub_279A0 | registerproto (待确认) | 注册函数原型, 处理"functions"限制 |

## lcorolib.c - 协程库

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x3f854 | 252 | sub_3F854 | auxresume (待确认) | "too many arguments to resume" / "too many results to resume" |

## ltablib.c - 表库 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x310e0 | 236 | sub_310E0 | unpack (待确认) | "too many results to unpack" |
| 0x312b8 | 424 | sub_312B8 | tmove (待确认) | "too many elements to move" |

## ldo.c - 函数调用与栈管理 (续)

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x1cad8 | 312 | sub_1CAD8 | f_parser | 读首字节: 0x1A/0x1C→undump2, 0x1B→undump1, 其他→luaY_parser; 检查mode参数 |

## lparser.c - 解析器

| 地址 | 大小 | IDA原名 | 恢复名称 | 确认方式 |
|------|------|---------|----------|----------|
| 0x25B60 | 724 | sub_25B60 | luaY_parser | 被f_parser调用处理文本格式 |

## luajava 核心函数

| 地址 | 大小 | IDA原名 | 恢复名称 | 来源 | 确认方式 |
|------|------|---------|----------|------|----------|
| 0xb72c | 144 | checkEnv | checkEnv | luajava.c | 已有符号 |
| 0xb7bc | 4 | checkIndex | checkIndex | luajava.c | 已有符号 |
| 0xb7c0 | 84 | checkJavaObject | checkJavaObject | luajava.c | 已有符号 |
| 0xb814 | 200 | toJavaObject | toJavaObject | luajava.c | 已有符号 |
| 0xb8dc | 332 | checkError | checkError | luajava.c | 已有符号 |
| 0xba28 | 272 | javaOverride | javaOverride | luajava.c | 已有符号 |
| 0xbb38 | 224 | javaGetType | javaGetType | luajava.c | 已有符号 |
| 0xbc18 | 128 | isJavaObject | isJavaObject | luajava.c | 已有符号 |
| 0xbc98 | 360 | javaEquals | javaEquals | luajava.c | 已有符号 |
| 0xbe00 | 60 | javaGetContext | javaGetContext | luajava.c | 已有符号 |
| 0xbe3c | 360 | javaIsInstanceOf | javaIsInstanceOf | luajava.c | 已有符号 |
| 0xbfa4 | 116 | pushJavaObject | pushJavaObject | luajava.c | 已有符号 |
| 0xc018 | 124 | getEnvFromState | getEnvFromState | luajava.c | 已有符号 |
| 0xc094 | 188 | pushJNIEnv | pushJNIEnv | luajava.c | 已有符号 |
| 0xc150 | 2664 | luaopen_luajava | luaopen_luajava | luajava.c | 已有符号 |
| 0xcfcc | 296 | sub_CFCC | luaJavaFunctionCall | luajava.c:1461 | 反编译对比: 检查JavaFunction+CallIntMethod+__call元方法 |
| 0xd0f4 | 252 | sub_D0F4 | gc | luajava.c:768 | 反编译对比: 设置元表+CallStaticVoidMethod(javaGc)+__gc元方法 |
| 0xd1f0 | 224 | sub_D1F0 | javaToString | luajava.c:1179 | 反编译对比: CallStaticIntMethod(to_string)+luaL_tolstring+__tostring元方法 |
| 0x10688 | 144 | sub_10688 | javaBindClass (待确认) | luajava.c | 检查JavaObject, 调用CallStaticObjectMethod |
| 0x10814 | 296 | sub_10814 | javaNew (待确认) | luajava.c | 创建Java对象, 调用CallStaticObjectMethod |
| 0xf5f8 | 200 | sub_F5F8 | luajava_bindClass (待确认) | luajava.c | Lua注册版本, 检查参数数量, 调用CallStaticObjectMethod |
| 0xff24 | 1036 | sub_FF24 | objectIndex (待确认) | luajava.c | Java对象的__index元方法, 处理字段和方法访问, 缓存到表中 |

## C++ 运行时函数

| 地址 | 大小 | IDA原名 | 恢复名称 | 说明 |
|------|------|---------|----------|------|
| 0xa750 | 20 | sub_A750 | (thunk) | JUMPOUT(0), 跳转桩 |
| 0xb6fc | 24 | sub_B6FC | (cxx_terminate) | 调用 result(), C++终止处理 |
| 0xb714 | 24 | sub_B714 | (cxx_atexit) | __cxa_atexit 注册 |

## JNI 导出函数 (已有符号)

Java_com_luajava_LuaState__1* 系列均已有正确符号。

## 待分析

- objectIndex (luajava.c:500) - 在 IDA 中可能已被内联或命名不同
- callMethod (luajava.c:622) - 在 IDA 中可能已被内联
- objectNewIndex (luajava.c:674) - 在 IDA 中可能已被内联
- jclose (luajava.c:793)
- javaBindClass (luajava.c:822)
- createProxy (luajava.c:859)
- newArray (luajava.c:896)
- createArray (luajava.c:923)
- javaNew (luajava.c:962)
- javaNewInstance (luajava.c:1053)
- javaLoadLib (luajava.c:1108)
- asTable (luajava.c:1151)
- coding (luajava.c:1318)
- javaObjectLength (luajava.c:1284)
