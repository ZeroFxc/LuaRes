p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add macro at top after includes
s = s.replace(
    '#include "obf_util.h"',
    '#include "obf_util.h"\n\n#define UPVAL_DEBUG 0\n#if UPVAL_DEBUG\n#define DBG(...) fprintf(stderr, __VA_ARGS__)\n#else\n#define DBG(...) ((void)0)\n#endif'
)

# Replace all fprintf(stderr,"[UPVAL] with DBG(
s = s.replace('fprintf(stderr,"[UPVAL]', 'DBG("[UPVAL]')

open(p, 'w', encoding='utf-8').write(s)
print('upvalue_promote debug wrapped')

# Same for obf_util.c
p2 = r'E:\LuaRes\luaclib\obf_util.c'
s2 = open(p2, encoding='utf-8').read()
s2 = s2.replace('fprintf(stderr,"[OCS]', '/*OCS_DBG*/ fprintf(stderr,"[OCS]')
open(p2, 'w', encoding='utf-8').write(s2)
print('obf_util debug marked (kept as-is for now, can comment out)')
