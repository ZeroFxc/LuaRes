p = r'E:\LuaRes\luatools\opcode_research.lua'
s = open(p, encoding='utf-8').read()

# Fix fmt function: JMP is 30, not 27
s = s.replace(
    'if op == 27 or op == 31 or op == 32 or op == 33 then',
    'if op == 30 or op == 31 or op == 32 or op == 33 then'
)
# Fix FORLOOP/FORPREP: 39/40
s = s.replace(
    'if op == 37 or op == 38 or op == 40 or op == 42 then',
    'if op == 39 or op == 40 or op == 42 then'
)
# Fix CLOSURE: 44
s = s.replace(
    'if op == 36 or op == 41 then',
    'if op == 44 then'
)
# Fix reads_regs: EQ/LT/LE
s = s.replace(
    'elseif op == 27 or op == 31 or op == 32 or op == 33 then',
    'elseif op == 31 or op == 32 or op == 33 then'
)
# Fix reads_regs: TFORCALL is 41
s = s.replace(
    'elseif op == 43 then table.insert(regs, a+1); table.insert(regs, a+2)',
    'elseif op == 41 then table.insert(regs, a+1); table.insert(regs, a+2)'
)
# Fix reads_regs: SETLIST is 43
s = s.replace(
    'elseif op == 44 then for i=a+1, a+b do table.insert(regs, i) end',
    'elseif op == 43 then for i=a+1, a+b do table.insert(regs, i) end'
)
# Fix pairing: JMP is 30
s = s.replace(
    '(next_op == 27 and " (配对正确)" or " (配对错误!)")',
    '(next_op == 30 and " (配对正确)" or " (配对错误!)")'
)
# Fix pairing: SETLIST is 43
s = s.replace(
    'elseif op == 44 then  -- SETLIST C=0',
    'elseif op == 43 then  -- SETLIST C=0'
)
# Fix JMP analysis: JMP is 30
s = s.replace(
    'if op == 27 then  -- JMP',
    'if op == 30 then  -- JMP'
)
# Fix FORLOOP/FORPREP analysis
s = s.replace(
    'elseif op == 37 or op == 38 then  -- FORLOOP/FORPREP',
    'elseif op == 39 or op == 40 then  -- FORLOOP/FORPREP'
)

open(p, 'w', encoding='utf-8').write(s)
print('Fixed opcode numbers')
