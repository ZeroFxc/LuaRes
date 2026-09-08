const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');

async function main() {
    const M = await createLuacModule();
    M._wasm_init();

    // Simple for loop test
    const src = `for j = 1, 3 do
    print(j)
end
print("done")`;

    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);

    const np = M._malloc(20);
    M.stringToUTF8('cfg_shuffle_c', np, 20);
    const r = M._wasm_apply(h, np);
    M._free(np);
    console.log('result=', r);

    const lp = M._malloc(4);
    const op = M._wasm_dump(h, lp);
    const ol = M.getValue(lp, 'i32');
    M._free(lp);
    const out = Buffer.from(M.HEAPU8.subarray(op, op + ol));
    fs.writeFileSync('_cfg_for.luac', out);
    M._wasm_free_dump(op);
    M._wasm_free(h);
    M._wasm_shutdown();
}
main().catch(e => { console.error(e); process.exit(1); });
