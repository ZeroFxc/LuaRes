p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''            if(first_read>=0 && (first_write<0 || first_read<first_write)){
                if(next<32)ext_regs[next++]=r;
            }'''

new = '''            /* first_read<=first_write: 同一条指令先读后写（如 CONCAT R8,R8,R9）也算外部变量 */
            if(first_read>=0 && (first_write<0 || first_read<=first_write)){
                if(next<32)ext_regs[next++]=r;
            }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed dataflow: first_read<=first_write counts as external')
