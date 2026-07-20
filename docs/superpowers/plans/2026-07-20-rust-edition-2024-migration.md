# Rust edition 2024 移行 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `crates/firmware` と `crates/mube-core` を Rust edition 2024 に移行し、workspace を resolver "3" に上げる。

**Architecture:** Rust 公式の標準手順に従う。まず edition 2021 のまま `cargo fix --edition` で 2024 互換コードへ機械移行し、次に Cargo.toml の edition と workspace の resolver を切り替え、ビルド／clippy の fallout を最小修正して CI 相当の検証で確定する。自クレートに `unsafe` / `static mut` は無いため、組み込み特有の unsafe 手直しは発生しない見込み。

**Tech Stack:** Rust stable (devShell rustc 1.96.1), Embassy/CYW43 (thumbv6m-none-eabi), mube-core (host-testable), cargo, clippy。

## Global Constraints

- 実行コマンドはすべて `nix develop -c` を前置する（開発機の非対話シェルは PATH に `cargo` が無い）。作業ディレクトリは worktree `/home/ekuinox/works/repo/ekuinox/mube/.claude/worktrees/edition-2024`。
- toolchain は stable 固定（`rust-toolchain.toml`）。devShell の rustc は 1.96.1 で edition 2024 の要件 1.85+ を満たす。
- 派生物（`scad/build/`・`circuit/build/`・`*.stl`）と CYW43 ブロブ（`crates/firmware/cyw43-firmware/*.bin`）はコミットしない。ブロブはビルド用にダミー（空ファイル）を置く。
- `Cargo.lock` はコミット済み。resolver 変更で差分が出たらコミットに含める。
- WiFi 認証（`WIFI_SSID` / `WIFI_PASSWORD`）や実ブロブの中身を会話・コミットに載せない。
- 検証の合格基準（CI の check ジョブ相当 + host-test）:
  - `nix develop -c cargo host-test`
  - `nix develop -c cargo check -p mube-core --target x86_64-unknown-linux-gnu`
  - `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
  - `nix develop -c cargo clippy -p mube-core --target x86_64-unknown-linux-gnu -- -D warnings`
  - `nix develop -c cargo clippy -p mube-firmware --target thumbv6m-none-eabi -- -D warnings`
- 前提: thumbv6m の std は取得済み（未取得なら `nix develop -c rustup target add thumbv6m-none-eabi`）。ダミーブロブは配置済み（無ければ `touch crates/firmware/cyw43-firmware/{43439A0.bin,43439A0_clm.bin,nvram_rp2040.bin}`）。

---

### Task 1: `cargo fix --edition` による機械移行（edition は 2021 のまま）

edition を上げる前に、2024 互換の書き換えを `cargo fix --edition` で当てる。自クレートは clean なため差分ゼロの可能性が高いが、公式手順として実施し、当たった差分を確定する。

**Files:**
- Modify (fix が触りうる): `crates/mube-core/src/*.rs`, `crates/firmware/src/*.rs`
- 変更なし: `Cargo.toml`（この時点では edition/resolver は据え置き）

**Interfaces:**
- Consumes: なし（移行の起点）。
- Produces: 2024 互換に整えたソース。Task 2 はこの状態から edition を切り替える。

- [ ] **Step 1: 作業ツリーが clean なことを確認**

Run: `cd /home/ekuinox/works/repo/ekuinox/mube/.claude/worktrees/edition-2024 && git status --short`
Expected: 出力なし（ダミーブロブは gitignore 済みで表示されない）。もし未コミットの変更があれば先に退避する。

- [ ] **Step 2: mube-core に cargo fix --edition（host 文脈）**

Run:
```bash
nix develop -c cargo fix --edition -p mube-core --target x86_64-unknown-linux-gnu
```
Expected: `Finished` で終了。`Migrating ...` の後、差分ありなら該当ファイルが書き換わる／差分なしならファイル変更なし。エラーで落ちないこと。

- [ ] **Step 3: firmware に cargo fix --edition（thumbv6m 文脈）**

Run:
```bash
nix develop -c cargo fix --edition -p mube-firmware --target thumbv6m-none-eabi
```
Expected: `Finished` で終了。エラーで落ちないこと。

- [ ] **Step 4: 差分を確認**

Run: `git diff --stat`
Expected: fix が当てた差分（無ければ空）。差分がある場合は内容を目視し、意図した 2024 互換化のみであることを確認する。edition はまだ 2021 なので、この状態でもビルドは通るはず。

- [ ] **Step 5: 2021 のままビルド健全性を確認**

Run:
```bash
nix develop -c cargo check -p mube-core --target x86_64-unknown-linux-gnu && \
nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi
```
Expected: 両方 `Finished`（エラーなし）。

- [ ] **Step 6: コミット（差分がある場合のみ）**

差分が無ければこの Task はコミット不要。差分がある場合:
```bash
git add crates/
git commit -m "$(cat <<'EOF'
refactor: cargo fix --edition で 2024 互換へ機械移行 (TASK-11)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: コミット作成、または「差分なしのためスキップ」を記録。

---

### Task 2: edition を 2024 へ、resolver を "3" へ切替し fallout を修正・検証

Cargo.toml 3 ファイルを書き換え、ビルド／clippy の fallout を最小修正し、CI 相当 + host-test で確定する。

**Files:**
- Modify: `crates/firmware/Cargo.toml:4`（`edition = "2021"` → `edition = "2024"`）
- Modify: `crates/mube-core/Cargo.toml:4`（`edition = "2021"` → `edition = "2024"`）
- Modify: `Cargo.toml:2`（`resolver = "2"` → `resolver = "3"`）
- Modify (発生時のみ): `crates/*/src/*.rs`（edition 2024 の fallout 修正）
- Modify (発生時のみ): `Cargo.lock`（resolver 変更に伴う版選択差分）

**Interfaces:**
- Consumes: Task 1 が整えた 2024 互換ソース。
- Produces: edition 2024 / resolver "3" で全検証が通る状態。TASK-11 の受け入れ条件を満たす最終形。

- [ ] **Step 1: mube-core の edition を 2024 に**

`crates/mube-core/Cargo.toml` の 4 行目を書き換える:
```toml
edition = "2024"
```
（変更前: `edition = "2021"`）

- [ ] **Step 2: firmware の edition を 2024 に**

`crates/firmware/Cargo.toml` の 4 行目を書き換える:
```toml
edition = "2024"
```
（変更前: `edition = "2021"`）

- [ ] **Step 3: workspace の resolver を "3" に**

`Cargo.toml`（workspace ルート）の 2 行目を書き換える:
```toml
resolver = "3"
```
（変更前: `resolver = "2"`）

- [ ] **Step 4: host 側ビルドを実行して fallout を確認**

Run: `nix develop -c cargo check -p mube-core --target x86_64-unknown-linux-gnu`
Expected: `Finished`。エラーが出たら内容を読み、下記チェックリストに沿って最小修正する。
- RPIT ライフタイム捕捉: `impl Trait`/`impl Future` 戻り値で借用エラーが出たら `+ use<'_>` 等で捕捉を明示。
- prelude 追加（`Future`/`IntoFuture`）: 同名メソッド衝突があれば完全修飾で解消。
- `gen` 予約語: 識別子衝突があれば `r#gen` またはリネーム。
- never 型フォールバック: 型推論エラーが出たら明示的な型注釈を付す。
修正したら本 Step を再実行し `Finished` になるまで繰り返す。

- [ ] **Step 5: thumbv6m 側ビルドを実行して fallout を確認**

Run: `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
Expected: `Finished`。エラーは Step 4 と同じチェックリストで最小修正し、`Finished` まで繰り返す。

- [ ] **Step 6: host-test を実行**

Run: `nix develop -c cargo host-test`
Expected: `test result: ok. 20 passed; 0 failed`（移行前の基準線と同じ 20 件）。

- [ ] **Step 7: clippy（host / thumbv6m 両方、`-D warnings`）を実行**

Run:
```bash
nix develop -c cargo clippy -p mube-core --target x86_64-unknown-linux-gnu -- -D warnings && \
nix develop -c cargo clippy -p mube-firmware --target thumbv6m-none-eabi -- -D warnings
```
Expected: 両方 `Finished`（警告ゼロ）。edition 2024 の新規 lint が出たら最小修正して再実行する。

- [ ] **Step 8: Cargo.lock の差分を確認**

Run: `git diff --stat Cargo.lock`
Expected: resolver "3" 由来の差分が出る場合がある。差分が出たら Step 4–7 が全て通っていることを再確認し、そのままコミット対象に含める。差分が大きくビルドが壊れる場合は spec のリスク節に従い resolver を "2" に戻す判断を検討する（その場合はユーザーに相談）。

- [ ] **Step 9: 最終確認（受け入れ条件の一括再実行）**

Run:
```bash
grep -n '^edition' crates/firmware/Cargo.toml crates/mube-core/Cargo.toml && \
grep -n 'resolver' Cargo.toml && \
nix develop -c cargo host-test && \
nix develop -c cargo check -p mube-core --target x86_64-unknown-linux-gnu && \
nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi && \
nix develop -c cargo clippy -p mube-core --target x86_64-unknown-linux-gnu -- -D warnings && \
nix develop -c cargo clippy -p mube-firmware --target thumbv6m-none-eabi -- -D warnings
```
Expected: edition 2 箇所が `2024`、resolver が `"3"`、host-test 20 passed、check 2 件と clippy 2 件が全て `Finished`。

- [ ] **Step 10: コミット**

```bash
git add Cargo.toml Cargo.lock crates/firmware/Cargo.toml crates/mube-core/Cargo.toml crates/
git commit -m "$(cat <<'EOF'
build: Rust edition 2024 へ移行・workspace resolver を 3 に (closes TASK-11)

両クレートの edition を 2024 に、workspace resolver を 3 に更新。
host-test / thumbv6m check / clippy(-D warnings) を確認。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: コミット作成。`git status` が clean。

---

## 完了後

- backlog の TASK-11 を Done にする（`creating-backlog-tasks` スキル / `backlog task edit` 系）。受け入れ条件のチェックを埋める。
- PR 作成はユーザーの指示があってから（このリポジトリは PR 運用。ブランチ `worktree-edition-2024`）。
