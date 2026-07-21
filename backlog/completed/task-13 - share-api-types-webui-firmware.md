---
id: TASK-13
title: webui と firmware で API 型(JSON 契約)を共有する
status: Done
assignee: []
created_date: '2026-07-20 15:38'
updated_date: '2026-07-21 11:03'
labels:
  - firmware
dependencies: []
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
webui と firmware で API の型（ロック状態 / JSON 契約）を共有し、二重定義をなくす。

現状:
- firmware は mube-core の `LockState::as_json()`（手書きの const 文字列 `{"state":"LOCKED"}` 等）を返す。
- webui は独自の `StatusResponse { state: &str }` を serde-json-core でパースし、値を判定している。
- 両者が同じ JSON 契約を別々に持っており、片方だけ変えると不整合になりうる。

やりたいこと:
- mube-core に serde を feature 追加し（既存の defmt feature と同様に optional）、状態型 or レスポンス型に `#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]` を付けて共有する。
- webui は mube-core の型を使ってデシリアライズ（serde-json-core）。firmware も同型を no_std・no-alloc の serde-json-core でシリアライズできれば、as_json の手書き const を廃せる。
- webui から mube-core への path 依存はワークスペース除外境界をまたぐため、TASK-12（webui を workspace メンバに統合）と合わせて設計するのが自然。

PR #83（TASK-10 WebUI）レビューからの follow-up。「型を webui と firm 側で共有したい」。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ロック状態/レスポンスの型を mube-core に一本化し、webui と firmware が同じ定義を使う
- [x] #2 mube-core の serde は optional feature（firmware の no_std/no-alloc を壊さない）
- [x] #3 webui は共有型で JSON をデシリアライズし、独自の StatusResponse を廃する
- [x] #4 firmware の as_json 手書き const を共有シリアライズに置換できるか検討する（serde-json-core 等）
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
mube-core に JSON 契約を一本化した。

- mube-core に optional な serde feature を追加（default-features 無しの derive のみ。no_std/no-alloc 維持）。LockState に cfg_attr で Serialize/Deserialize + rename_all = "SCREAMING_SNAKE_CASE"（"LOCKED"/"UNLOCKED"）を付与し、契約型 StatusResponse { state: LockState } を webapi.rs に追加。
- webui は独自 StatusResponse を廃止し、mube-core = { features = ["serde"] } の共有型で serde-json-core パースに置換。webui の直接 serde 依存も削除。
- as_json() の手書き const は置換せず残した（AC#4 の検討結果）。理由: 取りうる値が 2 つだけで &'static str ならフラッシュ直置き・バッファ管理不要。代わりに契約テスト as_json_matches_serde_contract で serde 直列化・デシリアライズとの一致を担保（片方だけ変えるとテストが落ちる）。
- cargo host-test（flake の cargo-host-test）と CI の mube-core 各ステップに --all-features を追加し、契約テストが常に回るようにした。
- 検証: cargo host-test 8 passed（契約テスト含む）/ trunk build --release 成功（wasm 132,731 bytes、+1KB は enum デシリアライズ分）/ cargo build（firmware）/ clippy -D warnings（mube-core --all-features・mube-firmware、--locked）すべて成功。
<!-- SECTION:NOTES:END -->
