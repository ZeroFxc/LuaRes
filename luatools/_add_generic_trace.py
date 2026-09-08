p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()

# Add generic instruction trace after vmfetch, before the HeapValidate block
old = '''    vmfetch();
    {
        static long long _hv_count = 0;'''
new = '''    vmfetch();
    {
        static const char *_opnames2[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
        int _pc2 = (int)((ci->u.l.savedpc - 1) - cl->p->code);
        int _op2 = i & 0x3F;
        fprintf(stderr, "[PC] %d %s (%08x) maxstack=%d sizek=%d\\n", _pc2, _op2 < 47 ? _opnames2[_op2] : "?", i, cl->p->maxstacksize, cl->p->sizek);
        fflush(stderr);
    }
    {
        static long long _hv_count = 0;'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('generic trace added')
