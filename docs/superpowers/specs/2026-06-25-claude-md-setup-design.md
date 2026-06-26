# プロジェクト CLAUDE.md の整備 設計仕様

- 日付: 2026-06-25
- ステータス: 確定
- 対象: リポジトリルートに `CLAUDE.md` を新設し、セッション開始時に概要が乗り、Claude がハマる落とし穴を先回りで潰す
- 関連: ルート `README.md`（詳細はこちらへ委譲）、global `~/.claude/CLAUDE.md`（話し方・秘密ファイル取り扱い）

## 1. 背景と目的

このリポジトリはマルチドメインの monorepo（OpenSCAD 筐体 / Python 回路ネットリスト / STL ビューア / Rust+Embassy ファーム / host テスト可能なロジック）だが、ルートに `CLAUDE.md` が無い。そのため Claude はセッションごとに構成を探り直し、毎回同じ所でハマる（`cargo`/`openscad`/`uv` が素の PATH に無い、`build/` 派生物の非コミット、WiFi 認証や CYW43 ブロブの秘密扱い 等）。

ルート 1 枚の `CLAUDE.md` を置き、(a) プロジェクト概要をセッション開始時にコンテキストへ乗せ、(b) Claude 固有の運用上の地雷を凝縮する。詳細仕様は README に委譲し、重複を避ける（分業）。

### 設計判断

- **役割分担（README と分業）**: README は人間向けの網羅ドキュメントとして既に充実している。CLAUDE.md はそれを再掲せず、「概要 + Claude がハマる所」に特化する。詳細は README へリンクで委譲。
- **ルート 1 枚に集約**: 狙いが「開始時にざっと概要を乗せる」ことなので、必ず読まれるルート 1 枚にする。各エリアへのネスト（`crates/firmware/CLAUDE.md` 等）は情報量が増えてから検討（YAGNI）。
- **簡潔さ優先**: 1 画面〜1 画面半。コマンドの羅列や採寸の数値は README にあるので CLAUDE.md には書かず、「どう打つか」「どこが地雷か」だけ書く。
- **既存 memory との整合**: nix 経由ビルド・worktree 先作り等は既に auto-memory にあるが、memory はセッション横断の私的メモ。プロジェクト同梱の規約として CLAUDE.md にも要点を置き、リポジトリ単体で自己説明できるようにする。

## 2. スコープ

- 作るもの:
  - ルート `./CLAUDE.md`（新規）。下記 §3 の 5 セクション構成。
- 作らないもの（非目標）:
  - 各エリアのネスト CLAUDE.md。
  - README の改訂・再構成（CLAUDE.md からリンクするだけ。README は不変）。
  - コードやビルド設定の変更。本サイクルは文書のみ。
  - 秘密情報（実 SSID/PASSWORD、CYW43 ブロブ）の記載。扱い方の注意のみ書き、値は書かない。

## 3. CLAUDE.md の構成

簡潔な 5 セクション。見出しは短く、各項目 1 行を基本とする。

### 3.1 What this is（1〜2 行）
既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。筐体(OpenSCAD) + 回路(Python netlist) + Pico W ファーム(Rust/Embassy) の monorepo、という 1 文程度。

### 3.2 リポジトリ地図
主要ディレクトリを各 1 行で:
- `scad/` — 筐体（OpenSCAD）
- `circuit/` — 回路ネットリスト（Python, ERC ライト + from-to/bom 生成）
- `viewer/` — STL ブラウザビューア（Three.js + cloudflared）
- `crates/firmware/` — Pico W ファーム（Embassy/CYW43/PWM 接合部、thumbv6m）
- `crates/smtlk-core/` — ハード非依存ロジック（host テスト可）
- `build/` — 派生物（STL/netlist 出力。非コミット）
- `test/`, `docs/` — テスト / 設計ドキュメント

### 3.3 コマンドの正しい打ち方（落とし穴）
本体。Claude が間違えやすい所を凝縮:
- `openscad`/`cargo`/`uv` は nix dev シェルの中にしか無い → **`nix develop -c <cmd>`** 経由で実行。`.sh` 系（`build.sh`/`render.sh`）は自分で dev シェルに再突入するのでそのまま実行可。（注: `nix` CLI 本体が PATH に乗るかは環境側の問題。ホスト固有の PATH 設定は CLAUDE.md に焼かない方針。）
- 筐体ビルド: `./build.sh`（dev シェル外でも自動で nix 経由で再実行）。
- ファームビルド: `nix develop -c cargo build --locked`（既定ターゲット thumbv6m）。
- ロジックの host テスト: `nix develop -c cargo host-test`（実機不要）。
- その他テスト: `./test/render.sh <scad>`、`./test/netlist_test.py`。

### 3.4 触る時に注意（規約・地雷）
- `build/` と `*.stl` は派生物 → **コミットしない**（.gitignore 済み）。
- WiFi 認証情報（`crates/firmware/src/config.rs` の SSID/PASSWORD）と CYW43 ブロブ（`crates/firmware/cyw43-firmware/*.bin`、ライセンス物）は **未コミット・秘密扱い**。値を会話に載せない。
- サーボ実機合わせは少数のキャリブ定数だけを安全側から調整: 角度→パルス変換（`SERVO_MIN_US`/`SERVO_MAX_US`/`LOCK_DEG`/`UNLOCK_DEG`）は `crates/smtlk-core/src/servo_math.rs`、整定待ち `SETTLE_MS` は `crates/firmware/src/servo.rs`。（注: README は旧構成「servo.rs に 5 つ」のままで、host テスト化リファクタ後の現状とズレている。README 修正は本サイクル外だが要追従。）
- 採寸・固定方式の未確定値は params/socket/mount_plate に隔離（README「未確定」参照）。
- Cargo.lock はコミット済み。再現は `--locked` で。

### 3.5 詳細は README.md へ
「コマンド詳細・採寸・プロトコル・書き込み手順は README.md を参照」で締める 1 文。

## 4. 検証方法

- 文書のみの変更のためビルド/テストの実行は不要。
- セルフレビュー（brainstorming のチェックリスト準拠）: プレースホルダ無し / 内部矛盾無し / 参照先（ファイルパス・コマンド）が実在することの確認。特に `cargo host-test` alias、`config.rs`/`servo.rs`/`cyw43-firmware` のパス、`nix develop -c` の打ち方が現状と一致すること。
- README との重複が過剰でないこと（数値・手順の再掲をしていないこと）。

## 5. リスクと留意

- README とコマンドが将来ずれると二重メンテになる。CLAUDE.md は「打ち方と地雷」に限定し、変わりやすい具体値（採寸・GPIO・キャリブ）は README/コード側に残して参照に留める。
- global `~/.claude/CLAUDE.md`（話し方・秘密ファイル規約）と役割が被らないようにする。プロジェクト CLAUDE.md はあくまでこのリポジトリ固有の構成・運用に限定する。
- ネスト CLAUDE.md を作らない判断は、ファーム/回路の情報が増えた段階で再検討の余地がある（本サイクルでは作らない）。
