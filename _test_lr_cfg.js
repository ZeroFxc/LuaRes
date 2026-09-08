const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');
(async () => {
    const M = await createLuacModule();
    M._wasm_init();
    const src = 'local x=10 if x>5 then print("big") end for j=1,3 do print(j) end print("done")';
    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);
    for (const mod of ['loop_restructure_c', 'cfg_shuffle_c']) {
        const np = M._malloc(30);
        M.stringToUTF8(mod, np, 30);
        const r = M._wasm_apply(h, np);
        M._free(np);
        console.log(mod + ' result=' + r);
    }
    const lp = M._malloc(4);
    const op = M._wasm_dump(h, lp);
    const ol = M.getValue(lp, 'i32');
    M._free(lp);
    const out = Buffer.from(M.HEAPU8.subarray(op, op + ol));
    fs.writeFileSync('_lr_cfg.luac', out);
    M._wasm_free_dump(op);
    M._wasm_free(h);
    M._wasm_shutdown();
    console.log('dump size=' + ol);
})();
