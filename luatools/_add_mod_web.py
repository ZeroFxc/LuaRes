p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

# 1. Add to "其他" group
old1 = "    { id: 'antidec_c', label: '反编译对抗', desc: '插入干扰 unluac/luadec 的结构' },\n  ]},"
new1 = "    { id: 'antidec_c', label: '反编译对抗', desc: '插入干扰 unluac/luadec 的结构' },\n    { id: 'integrity_check_c', label: '完整性校验', desc: '运行时FNV-1a哈希校验字节码，仅用标准库(debug/string)，篡改则死循环' },\n  ]},"
s = s.replace(old1, new1, 1)

# 2. Add to EXEC_ORDER (before vm_embed_c)
old2 = "  'live_range_split_c','op48_junk_c','vm_embed_c'"
new2 = "  'live_range_split_c','op48_junk_c','integrity_check_c','vm_embed_c'"
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('done')
