---
id: TASK-1
title: Firmware power-saving operation
status: To Do
assignee: []
created_date: '2026-07-20 09:19'
updated_date: '2026-07-20 09:47'
labels:
  - firmware
dependencies: []
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
現状は常時給電と常時稼働の前提で、WiFi 接続と TCP 待ち受けを維持したまま動く。省電力運用（WiFi のパワーセーブ、アイドル時のクロック調整など）は未着手。サーボ給電は既に動作時のみ ON（GP14 の電源ゲート）。必要になったタイミングで方式を検討する。（GitHub issue #80 から移管）
<!-- SECTION:DESCRIPTION:END -->
