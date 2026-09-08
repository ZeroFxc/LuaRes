p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()

# Remove all the debug fprintf lines I added (they start with fprintf(stderr,"[OCS]")
import re
# Remove lines that are just debug fprintf
lines = s.split('\n')
new_lines = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith('fprintf(stderr,"[OCS]') or stripped.startswith('/*OCS_DBG*/'):
        continue
    new_lines.append(line)
s = '\n'.join(new_lines)
open(p, 'w', encoding='utf-8').write(s)
print('obf_util debug removed')
