---
id: TASK-2
title: 'ファーム: 手回し操作後の施錠状態の再同期'
status: To Do
assignee: []
created_date: '2026-07-20 09:19'
labels:
  - firmware
dependencies: []
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
サムターンを直接手で回して施錠状態が変わっても、ファームの LockState はそれを検知できないため、二色 LED の表示と STATUS 応答が実際の状態とずれる。位置検出の手段（センサ追加など）や再同期の方法は未検討。室内側の操作としてはタクトスイッチのトグルがあり、こちらは状態に反映される。問題になるのはスイッチを経由しない手回しのみ。（GitHub issue #81 から移管）
<!-- SECTION:DESCRIPTION:END -->
