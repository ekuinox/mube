# プロジェクト CLAUDE.md 整備 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** リポジトリルートに `CLAUDE.md` を新設し、セッション開始時にプロジェクト概要と Claude 固有の落とし穴がコンテキストに乗るようにする。

**Architecture:** ルート 1 枚の Markdown。README とは分業し、概要 + 運用上の地雷に特化、詳細は README へ委譲。コード変更なし、文書のみ。

**Tech Stack:** Markdown のみ。検証は参照先パス/コマンドの実在確認（事前確認済み）。

## Global Constraints

- 配置はルート `./CLAUDE.md` 1 枚のみ。ネスト CLAUDE.md は作らない。
- README の数値・手順を再掲しない（分業）。詳細は README.md へリンクで委譲。
- 秘密情報の実値（実 SSID/PASSWORD、CYW43 ブロブ内容）は記載しない。
- 簡潔に（1 画面〜1 画面半）。各項目 1 行基本。
- 関連 spec: `docs/superpowers/specs/2026-06-25-claude-md-setup-design.md`。

---

### Task 1: ルート CLAUDE.md を作成

**Files:**
- Create: `CLAUDE.md`（リポジトリルート）

**Interfaces:**
- Consumes: なし（新規文書）。参照先 `README.md`、`build.sh`、`crates/firmware/src/config.rs`、`crates/firmware/cyw43-firmware/`、`crates/smtlk-core/src/servo_math.rs`、`crates/firmware/src/servo.rs`、`.cargo/config.toml` の `host-test` alias は本サイクル開始時点で実在確認済み。
- Produces: ルート `CLAUDE.md`（セッション開始時に自動でコンテキストへ乗る）。

- [ ] **Step 1: `CLAUDE.md` を以下の内容で作成**

````markdown
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

- `build/` と `*.stl` は派生物。コミットしない（.gitignore 済み）。
- 秘密扱い・未コミット: WiFi 認証（`crates/firmware/src/config.rs` の `WIFI_SSID` / `WIFI_PASSWORD`）と CYW43 ブロブ（`crates/firmware/cyw43-firmware/*.bin`、ライセンス物）。実値を会話やコミットに載せない。
- サーボ実機合わせはキャリブ定数だけを安全側から調整する。角度→パルス変換（`SERVO_MIN_US` / `SERVO_MAX_US` / `LOCK_DEG` / `UNLOCK_DEG`）は `crates/smtlk-core/src/servo_math.rs`、整定待ち `SETTLE_MS` は `crates/firmware/src/servo.rs`。
- 採寸・ドア固定の未確定値は params/socket/mount_plate に隔離（README「未確定」参照）。
- Cargo.lock はコミット済み。再現は `--locked` で。

## 詳細

コマンド詳細・採寸・TCP プロトコル（LOCK/UNLOCK/STATUS）・書き込み手順は **README.md** を参照。
````

- [ ] **Step 2: 参照先の実在を確認**

Run:
```bash
test -f README.md \
  && test -f build.sh \
  && test -f crates/firmware/src/config.rs \
  && test -d crates/firmware/cyw43-firmware \
  && test -f crates/smtlk-core/src/servo_math.rs \
  && test -f crates/firmware/src/servo.rs \
  && grep -q 'host-test' .cargo/config.toml \
  && echo OK
```
Expected: `OK`（CLAUDE.md が参照する全パス/alias が実在）

- [ ] **Step 3: 内容セルフチェック**

確認項目（目視）:
- プレースホルダ（TBD/TODO）が無い。
- README の数値・手順を再掲していない（採寸値・GPIO・プロトコル詳細はリンクのみ）。
- 秘密の実値が書かれていない（`YOUR_WIFI_SSID` 等のプレースホルダ名のみ参照）。
- 1 画面〜1 画面半に収まっている。

- [ ] **Step 4: コミット**

```bash
git add CLAUDE.md
git commit -m "docs: ルート CLAUDE.md を新設（概要 + Claude 向け落とし穴、詳細は README へ委譲）"
```

---

## Self-Review

**1. Spec coverage（spec §3 の各セクション → 本プラン Task 1 Step 1 で網羅）:**
- §3.1 What this is → 冒頭 1 文。✓
- §3.2 リポジトリ地図 → 「リポジトリ地図」節。✓
- §3.3 コマンドの打ち方 → 「コマンドの打ち方」節（.sh 自己再突入 vs nix 必須の区別を追加）。✓
- §3.4 触る時の注意 → 「触る時の注意」節（servo キャリブの正しい場所を反映）。✓
- §3.5 詳細は README へ → 「詳細」節。✓

**2. Placeholder scan:** プラン内に TBD/TODO/「後で」等なし。CLAUDE.md 本文も完全な確定文。✓

**3. Type consistency:** 参照するファイルパス・定数名・alias 名は spec および事前 grep の実値と一致（`servo_math.rs` の 4 定数、`servo.rs` の `SETTLE_MS`、`config.rs` の `WIFI_SSID`/`WIFI_PASSWORD`、`host-test` alias）。✓
