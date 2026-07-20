---
id: TASK-5
title: サーボマウントのネジ受けがねじ止め中に上方向へ千切れる
status: To Do
assignee: []
created_date: '2026-07-20 10:46'
labels:
  - scad
dependencies: []
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
サーボモーターを筐体に固定するネジ受け（ボス）が、ねじ止めの最中に上方向（造形の積層方向）へ千切れて破断する。FDM 造形のため積層面が弱く、ねじ込みトルクと軸方向の引き抜き力にボスが耐えられていないと推測。

対策候補:
- ボスの肉厚を増やす／根元にフィレット・リブを追加する
- ボスの造形方向を見直す、またはナット埋め込み（ヒートインサート）に変更する
- ネジ径・下穴径・ねじ込みトルクの見直し

関連: `scad/` の筐体モデル。プリンタは Bambu A1 mini（0.4mm ノズル / 0.2mm 層）。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ねじ止め時にネジ受け（ボス）が破断しない固定方式にする
- [ ] #2 肉厚増し・リブ/フィレット・ヒートインサート等の対策を比較検討して方針を決める
<!-- AC:END -->
