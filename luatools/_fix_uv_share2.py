p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_runtime.c'
s = open(p, encoding='utf-8').read()

# Simple replace: change the copy to shared reference
old1 = 'uv[i] = {val = getuv(d.idx)}'
new1 = 'uv[i] = UV[d.idx] or {val = nil}'

if old1 in s:
    s = s.replace(old1, new1, 1)
    print("Replaced uv[i] copy with shared UV reference")
else:
    print("ERROR: old1 not found")

# Add UV to the vmbuf_printf format args for makeclosure
# Find the line with "PROTO, PROTO, R);" that follows makeclosure
old2 = '"  end\\n", PROTO, PROTO, R);'
new2 = '"  end\\n", PROTO, PROTO, R, UV);'

# But there might be multiple occurrences. Find the one after makeclosure.
# Let's count occurrences first
count = s.count(old2)
print(f"Found {count} occurrences of format pattern")

# Replace only the first one (makeclosure)
if count >= 1:
    idx = s.find(old2)
    s = s[:idx] + new2 + s[idx+len(old2):]
    print("Added UV to first format args (makeclosure)")
else:
    print("ERROR: format pattern not found")

open(p, 'w', encoding='utf-8').write(s)
print("Done")
