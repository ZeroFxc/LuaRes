p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Add debug at LoadString entry
old = '''static char *LoadString(UndumpState *S, size_t *out_len) {
    size_t size = LoadByte(S);'''

new = '''static char *LoadString(UndumpState *S, size_t *out_len) {
    size_t size = LoadByte(S);
    if (size > 0 && size < 255) {
        size_t dbg_len = size - 1;
        if (dbg_len == 1) {
            /* peek at next byte */
            fprintf(stderr, "[LUAC_ENTRY] size=%zu encrypted=%d next_byte=%d\\n", size, S->encrypted, (int)S->buf[S->pos]);
        }
    }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('entry debug added')
