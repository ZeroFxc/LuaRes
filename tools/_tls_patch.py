# -*- coding: utf-8 -*-
# TLS 化 luacapi_log.c：跨度缓冲 per-thread，消除跨线程行交织竞态
import io

p = r'E:\LuaRes\luasafe\luacapi_log.c'
s = io.open(p, 'r', encoding='utf-8').read()

repls = []

# R1: g_enabled volatile
repls.append((
"""static int g_enabled = LUACAPI_LOG_DEFAULT_ENABLED;""",
"""static volatile int g_enabled = LUACAPI_LOG_DEFAULT_ENABLED;"""))

# R2: g_fp / g_open_failed volatile
repls.append((
"""static FILE *g_fp = NULL;
static int g_open_failed = 0;""",
"""static FILE * volatile g_fp = NULL;   /* 跨线程无锁快查 + 持锁写 */
static volatile int g_open_failed = 0;"""))

# R3: 缓冲 TLS 化 + 删除 g_owner
repls.append((
"""static char g_buf[LUACAPI_LOG_BUFSIZE];
static int  g_pos = 0;        /* 缓冲写位置 */
static int  g_depth = 0;      /* 嵌套深度 */
static int  g_has_arg = 0;    /* 当前跨度是否已有参数 */
static unsigned long g_owner = 0;  /* 当前日志跨度的持有线程 */""",
"""/* ---- 每线程跨度缓冲（TLS） ----
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
static LUACAPI_TLS int  g_has_arg = 0;    /* 本线程当前跨度是否已有参数 */"""))

# R4: open_file 拆 locked + 线程安全包装
repls.append((
"""static void luacapi_open_file (void) {
  char path[2048];
  /* 未指定目录时，先尝试编译期宏 LUACAPI_LOG_DIR_DEFAULT，再尝试环境变量
     LUACAPI_LOG_DIR。这样宿主可在加载任何 Lua 代码前（如 Android 应用
     启动时 setenv / 编译时 -D）就固定日志目录，VM 启动阶段的
     luaV_execute 等首条日志也能落入目标目录。 */
  if (g_dir[0] == '\\0' && g_path[0] == '\\0' && !g_dir_tried_default) {
    g_dir_tried_default = 1;
#ifdef LUACAPI_LOG_DIR_DEFAULT
    if (LUACAPI_LOG_DIR_DEFAULT[0] != '\\0')
      snprintf(g_dir, sizeof(g_dir), "%s", LUACAPI_LOG_DIR_DEFAULT);
    else
#endif
    {
      const char *e = getenv("LUACAPI_LOG_DIR");
      if (e != NULL && e[0] != '\\0')
        snprintf(g_dir, sizeof(g_dir), "%s", e);
    }
  }
  if (g_path[0] != '\\0') {
    snprintf(path, sizeof(path), "%s", g_path);
  }
  else if (g_dir[0] != '\\0') {
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
}""",
"""/* 打开日志文件（调用方须已持有锁）。 */
static void luacapi_open_file_locked (void) {
  char path[2048];
  /* 未指定目录时，先尝试编译期宏 LUACAPI_LOG_DIR_DEFAULT，再尝试环境变量
     LUACAPI_LOG_DIR。这样宿主可在加载任何 Lua 代码前（如 Android 应用
     启动时 setenv / 编译时 -D）就固定日志目录，VM 启动阶段的
     luaV_execute 等首条日志也能落入目标目录。 */
  if (g_dir[0] == '\\0' && g_path[0] == '\\0' && !g_dir_tried_default) {
    g_dir_tried_default = 1;
#ifdef LUACAPI_LOG_DIR_DEFAULT
    if (LUACAPI_LOG_DIR_DEFAULT[0] != '\\0')
      snprintf(g_dir, sizeof(g_dir), "%s", LUACAPI_LOG_DIR_DEFAULT);
    else
#endif
    {
      const char *e = getenv("LUACAPI_LOG_DIR");
      if (e != NULL && e[0] != '\\0')
        snprintf(g_dir, sizeof(g_dir), "%s", e);
    }
  }
  if (g_path[0] != '\\0') {
    snprintf(path, sizeof(path), "%s", g_path);
  }
  else if (g_dir[0] != '\\0') {
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
}"""))

# R5: set_enabled
repls.append((
"""void luacapi_log_set_enabled (int on) {
  unsigned long tid = luacapi_tid();
  if (g_owner == tid) { g_enabled = on ? 1 : 0; return; }  /* 已在跨度内 */
  luacapi_lock();
  g_enabled = on ? 1 : 0;
  luacapi_unlock();
}""",
"""void luacapi_log_set_enabled (int on) {
  luacapi_lock();
  g_enabled = on ? 1 : 0;
  luacapi_unlock();
}"""))

# R6: set_group 开头
repls.append((
"""void luacapi_log_set_group (const char *group, int on) {
  int i;
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (!same) luacapi_lock();""",
"""void luacapi_log_set_group (const char *group, int on) {
  int i;
  luacapi_lock();"""))

# R6b: set_group 结尾
repls.append((
"""  g_groups_all_on = luacapi_recount_groups();
  if (!same) luacapi_unlock();
}""",
"""  g_groups_all_on = luacapi_recount_groups();
  luacapi_unlock();
}"""))

# R7: set_fn 开头
repls.append((
"""  unsigned h;
  LuacapiFn *e;
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (fn == NULL || fn[0] == '\\0') return;
  if (!same) luacapi_lock();""",
"""  unsigned h;
  LuacapiFn *e;
  if (fn == NULL || fn[0] == '\\0') return;
  luacapi_lock();"""))

# R7b: set_fn 结尾
repls.append((
"""    g_fn_count = c;
  }
  if (!same) luacapi_unlock();
}""",
"""    g_fn_count = c;
  }
  luacapi_unlock();
}"""))

# R8: set_dir 开头
repls.append((
"""void luacapi_log_set_dir (const char *dir) {
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (!same) luacapi_lock();""",
"""void luacapi_log_set_dir (const char *dir) {
  luacapi_lock();"""))

# R8b: set_dir 结尾
repls.append((
"""  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  if (!same) luacapi_unlock();
}

void luacapi_log_set_file (const char *path) {""",
"""  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}

void luacapi_log_set_file (const char *path) {"""))

# R9: set_file 开头
repls.append((
"""void luacapi_log_set_file (const char *path) {
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (!same) luacapi_lock();""",
"""void luacapi_log_set_file (const char *path) {
  luacapi_lock();"""))

# R10: set_file 结尾 + flush 开头
repls.append((
"""  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  if (!same) luacapi_unlock();
}

void luacapi_log_flush (void) {""",
"""  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}

void luacapi_log_flush (void) {"""))

# R11: flush
repls.append((
"""void luacapi_log_flush (void) {
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (!same) luacapi_lock();
  luacapi_flush_locked();
  if (!same) luacapi_unlock();
}""",
"""void luacapi_log_flush (void) {
  luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();
  luacapi_flush_locked();
  luacapi_unlock();
}"""))

# R12: close
repls.append((
"""void luacapi_log_close (void) {
  unsigned long tid = luacapi_tid();
  int same = (g_owner == tid);
  if (!same) luacapi_lock();
  luacapi_flush_locked();
  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  if (!same) luacapi_unlock();
}""",
"""void luacapi_log_close (void) {
  luacapi_lock();
  luacapi_flush_locked();
  if (g_fp != NULL) { fclose(g_fp); g_fp = NULL; }
  g_open_failed = 0;
  luacapi_unlock();
}"""))

# R13: begin 去掉 g_owner 新跨度逻辑
repls.append((
"""  if (!g_enabled) return;
  if (g_fn_count > 0 && !luacapi_fn_on(fn)) return;      /* 函数级关闭 */
  if (!luacapi_group_on(group)) return;                  /* 分组关闭 */
  if (g_owner != luacapi_tid()) {  /* 新跨度：加锁并复位（跨线程会阻塞等待） */
    luacapi_lock();
    g_owner = luacapi_tid();
    g_pos = 0;
    g_depth = 0;
    g_has_arg = 0;
    if (g_fp == NULL && !g_open_failed) luacapi_open_file();
  }
  if (g_depth > 0) {  /* 嵌套调用：换行缩进 */""",
"""  if (!g_enabled) return;
  if (g_fn_count > 0 && !luacapi_fn_on(fn)) return;      /* 函数级关闭 */
  if (!luacapi_group_on(group)) return;                  /* 分组关闭 */
  if (g_fp == NULL && !g_open_failed) luacapi_open_file();
  if (g_depth > 0) {  /* 嵌套调用：换行缩进 */"""))

# R14: end
repls.append((
"""void luacapi_log_end (void) {
  if (!g_enabled) return;
  if (g_depth == 0 || g_owner != luacapi_tid()) return;  /* 防护 */
  g_depth--;
  luacapi_append_cstr(")");
  if (g_depth == 0) {
    luacapi_append_cstr("\\n");
    luacapi_flush_locked();
    g_owner = 0;
    luacapi_unlock();
  }
}""",
"""void luacapi_log_end (void) {
  if (!g_enabled) return;
  if (g_depth == 0) return;  /* 防护：本线程无活跃跨度 */
  g_depth--;
  luacapi_append_cstr(")");
  if (g_depth == 0) {
    luacapi_append_cstr("\\n");
    luacapi_lock();  /* 整行一次性写入文件，跨线程不交织 */
    if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();
    luacapi_flush_locked();
    luacapi_unlock();
  }
}"""))

# R15: arg_prefix
repls.append((
"""static void luacapi_arg_prefix (const char *name) {
  if (g_depth == 0 || g_owner != luacapi_tid()) return;  /* 未在跨度内 */""",
"""static void luacapi_arg_prefix (const char *name) {
  if (g_depth == 0) return;  /* 本线程未在跨度内 */"""))

# R16: call 变量声明
repls.append((
"""  unsigned long tid;
  CallInfo *ci;
  int same;

  if (!g_enabled) return;""",
"""  unsigned long tid;
  CallInfo *ci;

  if (!g_enabled) return;"""))

# R17: call 锁
repls.append((
"""  tid = luacapi_tid();
  same = (g_owner == tid);
  if (!same) luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file();""",
"""  tid = luacapi_tid();
  luacapi_lock();
  if (g_fp == NULL && !g_open_failed) luacapi_open_file_locked();"""))

# R18: call 结尾
repls.append((
"""  if (g_fp != NULL) {
    fwrite(line, 1, (size_t)pos, g_fp);
    fflush(g_fp);
  }
  if (!same) luacapi_unlock();
}""",
"""  if (g_fp != NULL) {
    fwrite(line, 1, (size_t)pos, g_fp);
    fflush(g_fp);
  }
  luacapi_unlock();
}"""))

# R19: 头注释
repls.append((
"""**   - 线程安全：同一时刻只允许一个线程持有日志跨度（begin..end），
**     其他线程阻塞等待；每条日志独立成行，顺序即调用时序。
**     调用层级由 lua_State 的 frm=（CallInfo.previous 链深度）字段还原。""",
"""**   - 线程安全：跨度缓冲（begin..end）为每线程私有（TLS），各线程
**     独立构建自己的日志行；整行写入文件时短暂持锁，跨线程不交织。
**     调用层级由 lua_State 的 frm=（CallInfo.previous 链深度）字段还原。"""))

ok = True
for i, (old, new) in enumerate(repls):
    cnt = s.count(old)
    if cnt != 1:
        print('R%d FAIL count=%d' % (i + 1, cnt))
        print('--- old head ---')
        print(old[:120])
        ok = False
    else:
        s = s.replace(old, new, 1)

if ok:
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('ALL %d REPLACEMENTS OK' % len(repls))
else:
    print('ABORTED, no write')
