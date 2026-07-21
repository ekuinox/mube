---
id: TASK-9
title: RUSTUP_TOOLCHAIN 環境変数によるビルドの問題
status: Done
assignee: []
created_date: '2026-07-20 10:46'
updated_date: '2026-07-21 10:17'
labels:
  - firmware
dependencies: []
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ビルド時に `RUSTUP_TOOLCHAIN` 環境変数が絡んで問題が起きる（環境変数がリポジトリの `rust-toolchain.toml` によるツールチェーン選択やクロスターゲット `thumbv6m-none-eabi` のビルドに干渉する疑い）。

やること:
- 具体的な再現手順とエラーメッセージを記録する（どの環境／シェルで `RUSTUP_TOOLCHAIN` が設定され、何が壊れるか）。
- リポジトリのツールチェーン指定と `RUSTUP_TOOLCHAIN` の優先順位を整理し、どちらを正とするか方針を決める。
- 恒久対策（ドキュメント追記、`.cargo/config` や devShell 側での明示的な unset／設定など）を検討する。

メモ: この開発機では非対話シェルの PATH に cargo が無く、ビルドは `nix develop -c cargo ...` 経由。詳細は追って追記する。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 再現手順とエラー内容を記録する
- [x] #2 ツールチェーン指定と RUSTUP_TOOLCHAIN の優先を整理し方針を決める
- [x] #3 恒久対策を実施しビルドが安定して通ることを確認する
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
rust-overlay 導入で恒久対策した。

- 原因: devShell の cargo/rustc が rustup のシムで、環境変数 RUSTUP_TOOLCHAIN が rust-toolchain.toml より優先される（rustup の仕様）。外部環境（ハーネス等）が RUSTUP_TOOLCHAIN を設定していると、未インストールの toolchain を指して cargo 起動自体が失敗するため env -u RUSTUP_TOOLCHAIN が必要だった。
- 方針: リポジトリの rust-toolchain.toml を正とする。
- 対策: flake.nix を rust-overlay（oxalica）化し、pkgs.rustup を rust-bin.fromRustupToolchainFile ./rust-toolchain.toml に置換。cargo/rustc が実バイナリになり RUSTUP_TOOLCHAIN の影響を受けない。RUSTUP_TOOLCHAIN=nonexistent-toolchain を与えても cargo --version / ビルドが正常動作することを確認済み（rustup シムなら即失敗する）。
- 副次効果: シェル起動時の rustup チャネル同期（ネット接続）が不要になり、toolchain は flake.lock で固定される（更新は nix flake update rust-overlay）。rustup 利用者向けの rust-toolchain.toml 自動導入は従来どおり有効。
<!-- SECTION:NOTES:END -->
