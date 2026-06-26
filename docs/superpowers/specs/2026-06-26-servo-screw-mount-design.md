# サーボ（SG90）ネジ固定 設計

- 日付: 2026-06-26
- 対象: `scad/`（筐体モデル）
- 目的: サーボをポケット摩擦保持から M2 タッピングねじによる確実な固定へ変更する。

## 背景

現状の筐体はサーボ（SG90）を `sg90_cutout()` のポケットにはめるだけで、ネジ穴を持たない。サーボはサムターンを回す際にトルク反力を受けるため、摩擦保持ではガタつき・脱落のリスクがある。ネジ固定を追加する。

`params.scad` には `servo_screw_d = 2.0` の定義があるが、どのモジュールからも参照されておらず実際のネジ穴を生成していない。

## 現状の幾何

- 原点 = サムターン／サーボ軸（ドアロゼット中心）。
- サーボはシャフトを `-Z`（床）方向に向け、床を貫いて下のサムターン socket に噛み合う。
- `sg90_cutout()`（`hardware.scad`）: 本体キューブ＋タブ逃げ＋シャフト逃げ。**タブ逃げは本体の上端（`+Z`）側**に置かれている。
- `body.scad` でサーボは `translate([0, 0, wall + servo_body_h/2])` に配置（本体下面が床上面 `z = wall`）。

実物の SG90 はマウントの耳（タブ）が出力シャフトと同じ端に付く。シャフトが床向きの本構成では、耳は**床側**に来るのが正しい。現モデルのタブ逃げ位置（上端）は実物と逆であり、ネジ固定の追加に合わせて修正する。

## 方針

1. `sg90_cutout()` のタブ逃げを上端（`+Z`）から床側（`-Z`、シャフト端）へ移す。
2. 床から M2 ねじ用のボスを2本立て、その上にサーボの耳が乗る構成にする。
3. ねじはシャフトと平行（`+Z` から `-Z` 方向）に、上から耳を貫いてボスに締める（M2 セルフタッピング）。
4. サーボは耳ボスの高さ分だけ持ち上がる。

## 変更詳細

### `params.scad`

新パラメータを追加する。`servo_screw_d`（未使用）は整理し、下穴径は `servo_screw_pilot` に置き換える。

```
servo_screw_span  = 27.6;  // 耳のネジ穴 中心間距離（データシート公称・要実測補正）
servo_screw_pilot = 1.8;   // M2 セルフタッピング下穴径
servo_boss_d      = 4.5;   // 耳ボス外径（Pico ボスと同径。ポケット/タブ干渉を回避）
servo_boss_h      = 4.5;   // 床からの耳ボス高さ（実効噛み合い = servo_boss_h − fit_clearance ≈ 4.1mm）
```

サニティチェックを追加する。

```
assert(servo_screw_pilot < servo_boss_d, "pilot hole smaller than boss");
assert(servo_boss_h >= servo_tab_h, "boss tall enough to seat the tab");
assert(servo_screw_span/2 + servo_boss_d/2 <= ext_left, "screw boss within interior (-X side)");
```

### `hardware.scad`

- `sg90_cutout()`: タブ逃げの `translate` を `+Z` 端から `-Z`（床）側へ変更。本体・シャフト逃げは現状維持。
- 新モジュール `servo_mounts()` を追加。`(±servo_screw_span/2, 0)` の2か所に、外径 `servo_boss_d`・高さ `servo_boss_h` のボスを立て、各ボスに `servo_screw_pilot` 径の下穴を貫通させる。`pico_w_mounts()` と同じ作り（`difference` でボス−下穴）。

### `body.scad`

- サーボ配置を `servo_boss_h` 分持ち上げる: `translate([servo_x, servo_y, wall + servo_boss_h + servo_body_h/2])`。
- `union()` 内（実体側）に `servo_mounts()` を追加配置。タブ逃げを移したことで耳ボス上面に耳が当たる位置関係になる。

## 干渉チェック（設計時点で確認済み）

ボス位置 `x = ±servo_screw_span/2 ≈ ±13.8`, `y = 0`、外径 `servo_boss_d = 4.5`（半径2.25）。

- 本体側壁: 内側 X 範囲は `-20 〜 +30`。ボスは `-16.05〜-11.55` / `11.55〜16.05` で壁に当たらない（`-X` 側が最も近く、内壁 `-20` まで約4mm余裕）。
- サーボ本体ポケット: ボスは床〜`servo_boss_h`(4mm) の高さに立ち、サーボ本体ポケットの底（持ち上げ後 `z ≈ wall + servo_boss_h`）はボス上面とほぼ接する。Z 方向の重なりは持ち上げクリアランス `fit_clearance`(0.4mm) 分のみで、ボス上端内側の微小な角が削れる程度（構造・ねじ穴には無影響）。
- MOSFET キープアウト: `y ≈ 19〜31` に位置。ボスは `y = 0` で Y 方向に重ならない。
- Pico スタンドオフ: 遠い `+Y` 側。干渉なし。
- ロゼット凹み（Ø46）: ボスは凹みの真上に来るが、ねじ山はボス本体（高さ `servo_boss_h`）で受けるため薄い床（凹み部 ≈0.9mm）に依存しない。

## 物理前提・注意点

- サーボを `servo_boss_h`（≈4.5mm）持ち上げるため、**シャフトのサムターン socket への差し込み深さが約4.5mm浅くなる**。socket はキャリブ隔離パーツであり、実機合わせで吸収する想定。気になる場合は `servo_boss_h` を詰める／socket 側を調整する。
- タブ逃げキューブはボス上端と `fit_clearance`（0.4mm）だけ重なる。そのため M2 タッピングねじの実効噛み合い深さは `servo_boss_h − fit_clearance ≈ 4.1mm` となる（ボス高さをそのまま噛み合い深さとしないこと）。
- タブ穴間隔 `servo_screw_span = 27.6` はデータシート公称値。実測後はこの値を直すだけで合わせられる。
- 推奨ねじ: **M2 × 6mm 推奨（7mm まで。8mm は床残り約0.5mmと際どいため避ける）**（耳厚 `servo_tab_h=2.5` ＋ボス `servo_boss_h=4.5` を貫き、床を突き抜けない長さ）。下穴 `servo_screw_pilot = 1.8`。

## テスト・検証

- `./test/render.sh scad/smartlock.scad` がエラーなく STL を生成すること（assert を含む幾何整合）。
- 個別モジュール確認のため `./test/render.sh scad/body.scad` も通ること。
- 目視: 生成 STL で耳ボス2本がサーボポケット床側に立ち、下穴が貫通していること、ボスが壁・MOSFET 域と干渉しないこと。

## スコープ外

- socket／サムターン噛み合い深さの再キャリブレーション（別途実機合わせ）。
- 実測値による `servo_screw_span` の確定（実測後に値更新のみ）。
- パーツ表（`docs/parts-selection.md`）への締結部品追記（必要なら別タスク）。
