#!/usr/bin/env bash
# Build all printable parts to build/. Re-execs inside the Nix dev shell if needed.
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")" && pwd)" -c "$0" "$@"
fi
cd "$(dirname "$0")"
mkdir -p build
for p in body lid socket tray asm_body asm_lid asm_socket asm_tray; do
  echo "== building $p =="
  log="$(openscad -D "part=\"$p\"" -o "build/$p.stl" scad/smartlock.scad 2>&1)"
  status=$?
  echo "$log"
  if [ "$status" -ne 0 ] || echo "$log" | grep -Eiq '^WARNING:|^ERROR:'; then
    echo "FAIL: $p"; exit 1
  fi
done
echo "== generating netlist (from-to / bom) =="
uv run --script circuit/netlist.py || { echo "FAIL: netlist"; exit 1; }
echo "All parts + netlist built to build/"
