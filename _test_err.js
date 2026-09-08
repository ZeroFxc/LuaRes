const fs=require('fs');
const createLuacModule=require('./luasafe/luac_wasm.js');
(async()=>{
  const M=await createLuacModule();
  M._wasm_init();
  const src='print("中文测试")';
  const sp=M._malloc(src.length);M.HEAPU8.set(Buffer.from(src),sp);
  const h=M._wasm_load(sp,src.length);M._free(sp);
  const np=M._malloc(30);M.stringToUTF8('str_encrypt_c',np,30);
  const r=M._wasm_apply(h,np);M._free(np);
  console.log('result='+r);
  const ep=M._wasm_last_error();
  if(ep) console.log('error='+M.UTF8ToString(ep));
  M._wasm_free(h);M._wasm_shutdown();
})();
