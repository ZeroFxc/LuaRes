import re

path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add include after lauxlib.h
content = content.replace(
    '#include "lauxlib.h"\n',
    '#include "lauxlib.h"\n#include "luac.h"\n',
    1
)
print('include added')

# 2. Remove the data structures block
pattern = r'/\*=+\n\*\* Data structures\n\*\*=+\*/\n\ntypedef struct luac_Proto \{.*?\} luac_Proto;\n\n/\* constant tags.*?\*/\n(?:#define[^\n]*\n)+'
content_new = re.sub(pattern, '', content, flags=re.DOTALL)
if content_new != content:
    content = content_new
    print('struct block removed')
else:
    print('struct block NOT removed')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
