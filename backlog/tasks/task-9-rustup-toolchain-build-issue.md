---
id: TASK-9
title: RUSTUP_TOOLCHAIN 環境変数によるビルドの問題
status: To Do
assignee: []
created_date: '2026-07-20 10:46'
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
- [ ] #1 再現手順とエラー内容を記録する
- [ ] #2 ツールチェーン指定と RUSTUP_TOOLCHAIN の優先を整理し方針を決める
- [ ] #3 恒久対策を実施しビルドが安定して通ることを確認する
<!-- AC:END -->
