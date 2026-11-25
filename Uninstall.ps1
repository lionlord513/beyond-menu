param([string]$GamePath = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Drive Beyond Horizons")
$ErrorActionPreference='Stop'
$game=[IO.Path]::GetFullPath($GamePath).TrimEnd('\')
$bin=Join-Path $game 'DriveBeyondHorizons\Binaries\Win64'
$exe=Join-Path $bin 'DriveBeyondHorizons-Win64-Shipping.exe'
if (!(Test-Path -LiteralPath $exe)) {throw 'Invalid game installation.'}
if (Get-Process -Name 'DriveBeyondHorizons-Win64-Shipping' -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}) {throw 'Close this game installation first.'}
$mods=Join-Path $bin 'ue4ss\Mods';$utf8=New-Object Text.UTF8Encoding($false)
$list=Join-Path $mods 'mods.txt'
if (Test-Path -LiteralPath $list) {[IO.File]::WriteAllText($list,[regex]::Replace([IO.File]::ReadAllText($list),'(?m)^\s*BeyondMenu\s*:[^\r\n]*','BeyondMenu : 0'),$utf8)}
$marker=Join-Path $mods 'BeyondMenu\enabled.txt';if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}
foreach($name in @('BeyondApocalypse','BasicM4','BeyondTuning')) {
 $main=Join-Path $mods "$name\Scripts\main.lua"
 if(Test-Path -LiteralPath $main){$text=[IO.File]::ReadAllText($main);$clean=[regex]::Replace($text,'(?s)\r?\n-- BEGIN BEYONDMENU PROVIDER\r?\n.*?-- END BEYONDMENU PROVIDER\r?\n','');if($text-ne$clean){[IO.File]::WriteAllText($main,$clean,$utf8)}}
}
Write-Output 'BeyondMenu disabled and optional integrations removed. Its settings and files are retained.'
