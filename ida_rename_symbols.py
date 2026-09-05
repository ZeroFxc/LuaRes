# AndLua libluajava.so 符号恢复脚本
# 在 IDA 中: File -> Script file -> 选择此文件
# 或 Shift+F2 粘贴运行

import ida_funcs
import ida_name

# 符号映射表: (地址, 函数名)
symbols = [
    # luajava 核心函数 (从 sub_* 恢复)
    (0xcfcc, "luaJavaFunctionCall"),
    (0xd0f4, "gc"),
    (0xd1f0, "javaToString"),
    (0x10688, "javaBindClass"),
    (0x10814, "javaNew"),
    (0xf5f8, "luajava_bindClass"),
    (0xff24, "objectIndex"),
    (0x10330, "objectNewIndex"),
    # lvm.c
    (0x39964, "luaV_execute"),
    (0x39350, "luaV_concat"),
    (0x39668, "luaV_objlen"),
    (0x387c0, "luaV_gettable"),
    (0x388f8, "luaV_settable"),
    (0x385D8, "luaV_tonumber_"),
    # ldo.c
    (0x1B488, "luaD_throw"),
    (0x1BA88, "luaD_precall"),
    (0x1BFF8, "luaD_poscall"),
    (0x1c1b8, "luaD_call"),
    (0x1c238, "luaD_callnoyield"),
    (0x1cad8, "f_parser"),
    (0x1eaa0, "luaD_throw2"),
    (0x1c590, "lua_resume"),
    (0x1b570, "luaD_rawrunprotected"),
    (0x1b60c, "luaD_reallocstack"),
    (0x1b930, "luaD_growstack"),
    # lundump.c - 双路径
    (0x32284, "luaU_undump"),
    (0x32D38, "luaU_undump2"),
    (0x32bf0, "undump1_error"),
    (0x336a4, "undump2_error"),
    (0x325e0, "LoadFunction"),
    (0x33094, "LoadFunction2"),
    (0x336dc, "LoadString2"),
    # lfunc.c
    (0x32C28, "luaF_newproto"),
    (0x1d66c, "luaF_newCclosure"),
    (0x1d6d4, "luaF_newLclosure"),
    (0x1d974, "luaF_freeproto"),
    # lgc.c
    (0x1E950, "luaC_fullgc"),
    (0x1E7E8, "luaC_checkGC"),
    (0x1DC68, "luaC_newobj"),
    (0x2aa30, "luaC_setdebt"),
    (0x1f474, "propagatemark"),
    (0x1e0a4, "sweepstep"),
    (0x1ec40, "atomic"),
    (0x1DC40, "luaC_fix"),
    # ltm.c
    (0x31CD0, "luaT_init"),
    (0x31D34, "luaT_gettm"),
    # lstate.c
    (0x2b148, "lua_close"),
    (0x2af68, "luaE_freeCI"),
    # andlua 扩展
    (0x1d464, "andlua_encrypt_string"),
    # ltable.c
    (0x2FBF8, "luaH_new"),
    (0x2F650, "luaH_resize"),
    (0x2fcb4, "luaH_set"),
    (0x2fa90, "luaH_getint"),
    (0x2fb68, "luaH_get"),
    (0x2fc3c, "luaH_free"),
    (0x2f4c0, "luaH_next"),
    (0x2F990, "setnodevector"),
    (0x2FBCC, "luaH_resizearray"),
    (0x302EC, "luaH_getshortstr"),
    (0x30438, "mainposition"),
    # lstring.c
    (0x2B4D0, "luaS_newlstr"),
    (0x2B730, "luaS_new"),
    (0x2b464, "luaS_resize"),
    # lobject.c
    (0x24738, "luaO_tostring"),
    (0x24820, "luaO_pushfstring"),
    (0x2403c, "luaO_arith"),
    (0x24cb0, "lua_pushvfstring"),
    (0x1aac8, "luaG_typeerror"),
    (0x1AC38, "varinfo"),
    (0x1AD64, "luaG_concaterror"),
    (0x1AD8C, "luaG_opinterror"),
    (0x1adec, "luaG_tointerror"),
    (0x1ae58, "luaG_compareerror"),
    (0x1ab14, "luaG_runerror"),
    (0x1a0d8, "luaB_resume"),
    (0x1afb0, "luaD_poscall2"),
    # ldebug.c
    (0x190c8, "hookf"),
    (0x193e0, "lua_getinfo"),
    (0x19a80, "lua_getupvalue"),
    (0x19b94, "lua_setupvalue"),
    (0x19080, "luaB_getuservalue"),
    (0x19ff0, "luaB_setuservalue"),
    (0x1927c, "luaB_getlocal"),
    (0x19320, "luaB_setlocal"),
    # lstrlib.c
    (0x20b1c, "str_format"),
    (0x2bf90, "str_format2"),
    (0x2c7b4, "str_gsub"),
    (0x2e048, "match"),
    (0x2eb68, "check_capture"),
    (0x2d190, "str_pack"),
    (0x2d760, "str_packsize"),
    (0x2d87c, "str_rep"),
    (0x2DD14, "writer"),
    (0x2EF44, "gmatch_aux"),
    (0x2F030, "getdetails"),
    (0x2F158, "getoption"),
    (0x2ba64, "str_char"),
    (0x2b910, "str_byte"),
    (0x2dd30, "push_captures"),
    (0x2ec30, "push_captures2"),
    (0x3791c, "match_error"),
    (0x2bb58, "str_dump"),
    (0x2cce8, "str_lower"),
    (0x2d0d4, "str_upper"),
    # lutf8lib.c
    (0x3646c, "Lutf8_gsub"),
    (0x372c4, "utf8_match"),
    # ltablib.c
    (0x308f4, "tconcat"),
    (0x31834, "sort"),
    (0x31C1C, "sort_comp"),
    (0x310e0, "unpack"),
    (0x312b8, "tmove"),
    (0x30f44, "tinsert"),
    (0x311cc, "tremove"),
    # lbaselib.c
    (0x17d80, "luaB_getmetatable"),
    (0x17dd8, "luaB_ipairs"),
    (0x18198, "luaB_next"),
    (0x181f0, "luaB_pairs"),
    (0x18434, "luaB_rawequal"),
    (0x18484, "luaB_rawlen"),
    (0x184E4, "luaB_rawget"),
    (0x18534, "luaB_rawset"),
    (0x18590, "luaB_select"),
    (0x18648, "luaB_setmetatable"),
    (0x186EC, "luaB_setmetamethod"),
    (0x1b11c, "luaB_load"),
    (0x17eec, "luaB_load2"),
    (0x17cf0, "luaB_module"),
    (0x17a94, "luaB_collectgarbage"),
    (0x182b8, "luaB_print"),
    (0x1881C, "luaB_tointeger"),
    (0x188EC, "luaB_tonumber"),
    (0x18AFC, "luaB_tostring"),
    (0x18b34, "luaB_type"),
    (0x1821c, "luaB_pcall"),
    (0x18C5C, "dofilecont"),
    (0x18C74, "pairsmeta"),
    (0x18D28, "ipairsaux"),
    (0x18bac, "luaB_xpcall"),
    (0x18E4C, "finishpcall"),
    (0x18ef4, "luaB_debug"),
    # lauxlib.c
    (0x17878, "luaL_panic"),
    (0x15ab0, "luaL_buffinit"),
    (0x22628, "luaL_error"),
    (0x22874, "luaL_error2"),
    # lmem.c
    (0x22a18, "luaM_toobig"),
    # loadlib.c
    (0x23370, "findloader"),
    (0x2384c, "luaL_requiref"),
    (0x23bc8, "searchpath"),
    (0x231c0, "searchpath2"),
    (0x23618, "searchpath3"),
    # lcorolib.c
    (0x3f854, "auxresume"),
    (0x3f5bc, "luaB_cocreate"),
    (0x3f69c, "luaB_costatus"),
    # llex.c
    (0x33e60, "llex"),
    (0x3fd74, "llex2"),
    (0x3596c, "luaX_next"),
    (0x41cf8, "read_numeral"),
    (0x41950, "read_long_string"),
    # lparser.c
    (0x25B60, "luaY_parser"),
    (0x18d80, "enterlevel"),
    (0x274cc, "error_expected"),
    (0x27c04, "luaX_syntaxerror"),
    (0x41714, "checklimit"),
    (0x276d8, "check"),
    (0x26700, "parser_func"),
    (0x27a78, "parser_func2"),
    (0x28920, "parser_goto"),
    (0x28c60, "parser_goto2"),
    (0x2a888, "parser_args"),
    # lcode.c
    (0x3e6bc, "luaK_exp2anyreg"),
    (0x3e0f0, "luaK_checkstack"),
    (0x25fd0, "registerlocal"),
    (0x279a0, "registerproto"),
    # liolib.c
    (0x1fbec, "io_close"),
    (0x1fd58, "io_read"),
    (0x20748, "io_write"),
    (0x20974, "io_close2"),
    (0x218d4, "io_tostring"),
    (0x21934, "dir_close"),
    (0x21a38, "io_close3"),
    # lbitlib.c
    (0x32104, "b_and"),
    (0x3c6a0, "b_extract"),
    (0x3c850, "b_replace"),
    # loslib.c
    (0x25964, "os_date"),
    (0x203ac, "os_time"),
    (0x22cfc, "os_getenv"),
    (0x25780, "os_tmpname"),
    (0x2580c, "os_date_setfield"),
    # lmathlib.c
    (0x22040, "math_log"),
    (0x22538, "math_frexp"),
    (0x21f1c, "math_fmod"),
    (0x22234, "math_modf"),
    # loslib.c
    (0x204e0, "os_mkdir"),
    (0x20690, "os_dir"),
    # liolib.c
    (0x2080c, "io_open"),
    # loadlib.c
    (0x22df8, "package_gc"),
    (0x23050, "lookforfunc"),
    # andlua 扩展
    (0x1d464, "andlua_encrypt_string"),
    (0x1cf40, "andlua_DumpFunction"),
]

renamed = 0
skipped = 0

for ea, name in symbols:
    # 检查函数是否存在
    f = ida_funcs.get_func(ea)
    if f is None:
        print(f"[SKIP] {hex(ea)}: not a function")
        skipped += 1
        continue
    
    old_name = ida_funcs.get_func_name(ea)
    
    # 重命名
    result = ida_name.set_name(ea, name, ida_name.SN_NOWARN)
    if result:
        print(f"[OK] {hex(ea)}: {old_name} -> {name}")
        renamed += 1
    else:
        print(f"[FAIL] {hex(ea)}: {old_name} -> {name} (name may already exist)")
        skipped += 1

print(f"\nDone: {renamed} renamed, {skipped} skipped")