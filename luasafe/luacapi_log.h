/*
** luacapi_log.h
** Lua C API 调用日志库（luasafe 内置）
**
** 功能：
**   对 luasafe 中所有 Lua C API 函数（lua_* 与 luaL_*）自动注入调用日志，
**   记录每次调用的函数名、参数值与进入时的栈深度，供分析宿主程序/脚本
**   对 Lua C API 的使用情况（典型场景：lua2c / API 追踪 / 学习）。
**
** 平台：Windows(mingw/msvc) / Linux / Android(NDK) / WASM(emscripten)
**
** 用法（一般由宿主程序在启动时配置一次）：
**     luacapi_log_set_dir("/sdcard/luacapi");   // 指定输出目录（不存在则创建）
**     luacapi_log_set_file("/tmp/api.log");     // 或直接指定完整文件路径（优先）
**     luacapi_log_set_enabled(1);               // 开关，默认开（WASM 默认关）
**     ... 运行 Lua ...
**     luacapi_log_close();                      // 结束并关闭日志文件
**
** 日志行格式：
**     [HH:MM:SS][tid=123] lua_getglobal(L=0x7f.. top=0 frm=2, name="print")
**     top=进入函数时 Lua 栈深度；frm=当前 C 调用帧深度（1=宿主直接调，
**     脚本执行中逐层递增），两者结合可还原完整调用链。
**
** 若需在编译期彻底关闭（函数体全部为空实现，零开销），
** 编译时定义 LUACAPI_LOG_DISABLE 即可。
**
** 输出目录的默认值（供 VM 启动阶段使用，宿主可在运行任何 Lua 代码
** 前固定日志位置；优先级低于运行时 set_dir/set_file）：
**   1) 编译时 -DLUACAPI_LOG_DIR_DEFAULT="\"/data/.../files\"" 
**   2) 进程环境变量 LUACAPI_LOG_DIR
**   3) 都未设置 → 当前工作目录 luacapi.log
*/

#ifndef luacapi_log_h
#define luacapi_log_h

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct lua_State;
struct CallInfo;

/* ---- 配置接口 ---- */
void luacapi_log_set_enabled(int on);          /* 0/1 总开关 */
int  luacapi_log_enabled(void);
void luacapi_log_set_dir(const char *dir);     /* 输出目录；日志文件名自动生成 */
void luacapi_log_set_file(const char *path);   /* 完整日志文件路径（优先于 dir） */
void luacapi_log_set_group(const char *group, int on); /* 分组开关 */
void luacapi_log_set_fn(const char *fn, int on);       /* 单个函数开关（覆盖分组） */
void luacapi_log_flush(void);                  /* 立即落盘 */
void luacapi_log_close(void);                  /* 落盘并关闭文件 */

/*
** 分组名（set_group 用）：lapi / lauxlib / ldebug / ldo / lstate / linit /
** lvm（luaV_* 内部函数入口）/ call（LUA_CALL 函数调用事件）/ log（手动日志）。
** set_fn 可用任意 API 函数名（lua_pushstring、luaL_addlstring、luaV_execute...）。
*/

/* ---- 手动追加一条日志（不受 API 插桩影响） ---- */
void luacapi_log_msg(const char *fmt, ...);

/* ---- 以下为自动插桩使用的流式原语，勿手动调用 ---- */
void luacapi_log_begin(const char *group, const char *fn);
void luacapi_log_state(const char *name, struct lua_State *L);
void luacapi_log_str(const char *name, const char *s);
void luacapi_log_strn(const char *name, const char *s, size_t maxlen);
void luacapi_log_int(const char *name, long long v);
void luacapi_log_uint(const char *name, unsigned long long v);
void luacapi_log_num(const char *name, double v);
void luacapi_log_ptr(const char *name, const void *p);
void luacapi_log_end(void);

/* lvm 层函数调用事件（luaD_precall 调用；func 为被调用函数 TValue*） */
void luacapi_log_call(struct lua_State *L, void *func);

/* ldebug.c 导出的函数名解析（luacapi_log.c 内部使用） */
const char *luac_funcnamefromcode(struct lua_State *L, struct CallInfo *ci,
                                  const char **name);

#ifdef __cplusplus
}
#endif

#endif /* luacapi_log_h */
