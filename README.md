# smtlk — スマートロック

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（tscircuit / TS）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に TCP ポート 6000 でコマンドを受け、サーボがサムターンを回して施錠/解錠する。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。

| サブシステム | ディレクトリ | 役割 |
| --- | --- | --- |
| 筐体 | `scad/` | ドアに貼るベースプレートと、ボルトオンのサーボ台座、電子部品トレイ、サムターン受け |
| 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 |
| ファーム | `crates/` | WiFi / TCP / サーボ制御（firmware）＋ ハード非依存ロジック（smtlk-core） |
| ビューア | `viewer/` | STL をブラウザで確認（cloudflared quick tunnel で共有可） |

ロジック部（コマンド解釈、状態機械、serve ループ、角度変換）はハード非依存で、実機なしに host テストできる。
回路はブレッドボード実機で、サーボと LED とスイッチを全部載せた同時動作まで検証済み。

## 開発環境

必要なツール:

- `cargo`（rustup）
- `bun`
- `openscad`
- `cloudflared`

無ければ `nix develop` が使える。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `bun scad/clash.ts` |
| scad ツールの単体テスト | `bun test scad/` |
| 回路 ERC（導通・ショート） | `cd circuit && bun install --frozen-lockfile && bun test` |
| ファームビルド（thumbv6m） | `cargo build` |
| ロジックの host テスト（実機不要） | `cargo host-test` |
| 3D ビューアを公開 | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `bun circuit/breadboard-serve.ts` |

## 配線と GPIO

配線の唯一の正は `circuit/index.tsx`（tscircuit）。
GPIO 割り当てはファームと一致:
サーボ PWM GP15 / サーボ電源ゲート GP14 / LED 赤 GP16・黄緑 GP18（コモンカソード）/ タクトスイッチ GP17（内部プルアップ）。

## ファームウェア

セットアップから書き込み、キャリブレーション、TCP プロトコルまでの詳細は [docs/firmware.md](docs/firmware.md) を参照。
日常の遠隔操作は `./lockctl.sh lock|unlock|toggle|status`。
