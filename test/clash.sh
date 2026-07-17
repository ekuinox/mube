#!/usr/bin/env bash
# 部品間の体積干渉を静的検出する。clash_check.scad は干渉体積だけを出力するモデルなので、
# レンダリング結果が空（"top level object is empty"）なら干渉なし=PASS、形状が出たら FAIL。
# openscad が無ければ nix dev シェルに再突入する（render.sh と同じ流儀）。
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
scad="$(cd "$(dirname "$0")" && pwd)/clash_check.scad"
out="/tmp/clash_check.stl"
log="$(openscad -o "$out" "$scad" 2>&1)"
status=$?
echo "$log"
# 空出力＝干渉なし。openscad は空エクスポートで警告と非ゼロ終了することがあるので先に判定する
if echo "$log" | grep -q "top level object is empty"; then
  echo "OK: no interference (empty intersection)"
  exit 0
fi
if [ "$status" -ne 0 ]; then echo "FAIL: openscad exit $status"; exit 1; fi
if echo "$log" | grep -Eq 'WARNING:|ERROR:'; then echo "FAIL: warnings/errors present"; exit 1; fi
facets="$(echo "$log" | grep -oE 'Facets: +[0-9]+' | grep -oE '[0-9]+' | tail -1)"
echo "FAIL: interference detected (facets=${facets:-unknown})"
exit 1
