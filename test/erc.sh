#!/usr/bin/env bash
# 回路の導通・ショート ERC を bun test で回す。bun が無ければ Nix dev シェルへ再突入。
set -uo pipefail
if ! command -v bun >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
cd "$(dirname "$0")/../circuit"
bun install --frozen-lockfile
bun test
