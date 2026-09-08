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
print("done")
local t = {a=1, b=2}
print(t.a + t.b)
local function add(a, b) return a + b end
print(add(5, 7))`;

const combos = [
    ['cfg_shuffle_c'],
    ['luac_flatten_c', 'cfg_shuffle_c'],
    ['cfg_shuffle_c', 'luac_flatten_c'],
    ['block_clone_c', 'cfg_shuffle_c'],
    ['cfg_shuffle_c', 'jmp_obfuscate_c'],
    ['str_encrypt_c', 'cfg_shuffle_c'],
    ['num_obfuscate_c', 'cfg_shuffle_c'],
    ['luac_flatten_c', 'block_clone_c', 'cfg_shuffle_c'],
    ['str_encrypt_c', 'str_split_c', 'num_obfuscate_c', 'cfg_shuffle_c'],
    ['luac_obfuscate_c', 'cfg_shuffle_c', 'jmp_obfuscate_c'],
];

async function testCombo(M, modules) {
    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);

    let allOk = true;
    for (const mod of modules) {
        const np = M._malloc(30);
        M.stringToUTF8(mod, np, 30);
        const r = M._wasm_apply(h, np);
        M._free(np);
        if (r !== 0) {
            allOk = false;
            break;
        }
    }

    if (!allOk) {
        M._wasm_free(h);
        return { ok: false, error: 'module failed' };
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

    for (const combo of combos) {
        const name = combo.join(' + ');
        try {
            const result = await testCombo(M, combo);
            if (result.ok) {
                process.stdout.write(`[PASS] ${name} (${result.size} bytes) - `);
                // Run verification
                const { execSync } = require('child_process');
                try {
                    const out = execSync('.\\luasafe\\lua_luac8.exe -e "local f=loadfile(\'_combo_test.luac\'); if f then f() else print(\'LOAD_FAIL\') end"', { encoding: 'utf8', timeout: 10000 });
                    if (out.includes('LOAD_FAIL') || out.includes('Error') || out.includes('error')) {
                        console.log('RUN_FAIL: ' + out.trim().split('\n')[0]);
                    } else {
                        console.log('RUN_OK');
                    }
                } catch (e) {
                    console.log('RUN_ERR: ' + e.message.split('\n')[0]);
                }
            } else {
                console.log(`[FAIL] ${name}: ${result.error}`);
            }
        } catch (e) {
            console.log(`[CRASH] ${name}: ${e.message.split('\n')[0]}`);
        }
    }

    M._wasm_shutdown();
}
main().catch(e => { console.error(e); process.exit(1); });
