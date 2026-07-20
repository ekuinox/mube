---
id: TASK-13
title: webui と firmware で API 型(JSON 契約)を共有する
status: To Do
assignee: []
created_date: '2026-07-20 15:38'
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
- [ ] #1 ロック状態/レスポンスの型を mube-core に一本化し、webui と firmware が同じ定義を使う
- [ ] #2 mube-core の serde は optional feature（firmware の no_std/no-alloc を壊さない）
- [ ] #3 webui は共有型で JSON をデシリアライズし、独自の StatusResponse を廃する
- [ ] #4 firmware の as_json 手書き const を共有シリアライズに置換できるか検討する（serde-json-core 等）
<!-- AC:END -->
