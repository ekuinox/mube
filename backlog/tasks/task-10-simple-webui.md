---
id: TASK-10
title: 簡単な WebUI から施錠/解錠と状態確認をしたい
status: To Do
assignee: []
created_date: '2026-07-20 10:46'
labels:
  - firmware
dependencies: []
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
簡単な WebUI が欲しい。現状は生の TCP プロトコル（LOCK / UNLOCK / STATUS。docs/firmware.md 参照）で操作する必要があり、スマホやブラウザから手軽に施錠/解錠・状態確認ができない。

やりたいこと:
- ブラウザから施錠/解錠ボタンと現在状態（LockState）が見える最小限の WebUI。
- 実現方式の検討（Pico W 上で HTTP を直接提供するか、別途 TCP をブリッジする軽量サーバ／ページを用意するか）。まずは最小構成で。

関連: プロトコルは docs/firmware.md、ロジックは `crates/smtlk-core/`。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ブラウザから施錠/解錠と現在状態(LockState)を操作・確認できる最小 WebUI を用意する
- [ ] #2 実現方式（Pico W 直提供 or ブリッジ）を検討して決める
<!-- AC:END -->
