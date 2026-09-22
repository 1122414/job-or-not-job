#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p build logs
"$GODOT_BIN" --headless --path . --export-pack macOS build/game.pck --log-file "$PWD/logs/export-pack.log"
"$GODOT_BIN" --headless --path . --script tools/runtime_licenses.gd
python3 - "$GODOT_BIN" <<'PY'
from pathlib import Path
import plistlib, shutil, sys
app = Path('build/今天不上班-0.3.0.app')
mac = app / 'Contents/MacOS'
res = app / 'Contents/Resources'
mac.mkdir(parents=True, exist_ok=True)
res.mkdir(parents=True, exist_ok=True)
shutil.copy2(sys.argv[1], mac / 'Godot')
shutil.copy2('build/game.pck', res / 'game.pck')
shutil.copy2('build/GODOT-LICENSES.txt', res / 'GODOT-LICENSES.txt')
for name in ['CREDITS.txt', 'MAKEHUMAN-CC0.txt']:
    shutil.copy2(Path('assets') / name, res / name)
launcher = mac / 'TodayOff'
launcher.write_text('''#!/bin/sh
APP_CONTENTS="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$APP_CONTENTS/MacOS/Godot" --main-pack "$APP_CONTENTS/Resources/game.pck" "$@"
''')
launcher.chmod(0o755)
with (app / 'Contents/Info.plist').open('wb') as f:
    plistlib.dump({'CFBundleName':'今天不上班','CFBundleDisplayName':'今天不上班','CFBundleIdentifier':'com.todayoff.mvp','CFBundleVersion':'0.3.0','CFBundleShortVersionString':'0.3.0','CFBundleExecutable':'TodayOff','CFBundlePackageType':'APPL','NSHighResolutionCapable':True,'LSMinimumSystemVersion':'12.0'},f)
PY
# Local development build, using the exact installed 4.7.1 runtime, not a mismatched template.
codesign --force --deep --sign - 'build/今天不上班-0.3.0.app'
ditto -c -k --sequesterRsrc --keepParent 'build/今天不上班-0.3.0.app' 'build/今天不上班-macOS-0.3.0.zip'
