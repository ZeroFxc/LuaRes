@echo off
setlocal enabledelayedexpansion
set EMSDK=E:\Soft\Proje\LXCLUA-NCore\emsdk
set PATH=%EMSDK%;%EMSDK%\upstream\emscripten;%EMSDK%\node\18.20.3_64bit\bin;%PATH%
cd /d E:\LuaRes

set CORE=luasafe\lapi.c luasafe\lcode.c luasafe\lctype.c luasafe\ldebug.c luasafe\ldo.c luasafe\ldump.c luasafe\lfunc.c luasafe\lgc.c luasafe\llex.c luasafe\lmem.c luasafe\lobject.c luasafe\lopcodes.c luasafe\lparser.c luasafe\lstate.c luasafe\lstring.c luasafe\ltable.c luasafe\ltm.c luasafe\lundump.c luasafe\lvm.c luasafe\lzio.c luasafe\lauxlib.c luasafe\lbaselib.c luasafe\lbitlib.c luasafe\lcorolib.c luasafe\ldblib.c luasafe\liolib.c luasafe\lmathlib.c luasafe\loslib.c luasafe\lstrlib.c luasafe\ltablib.c luasafe\lutf8lib.c luasafe\loadlib.c luasafe\linit.c luasafe\lunsafe_stub.c luasafe\luacapi_log.c luasafe\luacapi_log_lua.c

set FILES=
for %%f in (luaclib\*.c) do (
    if /I not "%%~nxf"=="vm_asm.c" if /I not "%%~nxf"=="wasm_entry.c" set FILES=!FILES! %%f
)
set VMFILES=
for %%f in (luaclib\vm_asm\*.c) do (
    if /I not "%%~nxf"=="test_asm.c" set VMFILES=!VMFILES! %%f
)

echo FILES=%FILES%
echo VMFILES=%VMFILES%
emcc -std=gnu99 -O2 -w -mtail-call -DLUA_COMPAT_5_2 -DVM_EMBED_NO_MAIN ^
  -IE:\LuaRes\luasafe -IE:\LuaRes\luaclib -IE:\LuaRes\luaclib\vm_asm -IE:\LuaRes\zlib-1.3.1 ^
  %CORE% %FILES% %VMFILES% luaclib\wasm_entry.c ^
  -s WASM=1 ^
  -s EXPORTED_FUNCTIONS=["_malloc","_free","_wasm_init","_wasm_load","_wasm_apply","_wasm_dump","_wasm_free_dump","_wasm_vm_embed","_wasm_free","_wasm_modules","_wasm_last_error","_wasm_shutdown","_wasm_register_module","_wasm_apply_custom","_wasm_custom_modules","_wasm_all_modules","_wasm_module_info","_wasm_run_bytecode","_wasm_free_output","_wasm_inspect","_wasm_get_code_size","_wasm_get_instruction","_wasm_set_instruction","_wasm_insert_instruction","_wasm_delete_instruction","_wasm_get_k_size","_wasm_get_constant_type","_wasm_get_constant_number","_wasm_get_constant_string","_wasm_get_constant_bool","_wasm_set_constant_number","_wasm_set_constant_string","_wasm_set_constant_bool","_wasm_set_constant_nil","_wasm_add_constant_number","_wasm_add_constant_string","_wasm_remove_constant"] ^
  -s EXPORTED_RUNTIME_METHODS=["ccall","cwrap","getValue","setValue","UTF8ToString","stringToUTF8","lengthBytesUTF8","writeArrayToMemory","HEAPU8","addFunction","removeFunction","ALLOC_NORMAL","ALLOC_STACK"] ^
  -s INITIAL_MEMORY=134217728 -s MAXIMUM_MEMORY=536870912 -s ALLOW_MEMORY_GROWTH=1 -s STACK_SIZE=16777216 -s USE_ZLIB=1 ^
  -s MODULARIZE=1 -s EXPORT_NAME=createLuacModule -s ENVIRONMENT=web,node ^
  -s FILESYSTEM=0 -s INVOKE_RUN=0 -s EXIT_RUNTIME=0 -s STANDALONE_WASM=0 --no-entry ^
  -o luasafe\luac_wasm.js

echo EXIT=%ERRORLEVEL%
echo Build done: luasafe\luac_wasm.wasm (no VMP obfuscation)
