path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all remaining push_proto calls with luac_push_proto
# But be careful not to replace luac_push_proto itself
import re
content = re.sub(r'(?<!luac_)push_proto\(', 'luac_push_proto(', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
