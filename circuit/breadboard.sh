#!/usr/bin/env bash
# ブレッドボード配線図を全プリセット生成し、ブラウザビューアを serve + cloudflared で公開する。
# bun が無ければ Nix dev シェルへ再突入。ローカルのみで見たいときは NO_TUNNEL=1 を付ける。
#
# 使い方:
#   ./circuit/breadboard.sh            # 全プリセット生成 → 公開URLをブラウザで開く
#   NO_TUNNEL=1 ./circuit/breadboard.sh # トンネルを張らず http://127.0.0.1:8766 で見る
#   PORT=9000 ./circuit/breadboard.sh   # ポート変更
#   Ctrl-C で停止
set -uo pipefail
if ! command -v bun >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
cd "$(dirname "$0")"
bun install --frozen-lockfile
exec uv run --script breadboard-serve.py "$@"
