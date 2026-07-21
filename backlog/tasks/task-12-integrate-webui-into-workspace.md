---
id: TASK-12
title: webui クレートを workspace メンバに統合し crates/* を一律扱いにする
status: Done
assignee: []
created_date: '2026-07-20 15:25'
updated_date: '2026-07-21 10:17'
labels:
  - firmware
dependencies: []
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
crates/webui（yew/WASM）はビルドターゲットが wasm32-unknown-unknown で、ルート workspace が thumbv6m-none-eabi 既定のため、現在はルートの `exclude` で workspace から外し、webui 側に空の `[workspace]` を持たせて独立クレート化している。

この空 `[workspace]` は、開発を git worktree（親リポジトリ配下の `.claude/worktrees/<name>` にネスト）で行う都合上必須になっている。無いと cargo が worktree ルートの `exclude` を越えて親リポジトリの workspace を拾い、`trunk build` が「believes it's in a workspace when it's not」で失敗する。

これを解消し、`crates/*` を一律 workspace メンバとして扱える構成に改善したい（例: クレートごとの `.cargo/config.toml` によるターゲット分離、per-package の default target 指定、あるいはメンバ化しても各クレートが自分のターゲットでビルドされる仕組み）。狙いは exclude と空 `[workspace]` の撤去、および crates 追加時の一貫した扱い。

PR #83（TASK-10 WebUI）のレビューからの follow-up。
- Cargo.toml「crates/* を一通りメンバとして扱うように今後改善したい（今回は良い）」
- crates/webui/Cargo.toml の `[workspace]`「いらない」（worktree 開発のため今回は残置）
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 crates/webui をルート workspace のメンバとして扱い、exclude と webui 側の空 [workspace] を撤去（または同等に不要化）する
- [x] #2 ルートの cargo build（thumbv6m 既定）が webui の wasm32 クレートで壊れない（ターゲット分離等で解決）
- [x] #3 trunk build --release が git worktree（.claude/worktrees/ ネスト）でも成功する
- [x] #4 firmware への dist 埋め込み（include_bytes）と CI が引き続きグリーン
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
crates/* を一律 workspace メンバ化して解決した。

- ルート Cargo.toml: members = ["crates/*"] + default-members = ["crates/firmware", "crates/mube-core"]。cargo は 1 起動 1 ターゲットなので、wasm32 専用の webui は素の cargo build（thumbv6m 既定）から外し、trunk が --target wasm32-unknown-unknown を明示してビルドする。
- webui の空 [workspace] と exclude を撤去。メンバ化により worktree でも root workspace が正しく解決され、trunk build --release が通ることを確認済み。
- webui の [profile.release] はルートへ移設（[profile.release.package.webui] opt-level="z", debug=false。lto はルートの fat が適用、wasm32 は panic=abort 相当）。
- webui/Cargo.lock を削除しルートの Cargo.lock に統合。
- 検証: trunk build --release（worktree 内）/ cargo build（dev・release、実 dist + 実 CYW43 ブロブ）/ cargo host-test（7 passed）/ CI 相当の clippy -D warnings（mube-core・mube-firmware、--locked）すべて成功。
<!-- SECTION:NOTES:END -->
