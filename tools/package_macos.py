"""Build a uniquely identified local app without replacing an older package."""
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

from build_manifest import ROOT, configured_renderer, manifest, sha256, source_identity


def build():
    requested = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
    engine = Path(shutil.which(requested) or requested).resolve()
    identity = manifest()
    identity['engine_version'] = subprocess.check_output([str(engine), '--version'], text=True).strip()
    config = (ROOT / 'project.godot').read_text()
    app_version = re.search(r'config/version="([^"]+)"', config).group(1)
    renderer = configured_renderer(config, 'macos')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    build_id = f"{stamp}-{identity['source_commit'][:8]}-{identity['source_sha256'][:8]}"
    output = ROOT / 'build' / 'baselines' / build_id
    output.mkdir(parents=True, exist_ok=False)
    identity.update(build_id=build_id, app_version=app_version,
                    renderer=renderer, validation='not_yet_verified')
    app = output / f'今天不上班-{app_version}.app'
    mac = app / 'Contents/MacOS'
    resources = app / 'Contents/Resources'
    mac.mkdir(parents=True)
    resources.mkdir(parents=True)
    log = output / 'export.log'
    with log.open('w') as stream:
        subprocess.run([str(engine), '--headless', '--path', str(ROOT), '--export-pack', 'macOS',
                        str(resources / 'game.pck')], stdout=stream, stderr=subprocess.STDOUT, check=True)
    if re.search(r'SCRIPT ERROR|ERROR:', log.read_text()):
        raise RuntimeError(f'Export logged errors: {log}')
    subprocess.run([str(engine), '--headless', '--path', str(ROOT), '--script',
                    'tools/runtime_licenses.gd'], check=True)
    if source_identity()['source_sha256'] != identity['source_sha256']:
        raise RuntimeError('Runtime source changed during packaging; incomplete output retained for diagnosis')
    shutil.copy2(engine, mac / 'Godot')
    shutil.copy2(ROOT / 'build/GODOT-LICENSES.txt', resources / 'GODOT-LICENSES.txt')
    for name in ('CREDITS.txt', 'MAKEHUMAN-CC0.txt'):
        shutil.copy2(ROOT / 'assets' / name, resources / name)
    shutil.copy2(ROOT / 'assets/polyhaven/provenance.json', resources / 'ASSET-SOURCES.json')
    shutil.copy2(ROOT / 'assets/company_materials/provenance.json', resources / 'COMPANY-MATERIALS.json')
    shutil.copy2(ROOT / 'assets/city_nature/provenance.json', resources / 'NATURE-SOURCES.json')
    shutil.copy2(ROOT / 'assets/city_architecture/provenance.json', resources / 'ARCHITECTURE-SOURCES.json')
    shutil.copy2(ROOT / 'assets/city_street/provenance.json', resources / 'STREET-SOURCES.json')
    shutil.copy2(ROOT / 'assets/audio/city/provenance.json', resources / 'AUDIO-SOURCES.json')
    shutil.copy2(ROOT / 'assets/animations/provenance.json', resources / 'ANIMATION-SOURCES.json')
    shutil.copy2(ROOT / 'assets/characters/cast/provenance.json', resources / 'CAST-SOURCES.json')
    shutil.copy2(ROOT / 'production/characters/cc0-2026-09-29/provenance.json', resources / 'CAST-ORIGINALS.json')
    for person in ('protagonist', 'lin_lan', 'a_cheng'):
        shutil.copy2(ROOT / f'assets/animations/cast/{person}-provenance.json',
                     resources / f'CAST-MOTION-{person}.json')
    identity['pck_sha256'] = sha256(resources / 'game.pck')
    identity['engine_source_sha256'] = sha256(engine)
    data = json.dumps(identity, ensure_ascii=False, indent=2) + '\n'
    (resources / 'build-manifest.json').write_text(data)
    (output / 'build-manifest.json').write_text(data)
    launcher = mac / 'TodayOff'
    launcher.write_text('''#!/bin/sh
APP_CONTENTS="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$APP_CONTENTS/Resources"
exec "$APP_CONTENTS/MacOS/Godot" --main-pack "$APP_CONTENTS/Resources/game.pck" "$@"
''')
    launcher.chmod(0o755)
    with (app / 'Contents/Info.plist').open('wb') as stream:
        plistlib.dump({'CFBundleName': '今天不上班', 'CFBundleDisplayName': '今天不上班',
                      'CFBundleIdentifier': 'com.todayoff.mvp.v050', 'CFBundleVersion': app_version,
                      'CFBundleShortVersionString': app_version, 'CFBundleExecutable': 'TodayOff',
                      'CFBundlePackageType': 'APPL', 'NSHighResolutionCapable': True,
                      'LSMinimumSystemVersion': '12.0'}, stream)
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    archive = output / f'今天不上班-macOS-{app_version}.zip'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(archive)], check=True)
    (output / 'artifact-sha256.json').write_text(json.dumps(
        {'build_id': build_id, 'zip': archive.name, 'sha256': sha256(archive),
         'packaged_runtime_sha256': sha256(mac / 'Godot')}, indent=2) + '\n')
    print(f'BUILD_OUTPUT={output}')
    print('Build created; gameplay and visual acceptance remain separate.')


if __name__ == '__main__':
    build()
