// Node.js test for WASM const_hide with zeus script
const fs = require('fs');
const path = require('path');

// Load the WASM module factory
const createLuacModule = require('./luasafe/luac_wasm.js');

async function main() {
    console.log('=== WASM Node.js Test ===');
    
    // Initialize module
    const Module = await createLuacModule();
    console.log('WASM module loaded');
    
    // Init WASM state
    const initRet = Module._wasm_init();
    console.log('wasm_init returned:', initRet);
    
    // Capture stderr
    let stderrBuf = '';
    const oldPrintErr = Module.printErr;
    Module.printErr = function(text) {
        stderrBuf += text + '\n';
        if (oldPrintErr) oldPrintErr(text);
    };
    
    // Read zeus source as raw bytes
    const srcBuf = fs.readFileSync('./zeus_customer_source_debug.lua');
    console.log('Source read:', srcBuf.length, 'bytes');
    
    // Allocate and copy source as raw bytes
    const srcPtr = Module._malloc(srcBuf.length);
    Module.HEAPU8.set(srcBuf, srcPtr);
    
    // wasm_load
    console.log('Calling wasm_load...');
    const handle = Module._wasm_load(srcPtr, srcBuf.length);
    Module._free(srcPtr);
    console.log('wasm_load returned handle:', handle);
    
    if (handle < 0) {
        const errPtr = Module._wasm_last_error();
        console.log('Load error:', Module.UTF8ToString(errPtr));
        return;
    }
    
    // wasm_apply with const_hide_c
    console.log('Calling wasm_apply(const_hide_c)...');
    const nameStr = 'const_hide_c';
    const nameLen = Module.lengthBytesUTF8(nameStr) + 1;
    const namePtr = Module._malloc(nameLen);
    Module.stringToUTF8(nameStr, namePtr, nameLen);
    const ret = Module._wasm_apply(handle, namePtr);
    Module._free(namePtr);
    console.log('wasm_apply returned:', ret);
    
    if (ret !== 0) {
        const errPtr = Module._wasm_last_error();
        console.log('Apply error:', Module.UTF8ToString(errPtr));
    }
    
    // wasm_dump
    console.log('Calling wasm_dump...');
    const outLenPtr = Module._malloc(4);
    const outPtr = Module._wasm_dump(handle, outLenPtr);
    const outLen = Module.getValue(outLenPtr, 'i32');
    Module._free(outLenPtr);
    console.log('wasm_dump returned ptr:', outPtr, 'len:', outLen);
    
    if (outPtr && outLen > 0) {
        const outBytes = new Uint8Array(Module.HEAPU8.buffer, outPtr, outLen);
        fs.writeFileSync('./zeus_out_wasm.luac', Buffer.from(outBytes));
        Module._wasm_free_dump(outPtr);
        console.log('Output saved:', outLen, 'bytes');
    }
    
    // wasm_free
    Module._wasm_free(handle);
    Module._wasm_shutdown();
    
    console.log('=== STDERR (last 2000 chars) ===');
    console.log(stderrBuf.slice(-2000));
    console.log('=== DONE ===');
}

main().catch(e => {
    console.error('FATAL:', e);
    console.error(e.stack);
});
