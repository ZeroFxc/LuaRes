const fs=require('fs');
const createLuacModule=require('./luasafe/luac_wasm.js');
(async()=>{
  const M=await createLuacModule();
  M._wasm_init();
  const src=fs.readFileSync('_test_100cn.lua','utf8');
  const buf=Buffer.from(src,'utf8');
  const sp=M._malloc(buf.length);M.HEAPU8.set(buf,sp);
  const h=M._wasm_load(sp,buf.length);M._free(sp);
  console.log('handle='+h);
  // original dump
  const lp0=M._malloc(4);const op0=M._wasm_dump(h,lp0);const ol0=M.getValue(lp0,'i32');M._free(lp0);
  console.log('original bytecode size='+ol0);
  M._wasm_free_dump(op0);
  // apply str_encrypt
  const np=M._malloc(30);M.stringToUTF8('str_encrypt_c',np,30);
  const r=M._wasm_apply(h,np);M._free(np);
  console.log('str_encrypt result='+r);
  const lp=M._malloc(4);const op=M._wasm_dump(h,lp);const ol=M.getValue(lp,'i32');M._free(lp);
  const out=Buffer.from(M.HEAPU8.subarray(op,op+ol));
  fs.writeFileSync('_test_100cn_out.luac',out);
  M._wasm_free_dump(op);M._wasm_free(h);M._wasm_shutdown();
  console.log('encrypted bytecode size='+ol);
  console.log('increase='+(ol-ol0)+' bytes ('+((ol/ol0-1)*100).toFixed(1)+'%)');
})();
