const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');
(async () => {
    const M = await createLuacModule();
    M._wasm_init();
    const src = 'print(666)';
    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);
    const np = M._malloc(30);
    M.stringToUTF8('vm_embed_c', np, 30);
    const r = M._wasm_apply(h, np);
    M._free(np);
    console.log('vm_embed result=' + r);
    const lp = M._malloc(4);
    const op = M._wasm_dump(h, lp);
    const ol = M.getValue(lp, 'i32');
    M._free(lp);
    const out = Buffer.from(M.HEAPU8.subarray(op, op + ol)).toString('utf8');
    M._wasm_free_dump(op);
    M._wasm_free(h);
    M._wasm_shutdown();
    fs.writeFileSync('_vm_no_comment.lua', out);
    // 检查是否还有Lua注释
    const lines = out.split('\n');
    let commentCount = 0;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('--') || line.startsWith('--[[')) {
            console.log(`Comment found at line ${i+1}: ${line.substring(0, 80)}`);
            commentCount++;
        }
    }
    console.log(`\nTotal lines: ${lines.length}`);
    console.log(`Comment lines found: ${commentCount}`);
    if (commentCount === 0) {
        console.log('PASS: No Lua comments in generated output');
    } else {
        console.log('FAIL: Lua comments still present');
    }
    // 验证运行
    const { execSync } = require('child_process');
    try {
        const runOut = execSync('.\\luasafe\\lua_luac8.exe _vm_no_comment.lua', { encoding: 'utf8', timeout: 10000 });
        console.log(`Run output: ${runOut.trim()}`);
    } catch (e) {
        console.log(`Run error: ${e.message.split('\n')[0]}`);
    }
})();
