# smtlk — スマートロック

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（tscircuit / TS）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に TCP ポート 6000 でコマンドを受け、サーボがサムターンを回して施錠/解錠する。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。

| サブシステム | ディレクトリ | 役割 |
| --- | --- | --- |
| 筐体 | `scad/` | ドアに貼るベースプレート＋ボルトオンのサーボ台座・電子部品トレイ・サムターン受け |
| 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 |
| ファーム | `crates/` | WiFi / TCP / サーボ制御（firmware）＋ ハード非依存ロジック（smtlk-core） |
| ビューア | `viewer/` | STL をブラウザで確認（cloudflared quick tunnel で共有可） |

ロジック部（コマンド解釈・状態機械・serve ループ・角度変換）はハード非依存で、実機なしに host テストできる。
回路はブレッドボード実機でサーボ・LED・スイッチ全部載せの同時動作を検証済み。

## 開発環境

使うツールは `openscad` / `bun` / `cargo`（rustup）/ `cloudflared`。手元に揃っていればそのまま使える。
揃っていない場合は Nix がオプションとしてあり、`nix develop` で全部入りの devShell に入れる（CI もこれを使う）。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `bun scad/clash.ts` |
| scad ツールの単体テスト | `bun test scad/` |
| 回路 ERC（導通・ショート） | `cd circuit && bun install --frozen-lockfile && bun test` |
| ファームビルド（thumbv6m） | `cargo build --locked` |
| ロジックの host テスト（実機不要） | `cargo host-test` |
| 3D ビューアを公開 | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `bun circuit/breadboard-serve.ts` |

`cargo host-test` は devShell が提供する別名で、実体は `cargo test -p smtlk-core --target <ホストトリプル>`
（devShell 外ではこちらを直接叩く）。ビューア 2 種は `NO_TUNNEL=1` を付けるとトンネル無しの
ローカル配信になる。`scad/build/`・`circuit/build/`・`*.stl` は派生物なのでコミットしない（.gitignore 済み）。

## 配線と GPIO

配線の唯一の正は `circuit/index.tsx`（tscircuit）。GPIO 割り当てはファームと一致:
サーボ PWM GP15 / サーボ電源ゲート GP14 / LED 赤 GP16・黄緑 GP18（コモンカソード）/
タクトスイッチ GP17（内部プルアップ）。

## ファームウェア

セットアップ（WiFi 認証・CYW43 ブロブ）・書き込み・サーボキャリブ・TCP プロトコルの詳細は
[docs/firmware.md](docs/firmware.md) を参照。日常の遠隔操作は `./lockctl.sh lock|unlock|toggle|status`。

## 未確定（積み残し）

- 筐体: ドア固定の突っ張り先（mount_plate で隔離）。サムターン実寸の最終合わせ（socket パラメータで隔離）。
- ファーム: 省電力運用 / 手回し後の状態再同期。
