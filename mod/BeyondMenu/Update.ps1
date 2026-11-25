param([string]$GamePath, [switch]$CheckOnly)
$ErrorActionPreference='Stop'
if (!$GamePath) { $GamePath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..')) }
$game=[IO.Path]::GetFullPath($GamePath).TrimEnd('\')
$exe=Join-Path $game 'DriveBeyondHorizons\Binaries\Win64\DriveBeyondHorizons-Win64-Shipping.exe'
if (!(Test-Path -LiteralPath $exe)) {throw 'Choose your game installation with -GamePath.'}
$headers=@{'User-Agent'='BeyondMenu-Updater';'Accept'='application/vnd.github+json'}
$release=Invoke-RestMethod -Uri 'https://api.github.com/repos/lionlord513/beyond-menu/releases/latest' -Headers $headers
if($release.tag_name -notmatch '^v(\d+\.\d+\.\d+)$'){throw 'Unrecognized release version.'}
$latest=$Matches[1];$installed=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bmm.json') -Raw|ConvertFrom-Json).Version
if([version]$latest -le [version]$installed){Write-Output "BeyondMenu $installed is up to date.";exit 0}
if($CheckOnly){Write-Output "BeyondMenu $latest is available.";exit 0}
if(Get-Process -Name 'DriveBeyondHorizons-Win64-Shipping' -ErrorAction SilentlyContinue|Where-Object {$_.Path-eq$exe}){throw 'Close this game installation before updating.'}
$asset=@($release.assets|Where-Object {$_.name-eq"BeyondMenu-$latest-Nexus.zip"})
$manifest=@($release.assets|Where-Object {$_.name-eq'bmm-mod.json'})
if($asset.Count-ne1-or$manifest.Count-ne1){throw 'The release is missing its package or checksum manifest.'}
$prefix="https://github.com/lionlord513/beyond-menu/releases/download/v$latest/"
if(!$asset[0].browser_download_url.StartsWith($prefix)-or!$manifest[0].browser_download_url.StartsWith($prefix)){throw 'Unexpected update location.'}
$meta=Invoke-RestMethod -Uri $manifest[0].browser_download_url -Headers $headers
if($meta.version-ne$latest-or$meta.asset-ne$asset[0].name-or$meta.sha256-notmatch'^[a-f0-9]{64}$'){throw 'Invalid update manifest.'}
$stage=Join-Path (Join-Path $PSScriptRoot 'state\updates') ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force|Out-Null
$zip=Join-Path $stage 'release.zip';Invoke-WebRequest -Uri $asset[0].browser_download_url -Headers $headers -OutFile $zip
if((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()-ne$meta.sha256){throw 'Update checksum failed. Nothing installed.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {foreach($entry in $archive.Entries){$p=$entry.FullName.Replace('\','/');if($p.StartsWith('/')-or$p.Contains(':')-or($p.Split('/')-contains'..')){throw 'Unsafe archive path.'}}}finally{$archive.Dispose()}
$extract=Join-Path $stage 'package';Expand-Archive -LiteralPath $zip -DestinationPath $extract
$installer=Join-Path $extract 'Install.ps1';if(!(Test-Path -LiteralPath $installer)){throw 'No installer in release.'}
& $installer -GamePath $game
Write-Output "Updated BeyondMenu to $latest."
