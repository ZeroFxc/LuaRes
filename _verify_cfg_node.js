const fs = require('fs');
const createLuacModule = require('./luasafe/luac_wasm.js');

async function main() {
    const M = await createLuacModule();
    M._wasm_init();

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
print("done")`;

    // Load original
    const sp = M._malloc(src.length);
    M.HEAPU8.set(Buffer.from(src), sp);
    const h = M._wasm_load(sp, src.length);
    M._free(sp);

    // Dump original bytecode
    const lp1 = M._malloc(4);
    const op1 = M._wasm_dump(h, lp1);
    const ol1 = M.getValue(lp1, 'i32');
    M._free(lp1);
    const orig = Buffer.from(M.HEAPU8.subarray(op1, op1 + ol1));
    M._wasm_free_dump(op1);

    // Apply cfg_shuffle
    const np = M._malloc(20);
    M.stringToUTF8('cfg_shuffle_c', np, 20);
    const r = M._wasm_apply(h, np);
    M._free(np);
    console.log('cfg_shuffle result=', r);

    // Dump new bytecode
    const lp2 = M._malloc(4);
    const op2 = M._wasm_dump(h, lp2);
    const ol2 = M.getValue(lp2, 'i32');
    M._free(lp2);
    const after = Buffer.from(M.HEAPU8.subarray(op2, op2 + ol2));
    M._wasm_free_dump(op2);
    M._wasm_free(h);
    M._wasm_shutdown();

    // Parse main proto code from bytecode (simplified: skip header, read main proto)
    function countOpcodes(bc) {
        // Lua 5.3 bytecode: header (12 bytes for luac_undump format)
        // Main proto starts after header. We need to parse the proto structure.
        // Simplified: just scan for instruction patterns in the main proto code section.
        // Actually, let's use a different approach: count JMP (op=30) by scanning 4-byte instructions.
        // The main proto code is after the proto header. Let's find it by parsing.
        let pos = 0;
        // Skip header: 0x1B or 0x1A, then version, format, endianness, sizes
        // For luasafe format, header is variable. Let's just find the code section.
        // The main proto has: sizecode (int), then code array.
        // We'll parse the proto minimally.
        function readByte() { return bc[pos++]; }
        function readInt() {
            const b0 = readByte(), b1 = readByte(), b2 = readByte(), b3 = readByte();
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        }
        function readString() {
            const len = readInt();
            if (len === 0) return null;
            pos += len;
            return '';
        }
        // Skip header bytes until we find proto start
        // Header: signature (4 bytes), version (1), format (1), endian (1), sizes (5 bytes)
        pos = 12; // approximate header size
        // Main proto:
        // firstline (int), numlines (int), numparams (byte), is_vararg (byte), maxstacksize (byte)
        readInt(); readInt(); readByte(); readByte(); readByte();
        // code: sizecode (int), then instructions
        const sizecode = readInt();
        const opcount = {};
        let jmpcount = 0;
        for (let i = 0; i < sizecode; i++) {
            const ins = readInt();
            const op = ins & 0x3F;
            opcount[op] = (opcount[op] || 0) + 1;
            if (op === 30) jmpcount++;
        }
        return { sizecode, jmpcount, opcount };
    }

    const a = countOpcodes(orig);
    const b = countOpcodes(after);

    console.log('\n=== ORIGINAL ===');
    console.log('sizecode:', a.sizecode, 'JMP:', a.jmpcount);
    console.log('=== CFG_SHUFFLE ===');
    console.log('sizecode:', b.sizecode, 'JMP:', b.jmpcount);
    console.log('\n=== SUMMARY ===');
    console.log(`Size: ${a.sizecode} -> ${b.sizecode} (${b.sizecode - a.sizecode >= 0 ? '+' : ''}${b.sizecode - a.sizecode})`);
    console.log(`JMP: ${a.jmpcount} -> ${b.jmpcount} (${b.jmpcount - a.jmpcount >= 0 ? '+' : ''}${b.jmpcount - a.jmpcount})`);

    if (b.sizecode !== a.sizecode || b.jmpcount !== a.jmpcount) {
        console.log('PASS: Bytecode changed (cfg_shuffle is effective)');
    } else {
        console.log('FAIL: Bytecode unchanged');
    }

    fs.writeFileSync('_cfg_verify_orig.luac', orig);
    fs.writeFileSync('_cfg_verify_after.luac', after);
}
main().catch(e => { console.error(e); process.exit(1); });
