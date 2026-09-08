import re
s = open(r'E:\LuaRes\luaclib\obf_register.c', encoding='utf-8').read()
matches = re.findall(r'\{"(\w+)",\s*(\w+)\}', s)
for m in matches:
    if 'vm_embed' in m[0] or 'vm_embed' in m[1]:
        print(m)
