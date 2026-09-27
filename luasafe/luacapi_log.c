/*
** luacapi_log.c
** Lua C API 调用日志库实现（luasafe 内置）
**
** 设计要点：
**   - 插桩代码（lapi.c 等）在进入每个 API 函数时调用本库的流式原语，
**     本库自身绝不调用任何 lua_* 函数，避免递归。
**   - 线程安全：跨度缓冲（begin..end）为每线程私有（TLS），各线程
**     独立构建自己的日志行；整行写入文件时短暂持锁，跨线程不交织。
**     调用层级由 lua_State 的 frm=（CallInfo.previous 链深度）字段还原。
**   - 字符串参数安全输出：NULL 打印 (null)，超长截断，控制字符转义；
**     对 (char*, size_t) 形式的非 NUL 结尾缓冲区提供 strn 变体。
**   - 写入即 fflush，进程崩溃也不丢日志。
*/

#include "lprefix.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(_WIN32) && !defined(__EMSCRIPTEN__)
  #include <windows.h>
  #include <process.h>   /* _getpid */
  #include <direct.h>    /* _mkdir */
#else
  #include <pthread.h>
  #include <stdint.h>
  #include <sys/stat.h>  /* mkdir */
  #include <unistd.h>    /* getpid */
#endif

#include "luacapi_log.h"

/* 访问 lua_State 内部结构以读取进入函数时的栈深度（仅本文件使用） */
#define LUA_CORE
#include "lua.h"
#include "lstate.h"

#define LUACAPI_LOG_BUFSIZE   16384  /* 单条（含嵌套）日志缓冲 */
#define LUACAPI_LOG_MAXSTR    120    /* 字符串参数最大打印长度 */
#define LUACAPI_LOG_MAXDEPTH  32     /* 缩进层数上限 */

#if defined(__EMSCRIPTEN__)
#define LUACAPI_LOG_DEFAULT_ENABLED 0  /* WASM 默认关闭（无文件系统） */
#else
#define LUACAPI_LOG_DEFAULT_ENABLED 1
#endif

/* ---- 平台原语 ---- */
#if defined(_WIN32) && !defined(__EMSCRIPTEN__)
static volatile LONG g_lock = 0;
static void luacapi_lock (void) {
  while (InterlockedExchange(&g_lock, 1) != 0) SwitchToThread();
}
static void luacapi_unlock (void) { InterlockedExchange(&g_lock, 0); }
static unsigned long luacapi_tid (void) { return (unsigned long)GetCurrentThreadId(); }
static long luacapi_pid (void) { return (long)_getpid(); }
static void luacapi_mkdir1 (const char *d) { _mkdir(d); }
#else
static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
static void luacapi_lock (void) { pthread_mutex_lock(&g_mutex); }
static void luacapi_unlock (void) { pthread_mutex_unlock(&g_mutex); }
static unsigned long luacapi_tid (void) {
  return (unsigned long)(uintptr_t)pthread_self();
}
static long luacapi_pid (void) {
#if defined(__EMSCRIPTEN__)
  return 0;
#else
  return (long)getpid();
#endif
}
static void luacapi_mkdir1 (const char *d) { mkdir(d, 0755); }
#endif

/* ---- 全局状态 ---- */
static volatile int g_enabled = LUACAPI_LOG_DEFAULT_ENABLED;
static char g_dir[1024] = "";
static char g_path[1024] = "";
static FILE * volatile g_fp = NULL;   /* 跨线程无锁快查 + 持锁写 */
static volatile int g_open_failed = 0;
static int g_dir_tried_default = 0;  /* 默认目录（宏/环境变量）已解析 */

/* ---- 每线程跨度缓冲（TLS） ----
   每条日志行只在本线程自己的缓冲中构建（begin..end），互不干扰；
   跨线程竞争只发生在整行写入文件时，由全局锁保护
   （见 luacapi_log_end / luacapi_log_call 的持锁写文件）。 */
#if defined(_MSC_VER)
#define LUACAPI_TLS __declspec(thread)
#else
#define LUACAPI_TLS __thread
#endif
static LUACAPI_TLS char g_buf[LUACAPI_LOG_BUFSIZE];
static LUACAPI_TLS int  g_pos = 0;        /* 本线程缓冲写位置 */
static LUACAPI_TLS int  g_depth = 0;      /* 本线程嵌套深度 */
static LUACAPI_TLS int  g_has_arg = 0;    /* 本线程当前跨度是否已有参数 */

/* ---- 分组开关与函数级开关 ---- */
typedef struct LuacapiGroup { const char *name; int on; } LuacapiGroup;
static LuacapiGroup g_groups[] = {
  {"lapi", 1}, {"lauxlib", 1}, {"ldebug", 1}, {"ldo", 1},
  {"lstate", 1}, {"linit", 1}, {"lvm", 1}, {"call", 1}, {"log", 1},
  {NULL, 0}
};
static int g_groups_all_on = 1;  /* 快速路径：全部组开启 */
static int g_fn_count = 0;       /* 快速路径：无函数级覆盖 */

#define LUACAPI_FN_BUCKETS 64
typedef struct LuacapiFn { char *fn; int on; struct LuacapiFn *next; } LuacapiFn;
static LuacapiFn *g_fn[LUACAPI_FN_BUCKETS];

static unsigned luacapi_fnhash (const char *s) {
  unsigned h = 5381;
  while (*s) h = (h * 33) ^ (unsigned char)*s++;
  return h & (LUACAPI_FN_BUCKETS - 1);
}

static int luacapi_fn_on (const char *fn) {
  LuacapiFn *e;
  if (g_fn_count == 0) return 1;
  for (e = g_fn[luacapi_fnhash(fn)]; e != NULL; e = e->next)
    if (strcmp(e->fn, fn) == 0) return e->on;
  return 1;  /* 未单独设置 → 跟随分组开关 */
}

static int luacapi_group_on (const char *g) {
  int i;
  if (g_groups_all_on && g_fn_count == 0) return 1;
  for (i = 0; g_groups[i].name; i++)
    if (strcmp(g_groups[i].name, g) == 0) return g_groups[i].on;
  return 1;  /* 未知组默认开启 */
}

static int luacapi_recount_groups (void) {
  int i;
  for (i = 0; g_groups[i].name; i++)
    if (!g_groups[i].on) return 0;
  return 1;
}

/* ---- 内部工具 ---- */
static void luacapi_append (const char *s, int len) {
  if (len <= 0) return;
  if (g_pos + len >= LUACAPI_LOG_BUFSIZE - 1) {
    len = LUACAPI_LOG_BUFSIZE - 1 - g_pos;
    if (len > 0) { memcpy(g_buf + g_pos, s, (size_t)len); g_pos += len; }
    return;  /* 超长部分丢弃 */
  }
  memcpy(g_buf + g_pos, s, (size_t)len);
  g_pos += len;
}

static void luacapi_append_cstr (const char *s) {
  luacapi_append(s, (int)strlen(s));
}

static void luacapi_flush_locked (void) {
  if (g_fp != NULL && g_pos > 0) {
    fwrite(g_buf, 1, (size_t)g_pos, g_fp);
    fflush(g_fp);
  }
  g_pos = 0;
  g_has_arg = 0;
}

/* 打开日志文件（调用方须已持有锁）。 */
static void luacapi_open_file_locked (void) {
  char path[2048];
  /* 未指定目录时，先尝试编译期宏 LUACAPI_LOG_DIR_DEFAULT，再尝试环境变量
     LUACAPI_LOG_DIR。这样宿主可在加载任何 Lua 代码前（如 Android 应用
     启动时 setenv / 编译时 -D）就固定日志目录，VM 启动阶段的
     luaV_execute 等首条日志也能落入目标目录。 */
  if (g_dir[0] == '\0' && g_path[0] == '\0' && !g_dir_tried_default) {
    g_dir_tried_default = 1;
#ifdef LUACAPI_LOG_DIR_DEFAULT
    if (LUACAPI_LOG_DIR_DEFAULT[0] != '\0')
      snprintf(g_dir, sizeof(g_dir), "%s", LUACAPI_LOG_DIR_DEFAULT);
    else
#endif
    {
      const char *e = getenv("LUACAPI_LOG_DIR");
      if (e != NULL && e[0] != '\0')
        snprintf(g_dir, sizeof(g_dir), "%s", e);
    }
  }
  if (g_path[0] != '\0') {
    snprintf(path, sizeof(path), "%s", g_path);
  }
  else if (g_dir[0] != '\0') {
    time_t t = time(NULL);
    struct tm *tmv = localtime(&t);
    luacapi_mkdir1(g_dir);  /* 已存在则返回错误，忽略 */
    snprintf(path, sizeof(path),
             "%s/luacapi_%04d%02d%02d_%02d%02d%02d_%ld.log",
             g_dir,
             tmv ? tmv->tm_year + 1900 : 0, tmv ? tmv->tm_mon + 1 : 1,
             tmv ? tmv->tm_mday : 1, tmv ? tmv->tm_hour : 0,
             tmv ? tmv->tm_min : 0, tmv ? tmv->tm_sec : 0, luacapi_pid());
  }
  else {
    snprintf(path, sizeof(path), "luacapi.log");
  }
  g_fp = fopen(path, "ab");
  if (g_fp == NULL) g_open_failed = 1;
}

/* 线程安全的打开入口：多线程首次并发进入时只允许打开一次。 */
static void luacapi_open_file (void) {
  if (g_fp != NULL || g_open_failed) return;
  luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();
  luacapi_unlock();
}

/* ---- 配置接口（可在任意时刻调用，线程安全） ---- */
void luacapi_log_set_enabled (int on) {
  luacapi_lock();
  g_enabled = on ? 1 : 0;
  luacapi_unlock();
}

int luacapi_log_enabled (void) {
  return g_enabled;
}

void luacapi_log_set_group (const char *group, int on) {
  int i;
  luacapi_lock();
  if (group != NULL) {
    for (i = 0; g_groups[i].name; i++)
      if (strcmp(g_groups[i].name, group) == 0) {
        g_groups[i].on = on ? 1 : 0;
        break;
      }
  }
  g_groups_all_on = luacapi_recount_groups();
  luacapi_unlock();
}

void luacapi_log_set_fn (const char *fn, int on) {
  unsigned h;
  LuacapiFn *e;
  if (fn == NULL || fn[0] == '\0') return;
  luacapi_lock();
  h = luacapi_fnhash(fn);
  for (e = g_fn[h]; e != NULL; e = e->next)
    if (strcmp(e->fn, fn) == 0) {
      e->on = on ? 1 : 0;
      goto done;
    }
  e = (LuacapiFn *)malloc(sizeof(LuacapiFn));
  if (e != NULL) {
    e->fn = strdup(fn);
    e->on = on ? 1 : 0;
    e->next = g_fn[h];
    g_fn[h] = e;
  }
done:
  {
    int c = 0, i;
    for (i = 0; i < LUACAPI_FN_BUCKETS; i++)
      for (LuacapiFn *x = g_fn[i]; x != NULL; x = x->next) c++;
    g_fn_count = c;
  }
  luacapi_unlock();
}

void luacapi_log_set_dir (const char *dir) {
  luacapi_lock();
  g_dir_tried_default = 1;  /* 显式设置后不再回退到宏/环境变量 */
  if (dir != NULL && dir[0] != '\0') {
    snprintf(g_dir, sizeof(g_dir), "%s", dir);
    g_path[0] = '\0';
  }
  else {
    g_dir[0] = '\0';
  }
  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}

void luacapi_log_set_file (const char *path) {
  luacapi_lock();
  if (path != NULL && path[0] != '\0') {
    snprintf(g_path, sizeof(g_path), "%s", path);
    g_dir[0] = '\0';
  }
  else {
    g_path[0] = '\0';
  }
  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}

void luacapi_log_flush (void) {
  luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();
  luacapi_flush_locked();
  luacapi_unlock();
}

void luacapi_log_close (void) {
  luacapi_lock();
  luacapi_flush_locked();
  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}

void luacapi_log_msg (const char *fmt, ...) {
  char line[1024];
  va_list ap;
  if (!g_enabled) return;
  va_start(ap, fmt);
  vsnprintf(line, sizeof(line), fmt, ap);
  va_end(ap);
  luacapi_log_begin("log", "$");
  luacapi_log_str("msg", line);
  luacapi_log_end();
}

/* ---- 流式原语（插桩使用） ---- */
void luacapi_log_begin (const char *group, const char *fn) {
  char hdr[96];
  int n;
  time_t t;
  struct tm *tmv;
  if (!g_enabled) return;
  if (g_fn_count > 0 && !luacapi_fn_on(fn)) return;      /* 函数级关闭 */
  if (!luacapi_group_on(group)) return;                  /* 分组关闭 */
  if (g_fp == NULL && !g_open_failed) luacapi_open_file();
  if (g_depth > 0) {  /* 嵌套调用：换行缩进 */
    int i;
    luacapi_append_cstr("\n");
    for (i = 0; i < g_depth && i < LUACAPI_LOG_MAXDEPTH; i++)
      luacapi_append_cstr("  ");
  }
  else {  /* 顶层：打时间戳与线程号 */
    t = time(NULL);
    tmv = localtime(&t);
    n = snprintf(hdr, sizeof(hdr), "[%02d:%02d:%02d][tid=%lu] ",
                 tmv ? tmv->tm_hour : 0, tmv ? tmv->tm_min : 0,
                 tmv ? tmv->tm_sec : 0, luacapi_tid());
    luacapi_append(hdr, n);
  }
  luacapi_append_cstr(fn);
  luacapi_append_cstr("(");
  g_has_arg = 0;
  g_depth++;
}

void luacapi_log_end (void) {
  if (!g_enabled) return;
  if (g_depth == 0) return;  /* 防护：本线程无活跃跨度 */
  g_depth--;
  luacapi_append_cstr(")");
  if (g_depth == 0) {
    luacapi_append_cstr("\n");
    luacapi_lock();  /* 整行一次性写入文件，跨线程不交织 */
    if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();
    luacapi_flush_locked();
    luacapi_unlock();
  }
}

static void luacapi_arg_prefix (const char *name) {
  if (g_depth == 0) return;  /* 本线程未在跨度内 */
  if (g_has_arg) luacapi_append_cstr(", ");
  else g_has_arg = 1;
  luacapi_append_cstr(name);
  luacapi_append_cstr("=");
}

void luacapi_log_int (const char *name, long long v) {
  char tmp[32];
  int n;
  luacapi_arg_prefix(name);
  n = snprintf(tmp, sizeof(tmp), "%lld", v);
  luacapi_append(tmp, n);
}

void luacapi_log_uint (const char *name, unsigned long long v) {
  char tmp[32];
  int n;
  luacapi_arg_prefix(name);
  n = snprintf(tmp, sizeof(tmp), "%llu", v);
  luacapi_append(tmp, n);
}

void luacapi_log_num (const char *name, double v) {
  char tmp[40];
  int n;
  luacapi_arg_prefix(name);
  n = snprintf(tmp, sizeof(tmp), "%.14g", v);
  luacapi_append(tmp, n);
}

void luacapi_log_ptr (const char *name, const void *p) {
  char tmp[32];
  int n;
  luacapi_arg_prefix(name);
  n = snprintf(tmp, sizeof(tmp), "%p", p);
  luacapi_append(tmp, n);
}

/* 带长度上限的字符串输出（maxlen==0 视为到 NUL 为止） */
void luacapi_log_strn (const char *name, const char *s, size_t maxlen) {
  size_t i, n;
  luacapi_arg_prefix(name);
  if (s == NULL) { luacapi_append_cstr("(null)"); return; }
  luacapi_append_cstr("\"");
  n = (maxlen == 0) ? strlen(s) : maxlen;
  if (n > LUACAPI_LOG_MAXSTR) n = LUACAPI_LOG_MAXSTR;
  for (i = 0; i < n; i++) {
    unsigned char c = (unsigned char)s[i];
    if (c == '\\' || c == '"') {
      char esc[2] = { '\\', (char)c };
      luacapi_append(esc, 2);
    }
    else if (c == '\n') luacapi_append_cstr("\\n");
    else if (c == '\r') luacapi_append_cstr("\\r");
    else if (c == '\t') luacapi_append_cstr("\\t");
    else if (c < 32 || c == 127) {
      char hex[8];
      int hn = snprintf(hex, sizeof(hex), "\\x%02X", (int)c);
      luacapi_append(hex, hn);
    }
    else {
      luacapi_append((const char *)&c, 1);
    }
  }
  if (maxlen == 0 ? strlen(s) > LUACAPI_LOG_MAXSTR : maxlen > LUACAPI_LOG_MAXSTR)
    luacapi_append_cstr("...");
  luacapi_append_cstr("\"");
}

void luacapi_log_str (const char *name, const char *s) {
  luacapi_log_strn(name, s, 0);
}

void luacapi_log_state (const char *name, struct lua_State *L) {
  char tmp[64];
  int n;
  luacapi_arg_prefix(name);
  if (L == NULL) { luacapi_append_cstr("(null)"); return; }
  n = snprintf(tmp, sizeof(tmp), "%p", (const void *)L);
  luacapi_append(tmp, n);
  if (L->ci != NULL) {  /* 进入函数时的栈深度（L->top - (ci->func + 1)） */
    n = snprintf(tmp, sizeof(tmp), " top=%d",
                 (int)(L->top - (L->ci->func + 1)));
    luacapi_append(tmp, n);
  }
  if (L->ci != NULL) {  /* 调用帧深度（沿 CallInfo.previous 链计数，扩容后依然有效） */
    int d = 0;
    CallInfo *ci = L->ci;
    while (ci != NULL && d < 1024) { d++; ci = ci->previous; }
    n = snprintf(tmp, sizeof(tmp), " frm=%d", d);
    luacapi_append(tmp, n);
  }
}

/* ---- lvm 层函数调用事件（luaD_precall 调用） ---- */
void luacapi_log_call (struct lua_State *L, void *func) {
  char line[LUACAPI_LOG_BUFSIZE];
  int n = 0;
  int pos = 0;
  int i;
  const char *name = NULL;
  int is_cfunc = 1;
  int nargs = 0;
  int frm = 0;
  time_t t;
  struct tm *tmv;
  unsigned long tid;
  CallInfo *ci;

  if (!g_enabled) return;
  if (g_fn_count > 0 && !luacapi_fn_on("LUA_CALL")) return;  /* 函数级覆盖 */
  if (!luacapi_group_on("call")) return;                     /* 分组关闭 */

  /* 类型与参数个数 */
  if (L != NULL && func != NULL) {
    int tt = ttype((const TValue *)func);
    is_cfunc = (tt == LUA_TCCL || tt == LUA_TLCF);
    nargs = (int)(L->top - (TValue *)func) - 1;
    if (nargs < 0) nargs = 0;
  }
  /* 函数名：调用者为 Lua 帧时由调用指令解析 */
  if (L != NULL && L->ci != NULL)
    luac_funcnamefromcode(L, L->ci, &name);
  if (name == NULL) name = "(unknown)";

  /* 帧深度 */
  if (L != NULL) {
    for (ci = L->ci; ci != NULL && frm < 1024; frm++) ci = ci->previous;
  }

  tid = luacapi_tid();
  luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();

  t = time(NULL);
  tmv = localtime(&t);
  n = snprintf(line + pos, sizeof(line) - pos,
               "[%02d:%02d:%02d][tid=%lu] LUA_CALL name=\"",
               tmv ? tmv->tm_hour : 0, tmv ? tmv->tm_min : 0,
               tmv ? tmv->tm_sec : 0, tid);
  if (n > 0) pos += n;
  /* 转义函数名 */
  for (i = 0; name[i] != '\0' && pos < (int)sizeof(line) - 32; i++) {
    unsigned char c = (unsigned char)name[i];
    if (c == '\\' || c == '"') {
      if (pos + 2 < (int)sizeof(line) - 32) {
        line[pos++] = '\\'; line[pos++] = (char)c;
      }
    }
    else if (c < 32 || c == 127) {
      int hn = snprintf(line + pos, sizeof(line) - pos, "\\x%02X", (int)c);
      if (hn > 0) pos += hn;
    }
    else {
      line[pos++] = (char)c;
    }
  }
  n = snprintf(line + pos, sizeof(line) - pos,
               "\" type=%s nargs=%d frm=%d\n",
               is_cfunc ? "C" : "L", nargs, frm);
  if (n > 0) pos += n;
  if (g_fp != NULL) {
    fwrite(line, 1, (size_t)pos, g_fp);
    fflush(g_fp);
  }
  luacapi_unlock();
}
