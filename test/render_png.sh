#!/usr/bin/env bash
# Render an OpenSCAD file to PNG using Mesa software rendering (no GPU/X required).
# Re-execs inside the Nix dev shell if openscad is not already on PATH.
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi

scad="${1:?usage: render_png.sh <scad> [out] [extra openscad flags...]}"
out="${2:-build/$(basename "${scad%.scad}").png}"
shift 2 2>/dev/null || shift 1
mkdir -p "$(dirname "$out")"

log="$(openscad -o "$out" \
  --backend Manifold \
  --render \
  --viewall --autocenter \
  --imgsize 2400,1800 \
  "$@" \
  "$scad" 2>&1)"
status=$?
echo "$log"
if [ "$status" -ne 0 ]; then echo "FAIL: openscad exit $status"; exit 1; fi
echo "OK: $out"
