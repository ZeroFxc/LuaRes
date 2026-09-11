# build_pat.ps1 - pattern-initialized stack vars to expose uninitialized reads
$ErrorActionPreference = "Continue"
cd E:\LuaRes
$zlib = "E:\LuaRes\zlib-1.3.1"
$objdir = "E:\LuaRes\build_pat"
New-Item -ItemType Directory -Force -Path $objdir | Out-Null
$lsExclude = @('luac.c','lunsafe_stub.c','main.c')
$luasafe = Get-ChildItem luasafe\*.c | Where-Object { $lsExclude -notcontains $_.Name }
$clExclude = @('vm_asm.c','wasm_entry.c')
$luaclib = Get-ChildItem luaclib\*.c | Where-Object { $clExclude -notcontains $_.Name }
$vmasm = Get-ChildItem luaclib\vm_asm\*.c | Where-Object { $_.Name -ne 'test_asm.c' }
$zl = Get-ChildItem "$zlib\*.c"
$src = @($luasafe) + @($luaclib) + @($vmasm) + @($zl)
$inc = @('-Iluasafe','-Iluaclib','-Iluaclib\vm_asm',"-I$zlib")
$flags = @('-std=gnu99','-O0','-g','-ftrivial-auto-var-init=pattern','-DVM_EMBED_NO_MAIN','-DLUA_USE_WINDOWS')
$objs = @(); $failed = 0
foreach($s in $src){
  $o = Join-Path $objdir ($s.BaseName + '.o'); $objs += $o; $need = $true
  if(Test-Path $o){ if((Get-Item $o).LastWriteTime -ge $s.LastWriteTime){ $need = $false } }
  if($need){ & gcc @flags @inc -c $s.FullName -o $o 2>&1 | ForEach-Object { Write-Host $_ }; if($LASTEXITCODE -ne 0){ $failed++ } }
}
if($failed -gt 0){ Write-Host "FAIL $failed"; exit 1 }
& gcc @flags $objs -o luasafe\obf_pat.exe -lws2_32 -lm 2>&1 | ForEach-Object { Write-Host $_ }
Write-Host ("LINK EXIT=" + $LASTEXITCODE)
