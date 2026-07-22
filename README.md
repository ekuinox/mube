# mube

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（tscircuit / TS）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に HTTP ポート 80 で WebUI と JSON API を配信し、サーボがサムターンを回して施錠/解錠する。
ブラウザで `http://<pico-ip>/` を開くと施錠/解錠ボタンと現在状態が表示される。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。

| サブシステム | ディレクトリ | 役割 |
| --- | --- | --- |
| 筐体 | `enclosure/` | ドアに貼るベースプレートと、ボルトオンのサーボ台座、電子部品トレイ、サムターン受け |
| 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 |
| ファーム | `crates/` | WiFi / HTTP / サーボ制御（mube-firmware）＋ ハード非依存ロジック（mube-core） |
| WebUI | `crates/mube-webui/` | yew SPA（trunk でビルド）。firmware に埋め込まれ HTTP で配信される |
| ビューア | `viewer/` | STL をブラウザで確認（cloudflared quick tunnel で共有可） |

ロジック部（コマンド解釈、状態機械、角度変換）はハード非依存で、実機なしに host テストできる。
回路はブレッドボード実機で、サーボと LED とスイッチを全部載せた同時動作まで検証済み。

## 開発環境

必要なツール:

- cargo（rustup なら rust-toolchain.toml が自動導入）
- bun
- openscad
- cloudflared
- just

無ければ nix develop が使える。clone 後は `nix develop -c just firmware` の一発でファームまでビルドできる。

| やりたいこと | コマンド（just） | 素のコマンド |
| --- | --- | --- |
| 筐体ビルド（STL を enclosure/build/ へ） | `just enclosure` | `bun enclosure/scripts/build.ts` |
| SCAD 単発レンダリング | `just render <scad> [out]` | `bun enclosure/scripts/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `just clash` | `bun enclosure/scripts/clash.ts` |
| enclosure ツールの単体テスト | `just test-enclosure` | `bun test enclosure/scripts/` |
| 回路 ERC（導通・ショート） | `just erc` | `cd circuit && bun install --frozen-lockfile && bun test` |
| WebUI ビルド（yew→dist） | `just webui` | `cd crates/mube-webui && trunk build --release` |
| ファームビルド一発（blob→webui→cargo build） | `just firmware` | — |
| ロジックの host テスト（実機不要） | `just host-test` | `cargo host-test` |
| 3D ビューアを公開 | `just viewer` | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `just breadboard` | `bun circuit/breadboard-serve.ts` |
| 施錠/解錠クライアント | `just lockctl <sub>` | `bun scripts/lockctl.ts <sub>` |

## ファームウェア

セットアップから書き込み、キャリブレーション、HTTP WebUI / API の詳細は [docs/firmware.md](docs/firmware.md) を参照。
日常の遠隔操作は `bun scripts/lockctl.ts lock|unlock|toggle|status`（ポート既定 80、`TARGET_IP` / `PORT` 環境変数で設定）。
ブラウザから操作する場合は `http://<pico-ip>/` を開く。
インターネット越しの遠隔操作（Caddy + cloudflared 中継の home-manager モジュール）は [docs/remote-relay.md](docs/remote-relay.md) を参照。
