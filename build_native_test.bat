@echo off
setlocal enabledelayedexpansion
set "MINGW=E:\Env\mingw64\bin"
set "ZLIB=E:\LuaRes\zlib-1.3.1"
set "PATH=%MINGW%;%PATH%"
cd /d E:\LuaRes

set CORE=luasafe\lapi.c luasafe\lcode.c luasafe\lctype.c luasafe\ldebug.c luasafe\ldo.c luasafe\ldump.c luasafe\lfunc.c luasafe\lgc.c luasafe\llex.c luasafe\lmem.c luasafe\lobject.c luasafe\lopcodes.c luasafe\lparser.c luasafe\lstate.c luasafe\lstring.c luasafe\ltable.c luasafe\ltm.c luasafe\lundump.c luasafe\lvm.c luasafe\lzio.c luasafe\lauxlib.c luasafe\lbaselib.c luasafe\lbitlib.c luasafe\lcorolib.c luasafe\ldblib.c luasafe\liolib.c luasafe\lmathlib.c luasafe\loslib.c luasafe\lstrlib.c luasafe\ltablib.c luasafe\lutf8lib.c luasafe\loadlib.c luasafe\linit.c luasafe\lunsafe_stub.c

set FILES=
for %%f in (luaclib\*.c) do (
    if /I not "%%~nxf"=="vm_asm.c" if /I not "%%~nxf"=="wasm_entry.c" set FILES=!FILES! %%f
)
set VMFILES=
for %%f in (luaclib\vm_asm\*.c) do (
    if /I not "%%~nxf"=="test_asm.c" set VMFILES=!VMFILES! %%f
)

set ZLIBSRC=%ZLIB%\adler32.c %ZLIB%\compress.c %ZLIB%\crc32.c %ZLIB%\deflate.c %ZLIB%\infback.c %ZLIB%\inffast.c %ZLIB%\inflate.c %ZLIB%\inftrees.c %ZLIB%\trees.c %ZLIB%\uncompr.c %ZLIB%\zutil.c

gcc -std=gnu99 -O0 -g -w -DCONST_HIDE_DEBUG -DLUA_COMPAT_5_2 -DVM_EMBED_NO_MAIN ^
  -IE:\LuaRes\luasafe -IE:\LuaRes\luaclib -IE:\LuaRes\luaclib\vm_asm -I%ZLIB% ^
  %CORE% %FILES% %VMFILES% %ZLIBSRC% native_test.c ^
  -o native_test.exe -lm

if exist native_test.exe (echo Build OK: native_test.exe) else (echo Build FAILED)
