param([string]$Zig='zig')
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot '..\mod\BeyondMenu\assets\native\BeyondMenuImaging.dll'
& $Zig cc -target x86_64-windows-gnu -O2 -shared (Join-Path $PSScriptRoot 'menu_native.c') -o $out -luser32 -lole32 -lwindowscodecs -luuid
if($LASTEXITCODE-ne0){throw 'Native helper build failed.'}
