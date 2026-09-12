@echo off
setlocal enabledelayedexpansion
cd /d E:\LuaRes

rem ============================================================
rem  build_native.bat - native exe build (CLI testing of obfuscators)
rem  entry: test_entry.c (registers luac module, then runs script)
rem  output: luasafe\lua_luac_c.exe
rem  usage: build_native.bat [full]    full = force full rebuild
rem ============================================================

set "OUT=luasafe\lua_luac_c.exe"
set "OBJDIR=build_native_bat"
set "ZLIB=E:\LuaRes\zlib-1.3.1"
set "ENTRY=test_entry.c"

if /I "%~1"=="full" set FULL=1

rem --- check compiler ---
where gcc >nul 2>nul
if errorlevel 1 (
    echo [ERROR] gcc not found in PATH.
    exit /b 1
)

if not exist "%OBJDIR%" mkdir "%OBJDIR%"
if not exist "%OBJDIR%\zlib" mkdir "%OBJDIR%\zlib"

set "FLAGS=-std=gnu99 -O2 -w -DLUA_COMPAT_5_2 -DVM_EMBED_NO_MAIN -DLUA_USE_WINDOWS"
set "INC=-Iluasafe -Iluaclib -Iluaclib\vm_asm -I%ZLIB%"

rem --- collect sources ---
set SRC=
for %%f in (luasafe\*.c) do (
    set "skip=0"
    if /I "%%~nxf"=="lua.c" set skip=1
    if /I "%%~nxf"=="luac.c" set skip=1
    if /I "%%~nxf"=="onelua.c" set skip=1
    if /I "%%~nxf"=="lunsafe_stub.c" set skip=1
    if /I "%%~nxf"=="main.c" set skip=1
    if "!skip!"=="0" set SRC=!SRC! %%f
)
for %%f in (luaclib\*.c) do (
    set "skip=0"
    if /I "%%~nxf"=="vm_asm.c" set skip=1
    if /I "%%~nxf"=="wasm_entry.c" set skip=1
    if "!skip!"=="0" set SRC=!SRC! %%f
)
for %%f in (luaclib\vm_asm\*.c) do (
    if /I not "%%~nxf"=="test_asm.c" set SRC=!SRC! %%f
)
for %%f in (%ZLIB%\*.c) do set SRC=!SRC! %%f
set SRC=!SRC! %ENTRY%

rem --- count sources ---
set CNT=0
for %%f in (%SRC%) do set /a CNT+=1
echo [info] %CNT% source files, objdir=%OBJDIR% (FULL=!FULL!)

set FAILED=0
if defined FULL goto full_build

rem --- incremental: generate temp ps1 (keep outside any block) ---
>  "%OBJDIR%\_stale.ps1" echo $srcs = '%SRC%' -split ' '
>> "%OBJDIR%\_stale.ps1" echo foreach ($s in $srcs) {
>> "%OBJDIR%\_stale.ps1" echo     $d = if ($s -like 'E:\LuaRes\zlib-1.3.1\*') { 'build_native_bat\zlib' } else { 'build_native_bat' }
>> "%OBJDIR%\_stale.ps1" echo     $o = $d + '\' + [IO.Path]::GetFileNameWithoutExtension($s) + '.o'
>> "%OBJDIR%\_stale.ps1" echo     if (-not (Test-Path $o)) { Write-Output $s; continue }
>> "%OBJDIR%\_stale.ps1" echo     if ((Get-Item $s).LastWriteTime -gt (Get-Item $o).LastWriteTime) { Write-Output $s }
>> "%OBJDIR%\_stale.ps1" echo }

set STALE=
for /f "delims=" %%x in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%OBJDIR%\_stale.ps1"') do set STALE=!STALE! %%x
del "%OBJDIR%\_stale.ps1" 2>nul
if defined STALE (
    for %%f in (%STALE%) do call :compile "%%f"
) else (
    echo [info] nothing to compile
)
goto after_compile

:full_build
echo [info] full rebuild
for %%f in (%SRC%) do call :compile "%%f"

:after_compile
if "%FAILED%"=="1" (
    echo [ERROR] compile failed, abort link.
    exit /b 1
)

rem --- collect all objects for link ---
set OBJS=
for %%f in (%SRC%) do (
    set "ODIR=!OBJDIR!"
    if /I "%%~dpf"=="%ZLIB%\" set "ODIR=!OBJDIR!\zlib"
    set OBJS=!OBJS! "!ODIR!\%%~nf.o"
)

rem --- link ---
echo [info] linking to %OUT%
gcc %FLAGS% %OBJS% -o "%OUT%" -lws2_32 -lm
if errorlevel 1 (
    echo [ERROR] link failed.
    exit /b 1
)
echo [OK] %OUT%
exit /b 0

:compile
set "CF=%~1"
set "ODIR=!OBJDIR!"
if /I "%~dp1"=="%ZLIB%\" set "ODIR=!OBJDIR!\zlib"
set "OBJ=!ODIR!\%~n1.o"
echo   CC %~n1
gcc %FLAGS% %INC% -c "!CF!" -o "!OBJ!"
if errorlevel 1 (
    echo   [FAIL] %~n1
    set FAILED=1
)
exit /b 0
