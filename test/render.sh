#!/usr/bin/env bash
# Render one OpenSCAD file to STL. Fail on non-zero exit or any WARNING/ERROR.
# Re-execs inside the Nix dev shell if openscad is not already on PATH.
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
scad="${1:?usage: render.sh <scad> [out]}"
out="${2:-/tmp/$(basename "${scad%.scad}").stl}"
mkdir -p "$(dirname "$out")"
log="$(openscad -o "$out" "$scad" 2>&1)"
status=$?
echo "$log"
if [ "$status" -ne 0 ]; then echo "FAIL: openscad exit $status"; exit 1; fi
if echo "$log" | grep -Eiq 'WARNING|ERROR'; then echo "FAIL: warnings/errors present"; exit 1; fi
echo "OK: $out"
