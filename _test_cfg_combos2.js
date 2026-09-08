const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');

const src = `local x = 10
if x > 5 then
    print("big")
elseif x > 2 then
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
repeat
    print("repeat")
    i = i - 1
until i <= 0
local t = {a=1, b=2}
print(t.a + t.b)
local function add(a, b) return a + b end
print(add(5, 7))
print("done")`;

const combos = [
    // 控制流模块互组合
    ['luac_flatten_c', 'flatten_enhance_c', 'cfg_shuffle_c'],
    ['cfg_shuffle_c', 'luac_flatten_c', 'flatten_enhance_c'],
    ['condition_split_c', 'cfg_shuffle_c'],
    ['cfg_shuffle_c', 'condition_split_c'],
    ['loop_restructure_c', 'cfg_shuffle_c'],
    ['cfg_shuffle_c', 'loop_restructure_c'],
    ['block_clone_c', 'cfg_shuffle_c', 'jmp_obfuscate_c'],
    // 控制流 + 数据混淆
    ['str_encrypt_c', 'str_split_c', 'cfg_shuffle_c', 'luac_flatten_c'],
    ['num_obfuscate_c', 'const_hide_c', 'cfg_shuffle_c'],
    ['table_obfuscate_c', 'cfg_shuffle_c'],
    ['bool_obfuscate_c', 'cfg_shuffle_c'],
    // 全控制流大杂烩
    ['luac_flatten_c', 'flatten_enhance_c', 'block_clone_c', 'cfg_shuffle_c', 'jmp_obfuscate_c', 'condition_split_c'],
    // 与vm_embed组合
    ['cfg_shuffle_c', 'vm_embed_c'],
    ['str_encrypt_c', 'cfg_shuffle_c', 'vm_embed_c'],
];

async function testCombo(M, modules) {
    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);

    let allOk = true;
    let failMod = '';
    for (const mod of modules) {
        const np = M._malloc(30);
        M.stringToUTF8(mod, np, 30);
        const r = M._wasm_apply(h, np);
        M._free(np);
        if (r !== 0) {
            allOk = false;
            failMod = mod;
            break;
        }
    }

    if (!allOk) {
        M._wasm_free(h);
        return { ok: false, error: 'module failed: ' + failMod };
    }

    const lp = M._malloc(4);
    const op = M._wasm_dump(h, lp);
    const ol = M.getValue(lp, 'i32');
    M._free(lp);
    const out = Buffer.from(M.HEAPU8.subarray(op, op + ol));
    M._wasm_free_dump(op);
    M._wasm_free(h);

    fs.writeFileSync('_combo_test.luac', out);
    return { ok: true, size: ol };
}

async function main() {
    const M = await createLuacModule();
    M._wasm_init();

    let pass = 0, fail = 0;
    for (const combo of combos) {
        const name = combo.join(' + ');
        try {
            const result = await testCombo(M, combo);
            if (result.ok) {
                process.stdout.write(`[APPLY_OK] ${name} (${result.size}B) - `);
                const { execSync } = require('child_process');
                try {
                    const out = execSync('.\\luasafe\\lua_luac8.exe -e "local f=loadfile(\'_combo_test.luac\'); if f then f() else print(\'LOAD_FAIL\') end"', { encoding: 'utf8', timeout: 15000 });
                    if (out.includes('LOAD_FAIL') || out.includes('Error') || out.includes('error') || out.includes('attempt to')) {
                        console.log('RUN_FAIL: ' + out.trim().split('\n')[0]);
                        fail++;
                    } else {
                        console.log('RUN_OK');
                        pass++;
                    }
                } catch (e) {
                    console.log('RUN_ERR: ' + e.message.split('\n')[0]);
                    fail++;
                }
            } else {
                console.log(`[APPLY_FAIL] ${name}: ${result.error}`);
                fail++;
            }
        } catch (e) {
            console.log(`[CRASH] ${name}: ${e.message.split('\n')[0]}`);
            fail++;
        }
    }

    M._wasm_shutdown();
    console.log(`\n=== TOTAL: ${pass} PASS, ${fail} FAIL ===`);
}
main().catch(e => { console.error(e); process.exit(1); });
