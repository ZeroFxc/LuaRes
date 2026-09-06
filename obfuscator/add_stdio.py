with open(r'E:\LuaRes\luasafe\lundump.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """#include <string.h>
#include <stdint.h>"""

new = """#include <string.h>
#include <stdint.h>
#include <stdio.h>"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luasafe\lundump.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
