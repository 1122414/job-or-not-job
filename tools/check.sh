#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p logs
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --path . --editor --import --quit --log-file "$PWD/logs/import.log"
if rg -n 'SCRIPT ERROR|ERROR:' logs/import.log; then exit 1; fi
"$GODOT_BIN" --headless --path . --quit-after 120 --log-file "$PWD/logs/smoke.log"
if rg -n 'SCRIPT ERROR|ERROR:' logs/smoke.log; then exit 1; fi
for test in tests/*_test.gd; do
  "$GODOT_BIN" --headless --path . --script "$test" --log-file "$PWD/logs/$(basename "$test").log"
  if rg -n 'SCRIPT ERROR|ERROR:' "logs/$(basename "$test").log"; then exit 1; fi
done
