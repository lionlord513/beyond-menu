"""Build a Nexus/Beyond Mod Manager ZIP and its GitHub update metadata."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
mod = root / 'mod/BeyondMenu'
metadata = json.loads((mod / 'bmm.json').read_text())
version = metadata['Version']
output = root / 'build'
output.mkdir(exist_ok=True)
archive = output / f'BeyondMenu-{version}-Nexus.zip'
prefix = 'DriveBeyondHorizons/Binaries/Win64/ue4ss/Mods/BeyondMenu/'

# Keep user data out of releases and fail the build if a runtime resource is missing.
files = [mod / 'bmm.json', mod / 'enabled.txt']
files += list((mod / 'Scripts').rglob('*.lua'))
files += list((mod / 'assets').rglob('*.png'))
files += list((mod / 'assets').rglob('*.txt'))
files += [mod / 'assets/native' / dll for dll in ('BeyondMenuImaging.dll', 'BeyondPaintballMesh.dll')]
paintball = mod / 'assets/paintball'
for required in ('marker.glb', 'canister.glb', 'ball.glb', 'shot.mp3', 'impact0.mp3', 'impact1.mp3', 'impact2.mp3', 'marker-albedo.png', 'marker-metallic.png', 'marker-roughness.png'):
    if not (paintball / required).is_file():
        raise FileNotFoundError(paintball / required)
files += [file for file in paintball.iterdir() if file.suffix in ('.glb', '.mp3')]
with zipfile.ZipFile(archive.with_suffix('.tmp'), 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for file in sorted(files):
        package.write(file, prefix + file.relative_to(mod).as_posix())
    for name in ('Update.ps1', 'Install.ps1', 'Uninstall.ps1', 'README.md', 'CHANGELOG.md', 'LICENSE.txt'):
        package.write(root / name, name)
archive.with_suffix('.tmp').replace(archive)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / 'SHA256SUMS.txt').write_text(f'{checksum}  {archive.name}\n')
manifest = {
    'schema': 1, 'version': version, 'channel': metadata['Channel'], 'asset': archive.name,
    'url': f'https://github.com/{metadata["Update"]["Repository"]}/releases/download/v{version}/{archive.name}',
    'sha256': checksum, 'size': archive.stat().st_size, 'notes': [metadata['Changelog']],
}
(output / 'bmm-mod.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(archive)
print('SHA256', checksum)
