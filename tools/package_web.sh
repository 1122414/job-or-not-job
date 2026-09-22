#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p build/web logs
touch build/.gdignore
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html --log-file "$PWD/logs/export-web.log"
if rg -n 'SCRIPT ERROR|ERROR:' logs/export-web.log; then exit 1; fi
"$GODOT_BIN" --headless --path . --script tools/runtime_licenses.gd
cp build/GODOT-LICENSES.txt assets/CREDITS.txt assets/MAKEHUMAN-CC0.txt build/web/
cp assets/fonts/OFL.txt build/web/NOTO-OFL.txt
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path('build/web')
with ZipFile('build/今天不上班-web.zip', 'w', ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        if path.is_file() and path.suffix != '.import':
            archive.write(path, path.relative_to(root))
print('网页包：build/今天不上班-web.zip')
print('本地试玩：python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web')
PY
