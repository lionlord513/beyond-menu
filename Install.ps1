param([string]$GamePath = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Drive Beyond Horizons")
$ErrorActionPreference = 'Stop'
$game = [IO.Path]::GetFullPath($GamePath).TrimEnd('\')
$relative = 'DriveBeyondHorizons\Binaries\Win64'
$exe = Join-Path $game "$relative\DriveBeyondHorizons-Win64-Shipping.exe"
if (!(Test-Path -LiteralPath $exe)) { throw 'Choose the Drive Beyond Horizons installation with -GamePath.' }
if (Get-Process -Name 'DriveBeyondHorizons-Win64-Shipping' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) { throw 'Close this game installation before installing BeyondMenu.' }
$mods = Join-Path $game "$relative\ue4ss\Mods"
if (!(Test-Path -LiteralPath (Join-Path $game "$relative\ue4ss\UE4SS.dll"))) { throw 'Install UE4SS first. BeyondMenu does not bundle other mods or replace your loader.' }
$source = Join-Path $PSScriptRoot "$relative\ue4ss\Mods\BeyondMenu"
if (!(Test-Path -LiteralPath "$source\Scripts\main.lua")) { $source = Join-Path $PSScriptRoot 'mod\BeyondMenu' }
if (!(Test-Path -LiteralPath "$source\Scripts\main.lua")) { throw 'Extract the complete BeyondMenu download before installing.' }
$destination = Join-Path $mods 'BeyondMenu'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($item in Get-ChildItem -LiteralPath $source) {
 if ($item.Name -in @('state','settings.ini')) { continue }
 Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force
}
$utf8 = New-Object Text.UTF8Encoding($false)
$listPath = Join-Path $mods 'mods.txt'
$list = if (Test-Path -LiteralPath $listPath) { [IO.File]::ReadAllText($listPath) } else { '' }
if ($list -match '(?m)^\s*BeyondMenu\s*:') { $list = [regex]::Replace($list,'(?m)^\s*BeyondMenu\s*:[^\r\n]*','BeyondMenu : 1') }
else { $list = $list.TrimEnd()+"`r`nBeyondMenu : 1`r`n" }
[IO.File]::WriteAllText($listPath,$list,$utf8)
[IO.File]::WriteAllText((Join-Path $destination 'enabled.txt'),'',$utf8)
$backup = Join-Path $destination ('state\integration-backups\'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
foreach ($entry in @(@('BeyondApocalypse','M','apocalypse'),@('BasicM4','M','apocalypse'),@('BeyondTuning','T','tuning'))) {
 $main = Join-Path $mods ($entry[0]+'\Scripts\main.lua')
 if (!(Test-Path -LiteralPath $main)) { continue }
 $original = [IO.File]::ReadAllText($main)
 $clean = [regex]::Replace($original,'(?s)\r?\n-- BEGIN BEYONDMENU PROVIDER\r?\n.*?-- END BEYONDMENU PROVIDER\r?\n','')
 if ($clean -notmatch ('return\s+'+$entry[1]+'\s*$')) { Write-Warning ('Optional integration skipped: '+$entry[0]+' has an unfamiliar entry point.'); continue }
 $bridge = @'
-- BEGIN BEYONDMENU PROVIDER
do
 local ok,err=pcall(function()
  local scripts=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
  local mods=scripts..'/../..';local root=mods..'/BeyondMenu'
  local enabled=io.open(root..'/enabled.txt','r');local active=enabled~=nil;if enabled then enabled:close()end
  local list=io.open(mods..'/mods.txt','r');if list then for line in list:lines()do local v=line:match('^%s*BeyondMenu%s*:%s*(%d)');if v then active=v=='1'end end;list:close()end
  if not active then return end
  local path=root..'/Scripts/provider_PROVIDER.lua';local file=io.open(path,'r');if not file then return end;file:close()
  dofile(path)(STATE,root)
 end)
 if not ok then print('[BeyondMenu] Optional provider: '..tostring(err)..'\n')end
end
-- END BEYONDMENU PROVIDER

'@
 $bridge = $bridge.Replace('PROVIDER.lua',$entry[2]+'.lua').Replace('(STATE,root)','('+$entry[1]+',root)')
 $updated = [regex]::Replace($clean,('return\s+'+$entry[1]+'\s*$'),[Text.RegularExpressions.MatchEvaluator]{param($m) "`n"+$bridge+$m.Value})
 if ($updated -ne $original) {
  New-Item -ItemType Directory -Force -Path $backup | Out-Null
  Copy-Item -LiteralPath $main -Destination (Join-Path $backup ($entry[0]+'-main.lua'))
  [IO.File]::WriteAllText($main,$updated,$utf8)
 }
}
Write-Output 'BeyondMenu installed. Open with F8. Your personal menu keeps its existing shortcut.'
