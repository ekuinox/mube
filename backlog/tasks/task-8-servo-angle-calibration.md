---
id: TASK-8
title: 'サーボ角度キャリブレーション: 0/90度が出ず可動範囲が実測0-100度'
status: To Do
assignee: []
created_date: '2026-07-20 10:46'
labels:
  - firmware
dependencies: []
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
施錠/解錠の角度が意図通りに出ておらず、取り付け位置がシビア。ソースは 0〜180 度を前提にしているが、実機では概ね 0〜100 度くらいの範囲でしか回っていない（サーボ個体・ホーンの初期位置・取り付けオフセットの影響と推測）。

やること:
- 実機での可動範囲とサムターンの施錠/解錠位置を実測する。
- 角度→パルス変換のキャリブ定数（`SERVO_MIN_US` / `SERVO_MAX_US` / `LOCK_DEG` / `UNLOCK_DEG`、`crates/smtlk-core/src/servo_math.rs`）を実測に合わせて安全側から調整する。
- 取り付けのシビアさを機構側で吸収できないか（ホーン位置の微調整代、スプライン合わせ、取り付けオフセット）検討する。

関連: `crates/smtlk-core/src/servo_math.rs`、整定待ちは `crates/firmware/src/servo.rs` の `SETTLE_MS`。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 実機の可動範囲と施錠/解錠位置を実測し記録する
- [ ] #2 servo_math.rs のキャリブ定数を実測に合わせ安全側から調整する
- [ ] #3 取り付け位置のシビアさを機構側で吸収する余地を検討する
<!-- AC:END -->
