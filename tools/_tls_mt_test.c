/* _tls_mt_test.c — TLS 化后多线程行交织回归测试（Windows） */
#include "luacapi_log.h"
#include <windows.h>
#include <stdio.h>
#include <stdint.h>

static const int N = 2000;   /* 每线程写入行数 */
static const int T = 4;      /* 线程数 */

static DWORD WINAPI worker (LPVOID arg) {
  int id = (int)(intptr_t)arg;
  int i;
  for (i = 0; i < N; i++) {
    luacapi_log_begin("lapi", "test_worker");
    luacapi_log_int("id", id);
    luacapi_log_int("i", i);
    luacapi_log_str("tag", "hello\"\\x");
    luacapi_log_end();
    /* 偶尔模拟嵌套（同线程快速路径） */
    if ((i & 127) == 0) {
      luacapi_log_begin("lapi", "nested");
      luacapi_log_str("inner", "nest");
      luacapi_log_end();
    }
  }
  return 0;
}

int main (void) {
  HANDLE th[T];
  int i;
  luacapi_log_set_file("tls_mt_test.log");
  for (i = 0; i < T; i++)
    th[i] = CreateThread(NULL, 0, worker, (LPVOID)(intptr_t)i, 0, NULL);
  WaitForMultipleObjects(T, th, TRUE, INFINITE);
  luacapi_log_close();
  printf("done\n");
  return 0;
}
