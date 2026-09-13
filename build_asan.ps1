# build_asan.ps1 - ASAN/UBSAN 构建原生测试解释器（独立对象目录，全量）
$ErrorActionPreference = "Continue"
cd E:\LuaRes
$zlib = "E:\LuaRes\zlib-1.3.1"
$objdir = "E:\LuaRes\build_asan"
New-Item -ItemType Directory -Force -Path $objdir | Out-Null

$lsExclude = @('luac.c','lunsafe_stub.c','main.c')
$luasafe = Get-ChildItem luasafe\*.c | Where-Object { $lsExclude -notcontains $_.Name }
$clExclude = @('vm_asm.c','wasm_entry.c')
$luaclib = Get-ChildItem luaclib\*.c | Where-Object { $clExclude -notcontains $_.Name }
$vmasm = Get-ChildItem luaclib\vm_asm\*.c | Where-Object { $_.Name -ne 'test_asm.c' }
$zl = Get-ChildItem "$zlib\*.c"
$src = @($luasafe) + @($luaclib) + @($vmasm) + @($zl)

$inc = @('-Iluasafe','-Iluaclib','-Iluaclib\vm_asm',"-I$zlib")
$flags = @('-std=gnu99','-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer',
           '-DVM_EMBED_NO_MAIN','-DLUA_USE_WINDOWS')
$objs = @()
$failed = 0
foreach($s in $src){
  $o = Join-Path $objdir ($s.BaseName + '.o')
  $objs += $o
  $need = $true
  if(Test-Path $o){ if((Get-Item $o).LastWriteTime -ge $s.LastWriteTime){ $need = $false } }
  if($need){
    & gcc @flags @inc -c $s.FullName -o $o 2>&1 | ForEach-Object { Write-Host $_ }
    if($LASTEXITCODE -ne 0){ Write-Host ("COMPILE FAIL: " + $s.Name); $failed++ }
  }
}
if($failed -gt 0){ Write-Host "=== $failed compile failures, abort link ==="; exit 1 }

Write-Host ("linking " + $objs.Count + " objects ...")
& gcc @flags $objs -o luasafe\obf_asan.exe -lws2_32 -lm 2>&1 | ForEach-Object { Write-Host $_ }
Write-Host ("LINK EXIT=" + $LASTEXITCODE)
