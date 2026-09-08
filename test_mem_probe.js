// Node.js test for WASM memory probe
const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');

async function main() {
    console.log('=== WASM Memory Probe Test ===');
    const Module = await createLuacModule();
    console.log('WASM module loaded');

    // Probe after init
    const p1 = Module._malloc(1024);
    console.log('After wasm_init: malloc(1024)=', p1);
    if (p1) Module._free(p1);

    Module._wasm_init();
    console.log('wasm_init done');

    const p2 = Module._malloc(1024);
    console.log('After wasm_init call: malloc(1024)=', p2);
    if (p2) Module._free(p2);

    const srcBuf = fs.readFileSync('./zeus_customer_source_debug.lua');
    const srcPtr = Module._malloc(srcBuf.length);
    Module.HEAPU8.set(srcBuf, srcPtr);
    const handle = Module._wasm_load(srcPtr, srcBuf.length);
    Module._free(srcPtr);
    console.log('wasm_load handle=', handle);

    const p3 = Module._malloc(1024);
    console.log('After wasm_load: malloc(1024)=', p3);
    if (p3) Module._free(p3);

    // Try larger allocations
    for (const sz of [4096, 16384, 65536, 1048576]) {
        const p = Module._malloc(sz);
        console.log('  malloc(' + sz + ')=', p);
        if (p) Module._free(p);
    }

    console.log('=== DONE ===');
}
main().catch(e => { console.error('FATAL:', e); });
