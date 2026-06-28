# Issue #13 修正 + CI 導入

## 概要

spawner.spawn() の括弧位置バグ (Issue #13) を修正し、再発防止として GitHub Actions CI を導入する。

## 1. spawner.spawn() 括弧位置修正

対象: `crates/firmware/src/main.rs`

3箇所で `.unwrap()` が `spawner.spawn()` の戻り値ではなくタスク関数の戻り値 (`SpawnToken`) に対して呼ばれている。`SpawnToken` は `unwrap()` を持たないため型エラーになるが、CYW43 ブロブ未配置によるマクロ展開エラーが先に発生するため隠れていた。

修正内容:

```rust
// 修正前（誤）
spawner.spawn(servo_task(servo).unwrap());
spawner.spawn(cyw43_task(runner).unwrap());
spawner.spawn(net_task(net_runner).unwrap());

// 修正後（正）
spawner.spawn(servo_task(servo)).unwrap();
spawner.spawn(cyw43_task(runner)).unwrap();
spawner.spawn(net_task(net_runner)).unwrap();
```

## 2. GitHub Actions CI

### ファイル

`.github/workflows/ci.yml`

### トリガー

- `push`: master ブランチ
- `pull_request`: master ブランチ向け

### ランナー

`ubuntu-latest` (x86_64)

### 環境セットアップ

- `dtolnay/rust-toolchain` action で `rust-toolchain.toml` を自動適用 (stable + thumbv6m-none-eabi ターゲット + clippy コンポーネント)
- Nix は不要 (CI では Rust ツールチェーンのみ使用)
- CYW43 ダミーブロブ: `touch` で空ファイルを作成して `aligned_bytes!` マクロの展開を通す

### チェック内容

| ステップ | 対象 | コマンド | 備考 |
|---|---|---|---|
| check | smtlk-core | `cargo check -p smtlk-core --target x86_64-unknown-linux-gnu` | ホストターゲット |
| check | smtlk-firmware | `cargo check -p smtlk-firmware --target thumbv6m-none-eabi` | ダミーブロブで型検査 |
| clippy | smtlk-core | `cargo clippy -p smtlk-core --target x86_64-unknown-linux-gnu -- -D warnings` | 警告をエラー扱い |
| clippy | smtlk-firmware | `cargo clippy -p smtlk-firmware --target thumbv6m-none-eabi -- -D warnings` | 警告をエラー扱い |
| test | smtlk-core | `cargo test -p smtlk-core --target x86_64-unknown-linux-gnu` | ホストテスト |

### CYW43 ダミーブロブの仕組み

firmware crate の `main.rs` は `cyw43::aligned_bytes!("../cyw43-firmware/43439A0.bin")` でバイナリブロブを埋め込む。このマクロは `include_bytes!` のアライメント付き版で、ファイルが存在しないとコンパイルが失敗する。CI ではライセンス物のブロブをコミットできないため、空ファイルをステップ内で作成してマクロ展開を通す。これにより型検査まで到達でき、Issue #13 のような括弧位置バグを検出できる。

## 3. CLAUDE.md へのルール追記

「触る時の注意」セクションに、Rust コード変更時はコミット前に `nix develop -c cargo host-test` を通すルールを追記する。CI と同じ基準をローカルでも守る運用。

## スコープ外

- OpenSCAD レンダリングテスト (Nix + Mesa 環境が必要)
- 回路ネットリストテスト (Python/uv 環境が必要)
- firmware の実機テスト
