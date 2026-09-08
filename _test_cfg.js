const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');

async function main() {
    const M = await createLuacModule();
    M._wasm_init();

    // Test with if-elseif-else code (has multiple basic blocks)
    const src = `local x = 5
if x > 10 then
    print("big")
elseif x > 5 then
    print("medium")
else
    print("small")
end
local i = 0
while i < 3 do
    print(i)
    i = i + 1
end
for j = 1, 3 do
    print(j)
end
print("done")`;

    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);
    console.log('handle=', h);

    // Apply cfg_shuffle
    const np = M._malloc(20);
    M.stringToUTF8('cfg_shuffle_c', np, 20);
    const r = M._wasm_apply(h, np);
    M._free(np);
    console.log('cfg_shuffle result=', r);

    if (r !== 0) {
        const ep = M._wasm_last_error();
        console.log('error:', M.UTF8ToString(ep));
        M._wasm_free(h);
        M._wasm_shutdown();
        return;
    }

    // Dump
    const lp = M._malloc(4);
    const op = M._wasm_dump(h, lp);
    const ol = M.getValue(lp, 'i32');
    M._free(lp);
    console.log('dump len=', ol);

    // Save output
    const out = Buffer.from(M.HEAPU8.subarray(op, op + ol));
    fs.writeFileSync('_cfg_test_out.luac', out);
    M._wasm_free_dump(op);
    M._wasm_free(h);
    M._wasm_shutdown();
    console.log('done');
}
main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
