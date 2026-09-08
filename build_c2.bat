@echo off
setlocal enabledelayedexpansion
cd /d E:\LuaRes
set "CLANG=C:\Program Files\LLVM\bin\clang.exe"
if not exist "%CLANG%" for /f "delims=" %%a in ('where clang 2^>nul') do set "CLANG=%%a"
echo Using clang: %CLANG%

del /q lua_luac_c2.exe 2>nul

set CORE=
for %%f in (luasafe\*.c) do (
    if /I not "%%~nxf"=="main.c" if /I not "%%~nxf"=="luac.c" if /I not "%%~nxf"=="lunsafe_stub.c" set CORE=!CORE! %%f
)
set FILES=
for %%f in (luaclib\*.c) do (
    if /I not "%%~nxf"=="vm_asm.c" if /I not "%%~nxf"=="wasm_entry.c" set FILES=!FILES! %%f
)
set VMFILES=
for %%f in (luaclib\vm_asm\*.c) do (
    if /I not "%%~nxf"=="test_asm.c" set VMFILES=!VMFILES! %%f
)

"%CLANG%" -O2 -DVM_EMBED_NO_MAIN -DLUA_USE_WINDOWS ^
  -IE:\LuaRes\zlib-1.3.1 -IE:\LuaRes\luasafe -IE:\LuaRes\luaclib -IE:\LuaRes\luaclib\vm_asm ^
  %CORE% %FILES% %VMFILES% ^
  -lws2_32 E:\LuaRes\zlib-1.3.1\libz.a -o lua_luac_c2.exe
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo BUILD OK
