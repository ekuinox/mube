# Rust edition 2024 への移行（設計）

対象タスク: TASK-11「Rust edition 2024 へ移行する」

## 背景と現状

`crates/firmware` と `crates/mube-core` はどちらも `edition = "2021"`。workspace の
`Cargo.toml` は `resolver = "2"`。toolchain は stable（`rust-toolchain.toml`）で、
devShell の rustc は 1.96.1。edition 2024 の要件（1.85+）は満たしている。

事前調査でわかったこと:

- 両クレートに `unsafe` ブロックは **1 個も無い**（`grep -rn unsafe crates/` がゼロ）。
- `static mut` も無い。TASK-11 の説明が警戒していた「組み込みの unsafe 周りの手直し」は
  自クレートには発生しない見込み。
- `#[no_mangle]` / `#[export_name]` / `#[link_section]` を **自クレートは直接書いていない**
  （メモリレイアウトは `build.rs` + `memory.x` + 依存の cortex-m-rt / embassy 経由）。
  これらの属性を生成するのは依存クレートのマクロで、edition は各マクロ定義クレート側に従う。
- `option_env!`（`config.rs` の WiFi 認証埋め込み）は edition 2024 の影響を受けない。

## ゴール（受け入れ条件）

1. `crates/firmware` / `crates/mube-core` の `edition = "2024"`。
2. workspace `Cargo.toml` の `resolver = "3"`。
3. `cargo build`（thumbv6m）と `cargo host-test` が通る。
4. clippy が警告なし（`-D warnings`）で host / thumbv6m 両方通る。
5. CI（`.github/workflows/ci.yml` の check ジョブ）が green。

## 方針

機械移行（`cargo fix --edition`）を先に当てて 2024 互換コードにしてから edition を上げる、
Rust 公式の標準手順に従う。unsafe/static mut が無いため差分は小さいと見込むが、
下記の edition 2024 変更点を検証で確認する。

### 手順

1. **機械移行（cargo fix）**
   - mube-core（host 文脈）: `cargo fix --edition -p mube-core --target x86_64-unknown-linux-gnu`
   - firmware（thumbv6m 文脈）: `cargo fix --edition -p mube-firmware --target thumbv6m-none-eabi`
   - この段階では Cargo.toml の edition は 2021 のまま。fix が 2024 互換の書き換えを当てる。
2. **edition / resolver の切替**
   - `crates/firmware/Cargo.toml` と `crates/mube-core/Cargo.toml` を `edition = "2024"`。
   - workspace `Cargo.toml` を `resolver = "2"` → `"3"`。
3. **手直し**
   - `cargo build` / `cargo clippy` で出たエラー・警告のみ最小修正する。
4. **検証**（CI 相当 + host-test）
   - `cargo host-test`
   - `cargo check -p mube-core --target x86_64-unknown-linux-gnu`
   - `cargo check -p mube-firmware --target thumbv6m-none-eabi`
   - `cargo clippy -p mube-core --target x86_64-unknown-linux-gnu -- -D warnings`
   - `cargo clippy -p mube-firmware --target thumbv6m-none-eabi -- -D warnings`
   - `Cargo.lock` の差分を確認（resolver "3" で版選択が変わる可能性）。
   - 実行はいずれも `nix develop -c` を前置する（開発機の非対話シェルは PATH に cargo が無い）。

### edition 2024 の変更点チェックリスト（手直しで当たりうる箇所）

- **RPIT のライフタイム捕捉変更**: `impl Trait` / `impl Future` を返す関数が
  in-scope のライフタイムを既定で捕捉するようになる。`serve` ループなど async 境界で
  戻り値型に影響が出ないか確認する（必要なら `+ use<>` で明示）。
- **prelude 追加**: `Future` / `IntoFuture` が prelude に入る。同名メソッドの
  曖昧化が起きないか確認する。
- **`gen` 予約語化**: 識別子に `gen` を使っていないか（現状 grep で該当なしの見込み）。
- **never 型フォールバック**: `!` → `()` のフォールバック変更に依存した箇所が無いか。
- **unsafe 属性化**: `#[no_mangle]` 等は自クレートに無いため対象外。依存マクロ由来は
  各マクロ定義クレートの edition に従うため、自クレートの移行では触らない。

## リスク

- **resolver "3" による Cargo.lock 差分**: 依存の版選択が変わり得る。CI は `--locked` の
  ため、更新後の `Cargo.lock` をコミットに含める。差分が大きい／ビルドが壊れる場合は
  切り戻し（resolver は "2" のまま edition だけ上げる）も選択肢として記録する。
- **環境要因（TASK-9 系）**: 開発機の rustup devShell に thumbv6m の std が未取得だと
  firmware ビルドが E0463 で失敗する。`rustup target add thumbv6m-none-eabi` で解消する
  （移行作業とは独立。今回の基準線確認時に実施済み）。

## 作業環境

`/using-git-worktrees` に従い、隔離 worktree
`.claude/worktrees/edition-2024`（ブランチ `worktree-edition-2024`）で実施する。
移行前の基準線は確認済み: host-test 20 passed、firmware check（thumbv6m）OK、
clippy（host / thumbv6m, `-D warnings`）OK。

## スコープ外

- 依存クレート（embassy 等）の版アップ。
- resolver 変更に伴う機能追加や依存整理。
- firmware の unsafe 化・リファクタ（そもそも unsafe が無い）。
