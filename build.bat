@echo off
setlocal enabledelayedexpansion
cd /d E:\LuaRes

set "selected=0"
set "NDK=C:\Users\ruilo\AppData\Local\Android\Sdk\ndk\30.0.15729638\ndk-build.cmd"
set "MINGW=E:\Env\mingw64\bin"
set "ZLIB=E:\LuaRes\zlib-1.3.1"
set "LUACLIB=E:\LuaRes\luaclib\luac.c"

:menu
cls
echo ========================================
echo   Select build target (UP/DOWN + ENTER)
echo ========================================
echo.
if !selected!==0 (echo ^> 1. luasafe Windows (gcc)) else (echo   1. luasafe Windows (gcc))
if !selected!==1 (echo ^> 2. androluajava NDK (luasafe+androluajava)) else (echo   2. androluajava NDK (luasafe+androluajava))
if !selected!==2 (echo ^> 3. oldaluajava NDK (luasafe+oldaluajava)) else (echo   3. oldaluajava NDK (luasafe+oldaluajava))
if !selected!==3 (echo ^> 4. andluanewjava NDK (luasafe+andluanewjava)) else (echo   4. andluanewjava NDK (luasafe+andluanewjava))
echo.

for /f "delims=" %%a in ('powershell -NoProfile -Command "$k=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode; if($k -eq 38){'UP'}elseif($k -eq 40){'DOWN'}elseif($k -eq 13){'ENTER'}else{'OTHER'}"') do set "key=%%a"

if "%key%"=="UP" (
    set /a selected-=1
    if !selected! lss 0 set selected=3
)
if "%key%"=="DOWN" (
    set /a selected+=1
    if !selected! gtr 3 set selected=0
)
if "%key%"=="ENTER" goto execute

goto menu

:execute
cls
if !selected!==0 goto build_luasafe_windows
if !selected!==1 goto build_androluajava
if !selected!==2 goto build_oldaluajava
if !selected!==3 goto build_andluanewjava

:build_luasafe_windows
echo ========================================
echo   Building luasafe Windows (gcc)
echo ========================================
echo.
taskkill /f /im lua_luac.exe 2>nul
set "PATH=%MINGW%;%PATH%"
cd /d E:\LuaRes\luasafe
gcc -std=gnu99 -O2 -I E:\LuaRes\luasafe -I %ZLIB% -o lua_luac.exe ^
  lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c ^
  lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ^
  ltm.c lundump.c lvm.c lzio.c ^
  lauxlib.c lbaselib.c lbitlib.c lcorolib.c ldblib.c liolib.c ^
  lmathlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c loadlib.c linit.c ^
  lunsafe.c %LUACLIB% ^
  %ZLIB%\adler32.c %ZLIB%\compress.c %ZLIB%\crc32.c %ZLIB%\deflate.c ^
  %ZLIB%\infback.c %ZLIB%\inffast.c %ZLIB%\inflate.c %ZLIB%\inftrees.c ^
  %ZLIB%\trees.c %ZLIB%\uncompr.c %ZLIB%\zutil.c ^
  lua.c -lm
if exist lua_luac.exe echo Build OK: lua_luac.exe
goto end

:build_androluajava
echo ========================================
echo   Building androluajava NDK (luasafe+androluajava)
echo ========================================
echo.
cd /d E:\LuaRes
echo LOCAL_PATH := $(call my-dir) > Android.mk
echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk
echo. >> Android.mk
echo # Lua static library (luasafe) >> Android.mk
echo include $(ROOT_PATH)/luasafe/Android.mk >> Android.mk
echo. >> Android.mk
echo # luajava shared library (androluajava) >> Android.mk
echo include $(ROOT_PATH)/androluajava/Android.mk >> Android.mk
"%NDK%" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:build_oldaluajava
echo ========================================
echo   Building oldaluajava NDK (luasafe+oldaluajava)
echo ========================================
echo.
cd /d E:\LuaRes
echo LOCAL_PATH := $(call my-dir) > Android.mk
echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk
echo. >> Android.mk
echo # Lua static library (luasafe) >> Android.mk
echo include $(ROOT_PATH)/luasafe/Android.mk >> Android.mk
echo. >> Android.mk
echo # luajava shared library (oldaluajava) >> Android.mk
echo include $(ROOT_PATH)/oldaluajava/Android.mk >> Android.mk
"%NDK%" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:build_andluanewjava
echo ========================================
echo   Building andluanewjava NDK (luasafe+andluanewjava)
echo ========================================
echo.
cd /d E:\LuaRes
echo LOCAL_PATH := $(call my-dir) > Android.mk
echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk
echo. >> Android.mk
echo # Lua static library (luasafe) >> Android.mk
echo include $(ROOT_PATH)/luasafe/Android.mk >> Android.mk
echo. >> Android.mk
echo # luajava shared library (andluanewjava) >> Android.mk
echo include $(ROOT_PATH)/andluanewjava/Android.mk >> Android.mk
"%NDK%" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:end
echo.
echo ========================================
echo   Build complete.
echo ========================================
pause
