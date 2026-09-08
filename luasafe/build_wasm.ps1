$ErrorActionPreference = "Stop"
$emcc = "E:\Soft\Proje\LXCLUA-NCore\emsdk\upstream\emscripten\emcc.bat"
$luasafe = "E:\LuaRes\luasafe"
$luaclib = "E:\LuaRes\luaclib"
$out = "E:\LuaRes\luasafe\luac_wasm.js"

# luasafe core files (exclude lua.c standalone entry)
$core = @(
    "lapi.c","lcode.c","lctype.c","ldebug.c","ldo.c","ldump.c","lfunc.c",
    "lgc.c","llex.c","lmem.c","lobject.c","lopcodes.c","lparser.c","lstate.c",
    "lstring.c","ltable.c","ltm.c","lundump.c","lvm.c","lzio.c",
    "lauxlib.c","lbaselib.c","lbitlib.c","lcorolib.c","ldblib.c",
    "liolib.c","lmathlib.c","loslib.c","lstrlib.c","ltablib.c","lutf8lib.c",
    "loadlib.c","linit.c","lunsafe_stub.c"
) | ForEach-Object { Join-Path $luasafe $_ }

# luaclib files (exclude old single-file vm_asm.c, replaced by vm_asm/ modular version)
$lib = Get-ChildItem (Join-Path $luaclib "*.c") | Where-Object { $_.Name -ne 'vm_asm.c' } | ForEach-Object { $_.FullName }

# vm_asm files (模块化虚拟机组装器, exclude test_asm.c standalone)
$vmasm = Get-ChildItem (Join-Path $luaclib "vm_asm\*.c") | Where-Object { $_.Name -ne 'test_asm.c' } | ForEach-Object { $_.FullName }

$all = $core + $lib + $vmasm

Write-Host "Compiling $($all.Count) files with emcc..."
& $emcc -std=gnu99 -O2 -w -DLUA_COMPAT_5_2 `
    -s USE_ZLIB=1 `
    -I $luasafe -I $luaclib -I (Join-Path $luaclib "vm_asm") `
    -s ALLOW_MEMORY_GROWTH=1 `
    -s INITIAL_MEMORY=128MB `
    -s MAXIMUM_MEMORY=512MB `
    -s STACK_SIZE=8MB `
    -s "EXPORTED_FUNCTIONS=['_malloc','_free','_wasm_init','_wasm_load','_wasm_apply','_wasm_dump','_wasm_free_dump','_wasm_free','_wasm_modules','_wasm_last_error','_wasm_shutdown','_wasm_register_module','_wasm_apply_custom','_wasm_custom_modules','_wasm_all_modules','_wasm_module_info','_wasm_run_bytecode','_wasm_free_output','_wasm_inspect','_wasm_get_code_size','_wasm_get_instruction','_wasm_set_instruction','_wasm_insert_instruction','_wasm_delete_instruction','_wasm_get_k_size','_wasm_get_constant_type','_wasm_get_constant_number','_wasm_get_constant_string','_wasm_get_constant_bool','_wasm_set_constant_number','_wasm_set_constant_string','_wasm_set_constant_bool','_wasm_set_constant_nil','_wasm_add_constant_number','_wasm_add_constant_string','_wasm_remove_constant','_wasm_vm_embed']" `
    -s "EXPORTED_RUNTIME_METHODS=['ccall','cwrap','getValue','setValue','UTF8ToString','stringToUTF8','lengthBytesUTF8','HEAPU8']" `
    -s FILESYSTEM=0 `
    -s ENVIRONMENT=web `
    -s EXPORT_NAME="createLuacModule" `
    -s MODULARIZE=1 `
    -o $out `
    $all

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build OK: $out"
    Get-Item $out | Select-Object Name, Length
    $wasm = $out -replace '\.js$','.wasm'
    if (Test-Path $wasm) { Get-Item $wasm | Select-Object Name, Length }
} else {
    Write-Host "Build FAILED with code $LASTEXITCODE"
}
