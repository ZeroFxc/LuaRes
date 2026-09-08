p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

old = '''      if(resultIsLua){
        // compile lua source to bytecode via wasm_load (pass raw bytes, no TextDecoder/TextEncoder to preserve high bytes)
        bcPtr = Module._malloc(resultBytes.length);
        Module.HEAPU8.set(resultBytes, bcPtr);
        const h2 = Module.ccall('wasm_load', 'number', ['number','number'], [bcPtr, resultBytes.length]);
        Module._free(bcPtr);
        if(h2 < 0){ throw new Error('VM源码编译失败'); }
        const lenPtr = Module._malloc(4);
        const dPtr = Module.ccall('wasm_dump', 'number', ['number','number'], [h2, lenPtr]);
        bcLen = Module.getValue(lenPtr, 'i32');
        Module._free(lenPtr);
        bcPtr = Module._malloc(bcLen);
        Module.HEAPU8.set(Module.HEAPU8.subarray(dPtr, dPtr + bcLen), bcPtr);
        Module.ccall('wasm_free_dump', null, ['number'], [dPtr]);
        Module.ccall('wasm_free', null, ['number'], [h2]);
      } else {'''

new = '''      if(resultIsLua){
        // pass lua source directly to wasm_run_bytecode (luaL_loadbuffer handles source, preserves raw bytes)
        bcPtr = Module._malloc(resultBytes.length);
        Module.HEAPU8.set(resultBytes, bcPtr);
        bcLen = resultBytes.length;
      } else {'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
