/*
** luacapi_log_lua.c
** luacapi_log 的 Lua 绑定（luasafe 内置 log 库的脚本接口）
**
** Lua 侧用法（openlibs 自动注册，可直接 require 或使用全局表）：
**   local log = require("log")
*/

#include "lprefix.h"

#include "lua.h"
#include "lauxlib.h"

#include "luacapi_log.h"

static int l_log_set_dir (lua_State *L) {
  const char *dir = luaL_optstring(L, 1, NULL);
  luacapi_log_set_dir(dir);
  return 0;
}

static int l_log_set_file (lua_State *L) {
  const char *path = luaL_optstring(L, 1, NULL);
  luacapi_log_set_file(path);
  return 0;
}

static int l_log_set_enabled (lua_State *L) {
  int old = luacapi_log_enabled();
  luacapi_log_set_enabled(lua_toboolean(L, 1));
  lua_pushboolean(L, old);
  return 1;
}

static int l_log_set_group (lua_State *L) {
  const char *g = luaL_checkstring(L, 1);
  int on = lua_toboolean(L, 2);
  luacapi_log_set_group(g, on);
  return 0;
}

static int l_log_set_fn (lua_State *L) {
  const char *f = luaL_checkstring(L, 1);
  int on = lua_toboolean(L, 2);
  luacapi_log_set_fn(f, on);
  return 0;
}

static int l_log_flush (lua_State *L) {
  luacapi_log_flush();
  return 0;
}

static int l_log_close (lua_State *L) {
  luacapi_log_close();
  return 0;
}

static int l_log_log (lua_State *L) {
  luaL_Buffer b;
  int n = lua_gettop(L);
  int i;
  luaL_buffinit(L, &b);
  for (i = 1; i <= n; i++) {
    size_t len;
    const char *s = luaL_tolstring(L, i, &len);
    if (i > 1) luaL_addchar(&b, ' ');
    luaL_addlstring(&b, s, len);
    lua_pop(L, 1);  /* 弹出 tostring 结果，保持参数位置不变 */
  }
  luaL_pushresult(&b);
  luacapi_log_msg("%s", lua_tostring(L, -1));
  return 0;
}

static int l_log_help (lua_State *L) {
  lua_pushstring(L,
    "luacapi_log - Lua C API 调用日志库（luasafe 内置）\n"
    "\n"
    "用法：local log = require(\"log\")\n"
    "\n"
    "配置：\n"
    "  log.set_dir(dir)       输出目录（不存在则自动创建）；dir=nil 恢复默认\n"
    "  log.set_file(path)     直接指定日志文件路径（优先于 set_dir）\n"
    "  log.set_enabled(on)    总开关，返回旧状态\n"
    "  log.set_group(name,on) 按分组开关，返回旧状态\n"
    "  log.set_fn(fname,on)   按单个函数开关，返回旧状态\n"
    "  log.flush()            立即落盘\n"
    "  log.close()            落盘并关闭日志文件\n"
    "  log.log(...)           手动写一行日志（参数 tostring 后空格连接）\n"
    "  log.help()             本说明\n"
    "\n"
    "分组（set_group 的 name 参数）：\n"
    "  lapi lauxlib ldebug ldo lstate linit lvm call log\n"
    "  - lvm：虚拟机内部 luaV_* 函数（luaV_execute 等）\n"
    "  - call：LUA_CALL 函数调用事件\n"
    "  - log：手动 log() 写入的行\n"
    "\n"
    "函数级开关（set_fn 的 fname 参数）：\n"
    "  任意 Lua C API 函数名，如 \"lua_getglobal\"、\"lua_pushstring\"；\n"
    "  或特殊名 \"LUA_CALL\" 单独开关函数调用事件。\n"
    "  未单独设置过的函数跟随所属分组开关。\n"
    "\n"
    "输出目录默认值（宿主在运行任何 Lua 代码前固定日志位置）：\n"
    "  1) 编译时 -DLUACAPI_LOG_DIR_DEFAULT=\"\\\"/path\\\"\"\n"
    "  2) 进程环境变量 LUACAPI_LOG_DIR\n"
    "  3) 都未设置 → 当前工作目录 luacapi.log\n"
    "\n"
    "日志行格式：\n"
    "  [HH:MM:SS][tid=123] lua_getglobal(L=0x.. top=0 frm=2, name=\"print\")\n"
    "  [HH:MM:SS][tid=123] LUA_CALL name=\"print\" type=C nargs=1 frm=2\n"
    "  [HH:MM:SS][tid=123] $(msg=\"自定义标记\")\n"
    "  top=进入时 Lua 栈深度；frm=C 调用帧深度（1=宿主直接调，逐层递增）\n");
  return 1;
}

static const luaL_Reg luacapi_log_funcs[] = {
  {"set_dir", l_log_set_dir},
  {"set_file", l_log_set_file},
  {"set_enabled", l_log_set_enabled},
  {"set_group", l_log_set_group},
  {"set_fn", l_log_set_fn},
  {"flush", l_log_flush},
  {"close", l_log_close},
  {"log", l_log_log},
  {"help", l_log_help},
  {NULL, NULL}
};

LUAMOD_API int luaopen_log (lua_State *L) {
  luaL_newlib(L, luacapi_log_funcs);
  return 1;
}
