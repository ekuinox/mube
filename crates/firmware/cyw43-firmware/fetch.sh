#!/usr/bin/env bash
# CYW43439 ファームウェアブロブ（firmware / NVRAM / CLM）を一撃で取得する。
#
# Infineon のライセンス物で .gitignore 済み。crate と同じ rev（cyw43-v0.7.0 タグ）から
# 取ってバージョンを揃える。詳細は同ディレクトリの README.md を参照。
#
# 使い方: どこから実行しても、このスクリプトの隣（cyw43-firmware/）に置く。
#   ./crates/firmware/cyw43-firmware/fetch.sh
set -euo pipefail

# スクリプト自身のあるディレクトリを保存先にする（cwd に依存しない）。
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TAG="cyw43-v0.7.0"
BASE="https://raw.githubusercontent.com/embassy-rs/embassy/${TAG}/cyw43-firmware"

# ファイル名 と 最低バイト数（HTML エラーページや空ファイルを弾く sanity check）。
FILES=(
  "43439A0.bin:100000"       # WiFi ファームウェア（実測 ~225KB）
  "43439A0_clm.bin:500"      # 国別 CLM（実測 984 bytes）
  "nvram_rp2040.bin:100"     # 基板 NVRAM（実測 ~0.6KB）
)

# ダウンローダを選ぶ（curl 優先、無ければ wget）。
if command -v curl >/dev/null 2>&1; then
  dl() { curl -fL --retry 3 --retry-delay 2 -o "$1" "$2"; }
elif command -v wget >/dev/null 2>&1; then
  dl() { wget -q -O "$1" "$2"; }
else
  echo "error: curl も wget も見つからない。どちらかを入れてね。" >&2
  exit 1
fi

echo "CYW43 ブロブを取得: tag=${TAG}"
echo "  保存先: ${DIR}"

for entry in "${FILES[@]}"; do
  name="${entry%%:*}"
  min="${entry##*:}"
  url="${BASE}/${name}"
  out="${DIR}/${name}"

  echo "  - ${name} ..."
  tmp="${out}.tmp"
  dl "$tmp" "$url"

  # サイズ検証（GNU/BSD stat 両対応）。
  size="$(stat -c%s "$tmp" 2>/dev/null || stat -f%z "$tmp")"
  if [ "$size" -lt "$min" ]; then
    rm -f "$tmp"
    echo "    error: ${name} が小さすぎる (${size} < ${min} bytes)。URL/タグを確認して。" >&2
    exit 1
  fi

  mv -f "$tmp" "$out"
  echo "    ok (${size} bytes)"
done

echo "完了。3ファイルとも ${DIR} に配置したよ。"
