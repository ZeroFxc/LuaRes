p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

# Add to MODULE_GROUPS after block_clone
s = s.replace(
    "{ id: 'block_clone_c', label: '基本块克隆', desc: '每个直线块克隆一份(寄存器重映射)，不透明谓词选择原版/克隆版，CFG节点翻倍' },",
    "{ id: 'block_clone_c', label: '基本块克隆', desc: '每个直线块克隆一份(寄存器重映射)，不透明谓词选择原版/克隆版，CFG节点翻倍' },\n    { id: 'cfg_shuffle_c', label: 'CFG基本块重排', desc: '物理打乱基本块顺序，块间用JMP连接，反编译器按物理顺序解析看到混乱控制流' },"
)

# Add to EXEC_ORDER after block_clone_c
s = s.replace(
    "'upvalue_promote_c','block_clone_c'",
    "'upvalue_promote_c','block_clone_c','cfg_shuffle_c'"
)

open(p, 'w', encoding='utf-8').write(s)
print('done')
