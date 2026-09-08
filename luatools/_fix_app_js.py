p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

old = '''      if(resultIsLua){
        const src = new TextDecoder().decode(resultBytes);
        const compiled = Module.ccall('wasm_load', 'number', ['number','number'], [0,0]);
        // compile lua source to bytecode via wasm_load (it handles source)
        const srcBytes = new TextEncoder().encode(src);
        bcPtr = Module._malloc(srcBytes.length);
        Module.HEAPU8.set(srcBytes, bcPtr);
        const h2 = Module.ccall('wasm_load', 'number', ['number','number'], [bcPtr, srcBytes.length]);
        Module._free(bcPtr);
        if(h2 < 0){ throw new Error('VM源码编译失败'); }'''

new = '''      if(resultIsLua){
        // compile lua source to bytecode via wasm_load (pass raw bytes, no TextDecoder/TextEncoder to preserve high bytes)
        bcPtr = Module._malloc(resultBytes.length);
        Module.HEAPU8.set(resultBytes, bcPtr);
        const h2 = Module.ccall('wasm_load', 'number', ['number','number'], [bcPtr, resultBytes.length]);
        Module._free(bcPtr);
        if(h2 < 0){ throw new Error('VM源码编译失败'); }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
