p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

# 1. Add to MODULE_GROUPS (控制流 group, after upvalue_promote)
old1 = "    { id: 'upvalue_promote_c', label: 'upvalue升降', desc: 'IIFE包装把局部变量提升为upvalue，改变变量存储方式' },\n  ]},"
new1 = "    { id: 'upvalue_promote_c', label: 'upvalue升降', desc: 'IIFE包装把局部变量提升为upvalue，改变变量存储方式' },\n    { id: 'block_clone_c', label: '基本块克隆', desc: '每个直线块克隆一份(寄存器重映射)，不透明谓词选择原版/克隆版，CFG节点翻倍' },\n  ]},"
s = s.replace(old1, new1, 1)

# 2. Add to EXEC_ORDER (after upvalue_promote_c)
old2 = "'call_rewrite_c','upvalue_promote_c',"
new2 = "'call_rewrite_c','upvalue_promote_c','block_clone_c',"
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('OK')
