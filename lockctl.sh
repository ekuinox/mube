#!/usr/bin/env bash
# スマートロックの施錠/解錠を TCP で切り替えるクライアント。
#   赤 = 施錠 (LOCKED) / 緑 = 解錠 (UNLOCKED)
#
# 接続先 IP は環境変数 TARGET_IP（.envrc.local で定義 → direnv がロード）。
# ポートは firmware の LOCK_PORT=6000 固定（LOCK_PORT env で上書き可）。
# 依存なし（bash の /dev/tcp だけ。nc 不要）。
#
# 使い方:
#   ./lockctl.sh            # 現在と逆に切り替え（トグル）
#   ./lockctl.sh toggle     # 同上
#   ./lockctl.sh lock       # 施錠（赤）
#   ./lockctl.sh unlock     # 解錠（緑）
#   ./lockctl.sh status     # 現在状態を問い合わせ（駆動しない）
set -euo pipefail

HOST="${TARGET_IP:?TARGET_IP が未設定。.envrc.local を定義して 'direnv allow' したか確認してね}"
PORT="${LOCK_PORT:-6000}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"  # 接続の最大待ち秒（IP 間違い/電源オフ時のハング防止）

# fd 3（接続済みソケット）へ 1 コマンド送り、1 行返す。末尾 CR は除去。
send() {
  printf '%s\n' "$1" >&3
  local reply
  if ! IFS= read -r -t 5 reply <&3; then
    echo "error: ${HOST}:${PORT} から応答なし（5秒タイムアウト）" >&2
    return 1
  fi
  printf '%s' "${reply%$'\r'}"
}

open_conn() {
  # ファームは同時1接続しか捌けず、接続を閉じた直後の再接続を RST で蹴る。
  # 以前は timeout で到達性プリフライトを張っていたが、その「開いて即閉じ」の
  # 直後に本接続すると 2 回目が Connection refused になっていた。接続は 1 回だけにする。
  # （connect ハング対策: 同一 LAN の誤 IP は ARP 失敗で即エラー。全体を timeout で
  #   くるみたい場合は呼び出し側で `timeout $CONNECT_TIMEOUT ./lockctl.sh ...` を使う）
  exec 3<>"/dev/tcp/${HOST}/${PORT}" 2>/dev/null || {
    echo "error: ${HOST}:${PORT} に接続できない。IP・電源・WiFi 接続を確認してね" >&2
    exit 1
  }
}
close_conn() { exec 3<&- 3>&- 2>/dev/null || true; }

cmd="${1:-toggle}"

open_conn
case "$cmd" in
  lock)   result="$(send LOCK)" ;;
  unlock) result="$(send UNLOCK)" ;;
  status) result="$(send STATUS)" ;;
  toggle)
    cur="$(send STATUS)"
    case "$cur" in
      LOCKED)   result="$(send UNLOCK)" ;;   # 赤→緑
      UNLOCKED) result="$(send LOCK)" ;;      # 緑→赤
      *) echo "error: STATUS の応答が想定外: '${cur}'" >&2; close_conn; exit 1 ;;
    esac
    ;;
  -h|--help|help)
    close_conn
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *) echo "usage: $0 [toggle|lock|unlock|status]" >&2; close_conn; exit 2 ;;
esac
close_conn

# 応答を人間向けに。
case "$result" in
  LOCKED)   echo "施錠 (LOCKED) / 赤" ;;
  UNLOCKED) echo "解錠 (UNLOCKED) / 緑" ;;
  ERR)      echo "error: ロックが ERR を返した（不正コマンド）" >&2; exit 1 ;;
  *)        echo "応答: '${result}'" >&2; exit 1 ;;
esac
