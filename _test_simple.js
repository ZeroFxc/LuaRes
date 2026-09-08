const fs=require('fs');
const createLuacModule=require('./luasafe/luac_wasm.js');
(async()=>{
  const M=await createLuacModule();
  M._wasm_init();
  const src='print("中文测试")';
  const buf=Buffer.from(src,'utf8');
  const sp=M._malloc(buf.length);M.HEAPU8.set(buf,sp);
  const h=M._wasm_load(sp,buf.length);M._free(sp);
  console.log('handle='+h);
  if(h<0){const ep=M._wasm_last_error();if(ep)console.log('load error='+M.UTF8ToString(ep));M._wasm_shutdown();return;}
  const np=M._malloc(30);M.stringToUTF8('str_encrypt_c',np,30);
  const r=M._wasm_apply(h,np);M._free(np);
  console.log('result='+r);
  if(r<0){const ep=M._wasm_last_error();if(ep)console.log('apply error='+M.UTF8ToString(ep));}
  const lp=M._malloc(4);const op=M._wasm_dump(h,lp);const ol=M.getValue(lp,'i32');M._free(lp);
  if(ol>0){const out=Buffer.from(M.HEAPU8.subarray(op,op+ol));fs.writeFileSync('_simple_out.luac',out);console.log('output size='+ol);}
  M._wasm_free_dump(op);M._wasm_free(h);M._wasm_shutdown();
})();
