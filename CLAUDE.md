# CLAUDE.md

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。筐体(OpenSCAD) + 回路(tscircuit / TS) + Pico W ファーム(Rust/Embassy) の monorepo。
詳細・背景は README.md に集約。ここは概要と Claude がハマりやすい所だけ。

## リポジトリ地図

- `scad/` — 筐体（OpenSCAD）
- `circuit/` — 回路（tscircuit / TS: 導通・ショート ERC。bun 管理）
- `viewer/` — STL ブラウザビューア（Three.js + cloudflared quick tunnel。bun）
- `crates/firmware/` — Pico W ファーム（Embassy/CYW43/PWM 接合部、thumbv6m-none-eabi）
- `crates/smtlk-core/` — ハード非依存ロジック（LockState/コマンド解釈/serve ループ/サーボ角度。host テスト可）
- `scad/build/`, `circuit/build/` — 派生物（STL/SVG 出力。非コミット）
- `docs/` — 設計ドキュメント

## コマンドの打ち方（落とし穴）

正式なコマンドは下表の素の形（Nix はツールを揃える手段のひとつで、プロジェクトの前提ではない）。
ただし**この開発機の非対話シェルには `openscad` / `cargo` / `bun` / `cloudflared` が PATH に無い**ので、
Claude が実行するときは各コマンドに `nix develop -c` を前置する（例: `nix develop -c bun scad/build.ts`。
`.sh` の自動再突入は廃止済み）。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `bun scad/clash.ts` |
| scad ツールの単体テスト | `bun test scad/` |
| 回路 ERC（導通・ショート） | `cd circuit && bun install --frozen-lockfile && bun test` |
| ファームビルド（既定ターゲット thumbv6m） | `cargo build --locked` |
| ロジックの host テスト（実機不要） | `cargo host-test` |
| 3D ビューア公開 | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `bun circuit/breadboard-serve.ts` |

## 触る時の注意（規約・地雷）

- Rust コードを変更したらコミット前に host テスト（`cargo host-test`）を通すこと。テストが落ちたまま完了扱いにしない。
- `scad/build/` / `circuit/build/` と `*.stl` は派生物。コミットしない（.gitignore 済み）。
- 秘密扱い・未コミット: WiFi 認証（ビルド時環境変数 `WIFI_SSID` / `WIFI_PASSWORD`。`crates/firmware/src/config.rs` が `option_env!` で埋め込む）と CYW43 ブロブ（`crates/firmware/cyw43-firmware/*.bin`、ライセンス物）。実値を会話やコミットに載せない。
- サーボ実機合わせはキャリブ定数だけを安全側から調整する。角度→パルス変換（`SERVO_MIN_US` / `SERVO_MAX_US` / `LOCK_DEG` / `UNLOCK_DEG`）は `crates/smtlk-core/src/servo_math.rs`、整定待ち `SETTLE_MS` は `crates/firmware/src/servo.rs`。
- 採寸・ドア固定の未確定値は params/socket/mount_plate に隔離（README「未確定」参照）。
- Cargo.lock はコミット済み。再現は `--locked` で。

## 詳細

コマンド表は README.md、ファームのセットアップから書き込み、TCP プロトコル（LOCK/UNLOCK/STATUS）までは docs/firmware.md、採寸は docs/measurements-checklist.md を参照。
