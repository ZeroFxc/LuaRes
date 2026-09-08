/*
** debug_mutate.c - 调试信息变异
**
** 不是剥离调试信息，而是伪造：
** 1. locvar_name — 替换为随机三字字符串
** 2. upval_name — 替换为随机三字字符串
** 3. lineinfo — 整体偏移 + 随机扰动，保持非递减趋势
**
** 误导基于调试信息的反编译器。
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define DEBUG_MUTATE_DEBUG 0

/* 生成随机三字小写字符串 */
static char *rand_3char(void) {
    char *s = malloc(4);
    s[0] = 'a' + (obf_rand() % 26);
    s[1] = 'a' + (obf_rand() % 26);
    s[2] = 'a' + (obf_rand() % 26);
    s[3] = '\0';
    return s;
}

static void mutate_function(luac_Proto *p) {
    if (!p) return;

    /* 1. 变异 locvar_name */
    if (p->locvar_name && p->sizelocvars > 0) {
        for (int i = 0; i < p->sizelocvars; i++) {
            if (p->locvar_name[i]) {
                free(p->locvar_name[i]);
                p->locvar_name[i] = rand_3char();
                p->locvar_name_len[i] = 3;
            }
        }
    }

    /* 2. 变异 upval_name */
    if (p->upval_name && p->sizeupvalues > 0) {
        for (int i = 0; i < p->sizeupvalues; i++) {
            if (p->upval_name[i]) {
                free(p->upval_name[i]);
                p->upval_name[i] = rand_3char();
                p->upval_name_len[i] = 3;
            }
        }
    }

    /* 3. 变异 lineinfo — 整体偏移 + 随机扰动，保持非递减 */
    if (p->lineinfo && p->sizelineinfo > 0) {
        int offset = 100 + (obf_rand() % 900);  /* 整体偏移 100-999 */
        int prev = 0;
        for (int i = 0; i < p->sizelineinfo; i++) {
            int base = p->lineinfo[i] + offset;
            int jitter = (int)(obf_rand() % 5) - 2;  /* -2 到 +2 */
            int val = base + jitter;
            if (val < prev) val = prev;  /* 保持非递减 */
            if (val < 1) val = 1;
            p->lineinfo[i] = val;
            prev = val;
        }
    }

    /* 递归子 proto */
    if (p->p) for (int i = 0; i < p->sizep; i++)
        mutate_function(p->p[i]);
}

int debug_mutate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    mutate_function(p);

    lua_pushinteger(L, 1);
    return 1;
}
