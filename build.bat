@echo off
setlocal enabledelayedexpansion
cd /d E:\LuaRes

set "selected=0"

:menu
cls
echo ========================================
echo   Select build target (UP/DOWN + ENTER)
echo ========================================
echo.
if !selected!==0 (echo ^> 1. Windows MinGW) else (echo   1. Windows MinGW)
if !selected!==1 (echo ^> 2. androluajava NDK) else (echo   2. androluajava NDK)
if !selected!==2 (echo ^> 3. oldaluajava NDK) else (echo   3. oldaluajava NDK)
if !selected!==3 (echo ^> 4. andluanewjava NDK) else (echo   4. andluanewjava NDK)
if !selected!==4 (echo ^> 5. luasafe版本 NDK) else (echo   5. luasafe版本 NDK)
echo.

for /f "delims=" %%a in ('powershell -NoProfile -Command "$k=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode; if($k -eq 38){'UP'}elseif($k -eq 40){'DOWN'}elseif($k -eq 13){'ENTER'}else{'OTHER'}"') do set "key=%%a"

if "%key%"=="UP" (
    set /a selected-=1
    if !selected! lss 0 set selected=4
)
if "%key%"=="DOWN" (
    set /a selected+=1
    if !selected! gtr 4 set selected=0
)
if "%key%"=="ENTER" goto execute

goto menu

:execute
cls
if !selected!==0 goto build_windows
if !selected!==1 goto build_androluajava
if !selected!==2 goto build_oldaluajava
if !selected!==3 goto build_andluanewjava
if !selected!==4 goto build_luasafe

:build_windows
echo ========================================
echo   Building Windows MinGW
echo ========================================
echo.
set "PATH=E:\Env\mingw64\bin;%PATH%"
cd /d E:\LuaRes\lua
mingw32-make mingw
goto end

:build_androluajava
echo ========================================
echo   Building androluajava NDK
echo ========================================
echo.
cd /d E:\LuaRes
powershell -NoProfile -Command "(Get-Content Android.mk) -replace 'oldaluajava','androluajava' | Set-Content Android.mk"
"C:\Users\ruilo\AppData\Local\Android\Sdk\ndk\30.0.15729638\ndk-build.cmd" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:build_oldaluajava
echo ========================================
echo   Building oldaluajava NDK
echo ========================================
echo.
cd /d E:\LuaRes
powershell -NoProfile -Command "(Get-Content Android.mk) -replace 'androluajava','oldaluajava' | Set-Content Android.mk"
"C:\Users\ruilo\AppData\Local\Android\Sdk\ndk\30.0.15729638\ndk-build.cmd" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:build_andluanewjava
echo ========================================
echo   Building andluanewjava NDK (andlua + andluanewjava)
echo ========================================
echo.
cd /d E:\LuaRes
echo LOCAL_PATH := $(call my-dir) > Android.mk
echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk
echo. >> Android.mk
echo # Lua static library (andlua modified) >> Android.mk
echo include $(ROOT_PATH)/andlua/Android.mk >> Android.mk
echo. >> Android.mk
echo # luajava shared library (androlua - (long,int) params, modified) >> Android.mk
echo include $(ROOT_PATH)/andluanewjava/Android.mk >> Android.mk
"C:\Users\ruilo\AppData\Local\Android\Sdk\ndk\30.0.15729638\ndk-build.cmd" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:build_luasafe
echo ========================================
echo   Building luasafe版本 NDK (luasafe + andluanewjava)
echo ========================================
echo.
cd /d E:\LuaRes
echo LOCAL_PATH := $(call my-dir) > Android.mk
echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk
echo. >> Android.mk
echo # Lua static library (luasafe - andlua with bugfixes) >> Android.mk
echo include $(ROOT_PATH)/luasafe/Android.mk >> Android.mk
echo. >> Android.mk
echo # luajava shared library (androlua - (long,int) params, modified) >> Android.mk
echo include $(ROOT_PATH)/andluanewjava/Android.mk >> Android.mk
"C:\Users\ruilo\AppData\Local\Android\Sdk\ndk\30.0.15729638\ndk-build.cmd" NDK_PROJECT_PATH=E:\LuaRes APP_BUILD_SCRIPT=E:\LuaRes\Android.mk NDK_APPLICATION_MK=E:\LuaRes\Application.mk
goto end

:end
echo.
echo ========================================
echo   Build complete.
echo ========================================
pause
