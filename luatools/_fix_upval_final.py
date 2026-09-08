p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        (void)ext_regs; (void)next;
            child->sizek = p->sizek;
            child->k_tag = malloc(sizeof(int)*p->sizek);
            child->k_str = malloc(sizeof(char*)*p->sizek);
            child->k_str_len = malloc(sizeof(int)*p->sizek);
            child->k_num = malloc(sizeof(double)*p->sizek);
            child->k_bool = malloc(sizeof(int)*p->sizek);
            memcpy(child->k_tag,p->k_tag,sizeof(int)*p->sizek);
            memcpy(child->k_num,p->k_num,sizeof(double)*p->sizek);
            memcpy(child->k_bool,p->k_bool,sizeof(int)*p->sizek);
            for (int ci=0;ci<p->sizek;ci++) {
                if (p->k_tag[ci]==4 && p->k_str[ci]) {
                    child->k_str[ci]=malloc(p->k_str_len[ci]+1);
                    memcpy(child->k_str[ci],p->k_str[ci],p->k_str_len[ci]);
                    child->k_str[ci][p->k_str_len[ci]]='\\0';
                    child->k_str_len[ci]=p->k_str_len[ci];
                } else { child->k_str[ci]=NULL; child->k_str_len[ci]=0; }
            }
        }

        /* (minimal child setup done above) */'''

new = '''        (void)ext_regs; (void)next;

        /* (minimal child setup done above) */'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
