"""Package only the standalone menu. No personal menu, runtime saves, or other mods."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1];mod=root/'mod/BeyondMenu'
meta=json.loads((mod/'bmm.json').read_text());version=meta['Version']
out=root/'build';out.mkdir(exist_ok=True)
name=f'BeyondMenu-{version}-Nexus.zip';archive=out/name
prefix='DriveBeyondHorizons/Binaries/Win64/ue4ss/Mods/BeyondMenu/'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as z:
 for f in sorted(mod.rglob('*')):
  if not f.is_file():continue
  rel=f.relative_to(mod).as_posix()
  if rel in ('bmm.json','enabled.txt','assets/native/BeyondMenuImaging.dll')or(rel.startswith('Scripts/')and f.suffix=='.lua')or(rel.startswith('assets/')and f.suffix in ('.png','.txt')):z.write(f,prefix+rel)
 for n in ('Update.ps1','Install.ps1','Uninstall.ps1','README.md','CHANGELOG.md','LICENSE.txt'):z.write(root/n,n)
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256SUMS.txt').write_text(f'{sha}  {name}\n')
manifest={'schema':1,'version':version,'channel':'stable','asset':name,'url':f'https://github.com/lionlord513/beyond-menu/releases/download/v{version}/{name}','sha256':sha,'size':archive.stat().st_size,'notes':[meta['Changelog']]}
(out/'bmm-mod.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(archive);print('SHA256',sha)
