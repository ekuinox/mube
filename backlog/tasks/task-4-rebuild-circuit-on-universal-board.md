---
id: TASK-4
title: 回路のユニバーサル基板化（P-03229 へのはんだ実装）
status: To Do
assignee: []
created_date: '2026-07-20 10:04'
labels:
  - circuit
  - scad
dependencies: []
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ブレッドボードで検証済みの回路（サーボ、二色 LED、タクトスイッチの全部載せ同時動作を確認済み）を、ユニバーサル基板 P-03229（秋月 Cタイプ 72×47mm、片面めっき）へはんだ実装し直す。配線の正は `circuit/index.tsx`（tscircuit）。

## 決定済みの前提

- 基板は P-03229。既製の四隅マウント穴は φ3.2、中心間ピッチ 長辺 66mm×短辺 41mm（docs/parts-selection.md）。
- Pico は基板に直付けせず抜き差し式にする: Pico 側にオスピンヘッダ、基板側にメスソケット。ソケット高さで実装高さが +8〜11mm になる。
- 現行トレイはブレッドボード搭載用なので、基板の四隅穴に合わせたマウント（支柱ピッチ 66×41）へ作り替えが要る。ソケット分の高さ増も考慮する。

## 作業項目

- 基板レイアウトを決めてはんだ実装（部品は docs/parts-selection.md の BOM どおり）。
- scad: トレイを P-03229 マウントに作り替え（φ3.2 穴用の支柱、ピッチ 66×41、高さ +8〜11mm 反映）。clash チェックも通す。
- 実装後にブレッドボードと同条件の実機確認（TCP 経由の施錠/解錠、LED、スイッチ）。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 サーボ・LED・スイッチ・TCP 操作がブレッドボード時と同等に動く
- [ ] #2 基板がトレイの四隅支柱（66×41 ピッチ）に固定できる
- [ ] #3 Pico をソケットから抜き差しでき、実装高さがトレイと干渉しない
<!-- AC:END -->
