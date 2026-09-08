import re

# Fix lundump.c
p1 = r'E:\LuaRes\luasafe\lundump.c'
s1 = open(p1, encoding='utf-8').read()

# Short string branch
old1 = '''    if (S->encrypted && len > 0) {
      char tmp[LUAI_MAXSHORTLEN + 1];
      memcpy(tmp, buff, len);
      decrypt_string((unsigned char *)tmp, len);
      if (is_valid_text((unsigned char *)tmp, len))
        memcpy(buff, tmp, len);
    }'''
new1 = '''    if (S->encrypted && len > 0) {
      char tmp[LUAI_MAXSHORTLEN + 1];
      memcpy(tmp, buff, len);
      decrypt_string((unsigned char *)tmp, len);
      /* len==1: single-byte strings always decrypt correctly (XOR with len%255),
         and is_valid_text rejects high bytes as incomplete UTF-8. */
      if (len == 1 || is_valid_text((unsigned char *)tmp, len))
        memcpy(buff, tmp, len);
    }'''
s1 = s1.replace(old1, new1, 1)

# Long string branch
old2 = '''    if (S->encrypted && len > 0) {
      char *tmp = luaM_newvector(S->L, len, char);
      memcpy(tmp, getstr(ts), len);
      decrypt_string((unsigned char *)tmp, len);
      if (is_valid_text((unsigned char *)tmp, len))
        memcpy(getstr(ts), tmp, len);
      luaM_freearray(S->L, tmp, len);
    }'''
new2 = '''    if (S->encrypted && len > 0) {
      char *tmp = luaM_newvector(S->L, len, char);
      memcpy(tmp, getstr(ts), len);
      decrypt_string((unsigned char *)tmp, len);
      if (len == 1 || is_valid_text((unsigned char *)tmp, len))
        memcpy(getstr(ts), tmp, len);
      luaM_freearray(S->L, tmp, len);
    }'''
s1 = s1.replace(old2, new2, 1)
open(p1, 'w', encoding='utf-8').write(s1)
print('lundump.c fixed')

# Fix luaclib/luac.c
p2 = r'E:\LuaRes\luaclib\luac.c'
s2 = open(p2, encoding='utf-8').read()
old3 = '''    if (S->encrypted && len > 0) {
        unsigned char *tmp = luac_alloc(len);
        memcpy(tmp, s, len);
        andlua_decrypt_string(tmp, len);
        int valid = andlua_is_valid_text(tmp, len);'''
new3 = '''    if (S->encrypted && len > 0) {
        unsigned char *tmp = luac_alloc(len);
        memcpy(tmp, s, len);
        andlua_decrypt_string(tmp, len);
        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'''
s2 = s2.replace(old3, new3, 1)
open(p2, 'w', encoding='utf-8').write(s2)
print('luac.c fixed')
