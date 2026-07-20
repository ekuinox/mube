---
id: TASK-11
title: Rust edition 2024 へ移行する
status: To Do
assignee: []
created_date: '2026-07-20 11:20'
labels:
  - rust
dependencies: []
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
crates/firmware と crates/mube-core は edition = "2021"。Rust edition 2024 へ移行する。toolchain は stable（rust-toolchain.toml）で edition 2024 の要件（1.85+）は既に満たしている。

手順の目安: cargo fix --edition で機械移行 → Cargo.toml の edition を 2024 へ → 手直し。組み込み側は edition 2024 の変更（unsafe 属性の明示化、static mut 参照の禁止など）が firmware クレートの unsafe 周りに当たりやすいので注意。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 両クレートの edition が 2024 になっている
- [ ] #2 cargo build（thumbv6m）と cargo host-test が通る
- [ ] #3 clippy が警告なしで通り CI が green
<!-- AC:END -->
