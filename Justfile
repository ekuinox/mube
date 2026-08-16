# 既定: レシピ一覧を表示
default:
    @just --list

# 筐体を STL に一括ビルド → enclosure/build/
enclosure:
    bun enclosure/scripts/build.ts

# 単発レンダリング（例: just render enclosure/models/tray.scad /tmp/tray.png）
render scad *rest:
    bun enclosure/scripts/render.ts {{scad}} {{rest}}

# 部品間の体積干渉チェック
clash:
    bun enclosure/scripts/clash.ts

# カバー STL が単一の連結ソリッドであることの回帰チェック
cover-components:
    bun enclosure/scripts/components.ts

# enclosure スクリプトの単体テスト（openscad 不要）
test-enclosure:
    bun test enclosure/scripts/

# 回路 ERC（導通・ショート）
erc:
    cd circuit && bun install --frozen-lockfile && bun test

# WebUI ビルド（yew → crates/mube-webui/dist）
webui:
    cd crates/mube-webui && trunk build --release

# CYW43 ブロブを取得（3 ファイル揃っていなければ取得）
blobs:
    bun scripts/fetch-cyw43.ts

# ファームビルド一発（blob 取得 → WebUI → cargo build）。clone 後これだけでOK
firmware: blobs webui
    cargo build

# OTA でファーム更新（ビルド → raw バイナリ化 → TCP 4242 送信。要 TARGET_IP と書き込み済みブートローダー）
ota: blobs webui
    cargo build --release
    rust-objcopy -O binary --remove-section .boot2 target/thumbv6m-none-eabi/release/mube-firmware target/mube-firmware-ota.bin
    bun scripts/lockctl.ts ota target/mube-firmware-ota.bin

# ロジックの host テスト（実機不要）
host-test:
    cargo host-test

# 3D ビューアを公開（cloudflared quick tunnel）
viewer:
    bun viewer/serve.ts

# ブレッドボード配線図ビューア
breadboard:
    bun circuit/breadboard-serve.ts

# 施錠/解錠クライアント（例: just lockctl status）
lockctl *args:
    bun scripts/lockctl.ts {{args}}
