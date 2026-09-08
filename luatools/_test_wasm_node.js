// Node.js test for WASM obfuscator with Chinese strings
const fs = require('fs');
const path = require('path');

const WASM_JS = path.join(__dirname, '..', 'luasafe', 'luac_wasm.js');
const WASM_WASM = path.join(__dirname, '..', 'luasafe', 'luac_wasm.wasm');

// Load the Emscripten module factory
const createModule = require(WASM_JS);

const EXEC_ORDER = [
  'const_hide_c','const_shuffle_c','str_encrypt_c','instruction_mutate_c',
  'num_obfuscate_c','str_split_c','bool_obfuscate_c','table_obfuscate_c',
  'opaque_predicate_c','const_poison_c','opaque_junk_c','junk_jmp_c',
  'junk_loadk_c','junk_move_c','luac_obfuscate_c','luac_flatten_c',
  'flatten_enhance_c','debug_strip_c','antidec_c','proto_shuffle_c',
  'live_range_split_c','op48_junk_c','reg_shuffle_c','junk_c',
  'condition_split_c','loop_restructure_c','jmp_obfuscate_c','indirect_call_c',
  'vm_embed_c'
];

const TEST_LUA = `print(6)
print("6")
print({6})
print({"6"})
print(true)
print(false)
print(nil)
print(6.6)
print((function (x) return {x} end)(6))
print((function (x) return x end)(6))
print((function() return 6 end)())
print((function (...) return ... end)(6))
print((function (...) return {...} end)(6))
print(#"6")
print(tostring(6).."")
local ver = _VERSION
if ver == "Lua 5.2" then
    print("运行在 Lua 5.2")
elseif ver == "Lua 5.3" then
    print("运行在 Lua 5.3")
elseif ver == "Lua 5.4" then
    print("运行在 Lua 5.4")
else
    print("未知版本:", ver)
end
`;

async function main() {
  console.log('Loading WASM module...');
  const wasmBinary = fs.readFileSync(WASM_WASM);
  const Module = await createModule({ wasmBinary });
  console.log('WASM loaded');

  Module.ccall('wasm_init', 'number', [], []);

  // Load test lua source
  const srcBytes = Buffer.from(TEST_LUA, 'utf-8');
  const srcPtr = Module._malloc(srcBytes.length);
  Module.HEAPU8.set(srcBytes, srcPtr);
  const handle = Module.ccall('wasm_load', 'number', ['number','number'], [srcPtr, srcBytes.length]);
  Module._free(srcPtr);
  if (handle < 0) {
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    console.error('Load failed:', err);
    process.exit(1);
  }
  console.log('Loaded, handle=', handle);

  // Apply all modules except vm_embed
  for (const mod of EXEC_ORDER) {
    if (mod === 'vm_embed_c') continue;
    const ret = Module.ccall('wasm_apply', 'number', ['number','string'], [handle, mod]);
    if (ret !== 0) {
      const err = Module.ccall('wasm_last_error', 'string', [], []);
      console.error('Module', mod, 'failed:', err);
      process.exit(1);
    }
    console.log('  OK:', mod);
  }

  // vm_embed
  const outLenPtr = Module._malloc(4);
  const outPtr = Module.ccall('wasm_vm_embed', 'number', ['number','number','number'], [handle, 0, outLenPtr]);
  const outLen = Module.getValue(outLenPtr, 'i32');
  Module._free(outLenPtr);
  if (!outPtr || outLen === 0) {
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    console.error('vm_embed failed:', err);
    process.exit(1);
  }
  const resultBytes = Buffer.from(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
  Module.ccall('wasm_free_output', null, ['number'], [outPtr]);
  Module.ccall('wasm_free', null, ['number'], [handle]);
  console.log('vm_embed done, size=', resultBytes.length);

  // Run the result
  const runPtr2 = Module._malloc(resultBytes.length);
  Module.HEAPU8.set(resultBytes, runPtr2);
  const runLenPtr = Module._malloc(4);
  const runPtr = Module.ccall('wasm_run_bytecode', 'number', ['number','number','number'], [runPtr2, resultBytes.length, runLenPtr]);
  const runLen = Module.getValue(runLenPtr, 'i32');
  Module._free(runPtr2);
  Module._free(runLenPtr);

  if (runPtr && runLen > 0) {
    const output = Buffer.from(Module.HEAPU8.subarray(runPtr, runPtr + runLen)).toString('utf-8');
    Module.ccall('wasm_free_output', null, ['number'], [runPtr]);
    console.log('\n=== RUN OUTPUT ===');
    console.log(output);
    console.log('=== END ===');

    // Check for Chinese string
    if (output.includes('运行在 Lua 5.3')) {
      console.log('\n[PASS] Chinese string output correct!');
    } else {
      console.log('\n[FAIL] Chinese string NOT found in output!');
      console.log('Looking for: 运行在 Lua 5.3');
      // Show bytes around where Chinese should be
      const lines = output.split('\n');
      console.log('Last 3 lines:');
      lines.slice(-3).forEach((l, i) => {
        console.log('  [' + i + '] len=' + l.length + ' bytes=' + Buffer.from(l, 'utf-8').toString('hex'));
      });
    }
  } else {
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    console.error('Run failed:', err);
    process.exit(1);
  }
}

main().catch(e => { console.error(e); process.exit(1); });
