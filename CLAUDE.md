# CLAUDE.md

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。筐体(OpenSCAD) + 回路(tscircuit / TS) + Pico W ファーム(Rust/Embassy) の monorepo。
詳細・背景は README.md に集約。ここは概要と Claude がハマりやすい所だけ。

## リポジトリ地図

- `enclosure/` — 筐体（OpenSCAD）。`models/` に *.scad、`scripts/` に build/render/clash/openscad ヘルパ
- `scripts/` — トップレベルの運用スクリプト（lockctl）
- `circuit/` — 回路（tscircuit / TS: 導通・ショート ERC。bun 管理）
- `viewer/` — STL ブラウザビューア（Three.js + cloudflared quick tunnel。bun）
- `crates/mube-firmware/` — Pico W ファーム（Embassy/CYW43/PWM 接合部、thumbv6m-none-eabi）
- `crates/mube-core/` — ハード非依存ロジック（LockState/コマンド解釈/serve ループ/サーボ角度。host テスト可）
- `enclosure/build/`, `circuit/build/` — 派生物（STL/SVG 出力。非コミット）
- `backlog/` — 残タスク（Backlog.md 管理。タスク = markdown ファイル）
- `docs/` — 設計ドキュメント

## コマンドの打ち方（落とし穴）

正式なコマンドは下表の素の形（Nix はツールを揃える手段のひとつで、プロジェクトの前提ではない）。
ただし**この開発機の非対話シェルには `openscad` / `cargo` / `bun` / `cloudflared` / `just` が PATH に無い**ので、
Claude が実行するときは各コマンドに `nix develop -c` を前置する（例: `nix develop -c just enclosure` や `nix develop -c bun enclosure/scripts/build.ts`。
`.sh` の自動再突入は廃止済み）。

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
| 3D ビューア公開 | `just viewer` | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `just breadboard` | `bun circuit/breadboard-serve.ts` |
| 施錠/解錠クライアント | `just lockctl <sub>` | `bun scripts/lockctl.ts <sub>` |

## 触る時の注意（規約・地雷）

- Rust コードを変更したらコミット前に host テスト（`cargo host-test`）を通すこと。テストが落ちたまま完了扱いにしない。
- `enclosure/build/` / `circuit/build/` と `*.stl` は派生物。コミットしない（.gitignore 済み）。
- 秘密扱い・未コミット: WiFi 認証（ビルド時環境変数 `WIFI_SSID` / `WIFI_PASSWORD`。`crates/mube-firmware/src/config.rs` が `option_env!` で埋め込む）と CYW43 ブロブ（`crates/mube-firmware/cyw43-firmware/*.bin`、ライセンス物）。実値を会話やコミットに載せない。
- サーボ実機合わせはキャリブ定数だけを安全側から調整する。角度→パルス変換（`SERVO_MIN_US` / `SERVO_MAX_US` / `LOCK_DEG` / `UNLOCK_DEG`）は `crates/mube-core/src/servo_math.rs`、整定待ち `SETTLE_MS` は `crates/mube-firmware/src/servo.rs`。
- 採寸は実測済みで確定（記録は docs/measurements-checklist.md）。残タスクは Backlog.md（`backlog/tasks/` の markdown）で管理する。CLI は devShell の `backlog`（`backlog task list --plain` など）。タスクのタイトル・本文は日本語。作成直後にファイル名だけ `task-N - <英語のkebab-case>.md`（`task-N - ` 接頭辞は保持、後半は小文字ハイフン区切り）へリネームする（view/edit は frontmatter の id で解決するが、`task complete` は `task-N - *.md` のファイル名パターンで探すため、接頭辞を崩すと失敗する。詳細は creating-backlog-tasks スキル参照）。Done タスクの completed/ への片付けは `backlog task complete <id>`。
- Cargo.lock はコミット済み。ビルドの厳密な再現が要る場面（CI・リリース）だけ `--locked` を付ける。

## 詳細

コマンド表は README.md、ファームのセットアップから書き込み、TCP プロトコル（LOCK/UNLOCK/STATUS）までは docs/firmware.md、採寸は docs/measurements-checklist.md を参照。
