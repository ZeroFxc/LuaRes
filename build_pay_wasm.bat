@echo off
setlocal
rem ============================================================
rem build_pay_wasm.bat - compile pay-sdk-c core to wasm
rem   network layer is done by JS (fetch); this module only does
rem   signing / decrypt / verify / json parsing.
rem   input : pay-sdk-c\src\pay_wasm.c (includes pay.c) + crypto sources
rem   output: web\pay_wasm.js + web\pay_wasm.wasm
rem   note  : http.c is NOT compiled; pay_wasm.c provides stubs
rem ============================================================
set EMSDK=E:\Soft\Proje\LXCLUA-NCore\emsdk
set PATH=%EMSDK%\upstream\emscripten;%EMSDK%\node\18.20.3_64bit\bin;%PATH%
cd /d E:\LuaRes

emcc -std=gnu99 -O2 -w ^
  -Ipay-sdk-c\include -Ipay-sdk-c\src ^
  pay-sdk-c\src\pay_wasm.c ^
  pay-sdk-c\src\aes.c pay-sdk-c\src\base64.c pay-sdk-c\src\hmac.c ^
  pay-sdk-c\src\json.c pay-sdk-c\src\sha256.c ^
  -s WASM=1 ^
  -s EXPORTED_FUNCTIONS=["_malloc","_free","_payw_init","_payw_version","_payw_build_request","_payw_parse_response","_payw_sg","_payw_gc"] ^
  -s EXPORTED_RUNTIME_METHODS=["ccall","cwrap","getValue","setValue","UTF8ToString","stringToUTF8","lengthBytesUTF8","writeArrayToMemory","HEAPU8"] ^
  -s INITIAL_MEMORY=8388608 -s ALLOW_MEMORY_GROWTH=1 ^
  -s MODULARIZE=1 -s EXPORT_NAME=createPayModule -s ENVIRONMENT=web,node ^
  -s FILESYSTEM=0 -s INVOKE_RUN=0 -s EXIT_RUNTIME=0 -s STANDALONE_WASM=0 --no-entry ^
  -o web\pay_wasm.js

echo EXIT=%ERRORLEVEL%
echo Build done: web\pay_wasm.wasm (no VMP obfuscation)
