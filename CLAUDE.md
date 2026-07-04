# CLAUDE.md

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。筐体(OpenSCAD) + 回路(Python netlist) + Pico W ファーム(Rust/Embassy) の monorepo。
詳細・背景は README.md に集約。ここは概要と Claude がハマりやすい所だけ。

## リポジトリ地図

- `scad/` — 筐体（OpenSCAD）
- `circuit/` — 回路ネットリスト（Python: ERC ライト + from-to/bom 生成）
- `viewer/` — STL ブラウザビューア（Three.js + cloudflared quick tunnel）
- `crates/firmware/` — Pico W ファーム（Embassy/CYW43/PWM 接合部、thumbv6m-none-eabi）
- `crates/smtlk-core/` — ハード非依存ロジック（LockState/コマンド解釈/serve ループ/サーボ角度。host テスト可）
- `build/` — 派生物（STL/netlist 出力。非コミット）
- `test/`, `docs/` — テスト / 設計ドキュメント

## コマンドの打ち方（落とし穴）

`openscad` / `cargo` / `uv` は nix dev シェルの中にしか無い。

- `.sh` 系（`./build.sh`, `./test/render.sh`）は自分で nix dev シェルに再突入するのでそのまま実行可。
- 素の `cargo` / `uv` / `openscad` / `./test/netlist_test.py` は **`nix develop -c <cmd>`** 経由で実行する。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL + netlist を build/ へ） | `./build.sh` |
| ファームビルド（既定ターゲット thumbv6m） | `nix develop -c cargo build --locked` |
| ロジックの host テスト（実機不要） | `nix develop -c cargo host-test` |
| SCAD レンダリングテスト | `./test/render.sh <scad>` |
| 回路ネットリストテスト | `nix develop -c ./test/netlist_test.py` |

## 触る時の注意（規約・地雷）

- Rust コードを変更したらコミット前に `nix develop -c cargo host-test` を通すこと。テストが落ちたまま完了扱いにしない。
- `build/` と `*.stl` は派生物。コミットしない（.gitignore 済み）。
- 秘密扱い・未コミット: WiFi 認証（ビルド時環境変数 `WIFI_SSID` / `WIFI_PASSWORD`。`crates/firmware/src/config.rs` が `option_env!` で埋め込む）と CYW43 ブロブ（`crates/firmware/cyw43-firmware/*.bin`、ライセンス物）。実値を会話やコミットに載せない。
- サーボ実機合わせはキャリブ定数だけを安全側から調整する。角度→パルス変換（`SERVO_MIN_US` / `SERVO_MAX_US` / `LOCK_DEG` / `UNLOCK_DEG`）は `crates/smtlk-core/src/servo_math.rs`、整定待ち `SETTLE_MS` は `crates/firmware/src/servo.rs`。
- 採寸・ドア固定の未確定値は params/socket/mount_plate に隔離（README「未確定」参照）。
- Cargo.lock はコミット済み。再現は `--locked` で。

## 詳細

コマンド詳細・採寸・TCP プロトコル（LOCK/UNLOCK/STATUS）・書き込み手順は **README.md** を参照。
