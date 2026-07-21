# mube

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（tscircuit / TS）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に HTTP ポート 80 で WebUI と JSON API を配信し、サーボがサムターンを回して施錠/解錠する。
ブラウザで `http://<pico-ip>/` を開くと施錠/解錠ボタンと現在状態が表示される。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。

| サブシステム | ディレクトリ | 役割 |
| --- | --- | --- |
| 筐体 | `scad/` | ドアに貼るベースプレートと、ボルトオンのサーボ台座、電子部品トレイ、サムターン受け |
| 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 |
| ファーム | `crates/` | WiFi / HTTP / サーボ制御（firmware）＋ ハード非依存ロジック（mube-core） |
| WebUI | `crates/webui/` | yew SPA（trunk でビルド）。firmware に埋め込まれ HTTP で配信される |
| ビューア | `viewer/` | STL をブラウザで確認（cloudflared quick tunnel で共有可） |

ロジック部（コマンド解釈、状態機械、角度変換）はハード非依存で、実機なしに host テストできる。
回路はブレッドボード実機で、サーボと LED とスイッチを全部載せた同時動作まで検証済み。

## 開発環境

必要なツール:

- cargo（rustup なら rust-toolchain.toml が自動導入）
- bun
- openscad
- cloudflared

無ければ nix develop が使える。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `bun scad/clash.ts` |
| scad ツールの単体テスト | `bun test scad/` |
| 回路 ERC（導通・ショート） | `cd circuit && bun install --frozen-lockfile && bun test` |
| WebUI ビルド（yew→dist）| `cd crates/webui && trunk build --release` |
| ファームビルド（thumbv6m、先に WebUI をビルドすること） | `cargo build` |
| ロジックの host テスト（実機不要） | `cargo host-test` |
| 3D ビューアを公開 | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `bun circuit/breadboard-serve.ts` |

## ファームウェア

セットアップから書き込み、キャリブレーション、HTTP WebUI / API の詳細は [docs/firmware.md](docs/firmware.md) を参照。
日常の遠隔操作は `bun lockctl.ts lock|unlock|toggle|status`（ポート既定 80、`TARGET_IP` / `PORT` 環境変数で設定）。
ブラウザから操作する場合は `http://<pico-ip>/` を開く。
