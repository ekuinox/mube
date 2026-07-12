# 筐体拡大＋ブレッドボードトレイ Implementation Plan (workstream B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 電子部品トレイを「Pico＋スタック基板」から「Pico＋ブレッドボードを横並び」に作り替え、ブレッドボード（実測 85.5×54.5mm）が収まるよう筐体を +X／+Y に拡大する。回路・ファームは非依存で不変。

**Architecture:** 座標原点＝サムターン／サーボ軸。−X（ドア枠 ≤50）／−Y（ハンドル ≤65）は硬い制約で不変、拡大は +X／+Y に逃がす。トレイはワールド座標で構築し、Pico を +Y 天井壁寄り（`pico_y` は USB プラグ届き 11mm を保つ式で導出）、その右へブレッドボードを浅い囲い壁ポケットで落とし込む。トレイ→本体固定は master と同じ「本体裏から M2 セルフタップでトレイ固定ポストへ」を踏襲し、ポストは BB を避けて 4 本再配置する。Pico は位置決めピン継続＋コーナー爪で押さえる。

**Tech Stack:** OpenSCAD（Nix dev シェル内）。テストは `assert()`（ジオメトリが空でも走る）と `./test/render.sh`（`WARNING:`/`ERROR:` で FAIL）、2D の `layout_check.scad` は SVG 出力で確認。

## Global Constraints

- コマンドは Nix dev シェル内でのみ動く。`.sh` 系（`./build.sh`, `./test/render.sh`）はそのまま実行可、素の `openscad` は `nix develop -c openscad …` 経由。
- 印刷補正: Bambu A1 mini（0.4ノズル/0.2mm層）。M2 セルフタップ下穴はトレイ実績値 `tray_screw_pilot = 2.1`。
- 座標: 原点=軸。−X=左（`clear_left=50`）／−Y=下（`clear_down=65`）は不変の硬い制約。+X=右／+Y=上へ拡大。
- ブレッドボード実測: 85.5 × 54.5mm（ハーフ 400穴相当）。厚み `bb_t` は未実測（形状はポケット壁高で決まり `bb_t` には依存させない。公称 9 を情報として置く）。
- コメントは日本語で、説明を十分に付ける（repo 規約）。
- `build/` と `*.stl` は派生物。コミットしない。
- ソース変更は本ブランチ `feat/breadboard-tray`（`origin/master` e154943 から分岐済み）。回路 `circuit/`・ファーム `crates/` は触らない。
- DRY / YAGNI / TDD / こまめにコミット。

---

### Task 1: params 更新 — 拡大 extents・BB／配置・固定ポスト定数と収まりアサート

旧スタック基板前提（`uboard_*`／背高支持ポスト `tray_post_*`）を撤去し、拡大 extents・ブレッドボード・新配置・固定ポスト定数へ差し替える。旧アサートも新レイアウト用に置換する。

**Files:**
- Modify: `scad/params.scad`

**Interfaces:**
- Produces（params のグローバル。後続タスクが参照）:
  - extents: `ext_left=27`, `ext_right=84`, `ext_down=26`, `ext_up=120`
  - 配置: `pico_x=0`, `pico_y`（= `ext_up - pico_usb_gap - pico_l/2` = 83.5）, `pico_usb_gap=11`, `pedestal_outer`
  - BB: `bb_l=85.5`, `bb_w=54.5`, `bb_t=9.0`, `bb_clearance=0.5`, `bb_pocket_wt=2.0`, `bb_pocket_wall_h=5.0`, `bb_off_x`（44.25）, `bb_off_y`（73）, `pico_bb_gap=4`, `bb_ped_gap=2.35`
  - 固定: `tray_fix_d=6`, `tray_fix_h=6`, `tray_fix_gap=1`, `tray_fix_x_left=-20`, `tray_fix_x_right`（= `pocket_outer_right + tray_fix_gap + tray_fix_d/2` = 78）, `tray_fix_y_lo=40`, `tray_fix_y_hi=100`, `tray_fix_pts`（4点のリスト, ワールド座標）
  - トレイ床: `tray_t=2.4`, `tray_x0`, `tray_x1`, `tray_y0`, `tray_y1`（床矩形の四隅）
  - ネジ: `tray_screw_pilot=2.1`, `tray_screw_grip=5`, `tray_screw_clear=2.4`, `tray_head_d=4.2`, `tray_head_h=1.6`
  - Pico 爪: `pico_clip_w=4`, `pico_clip_t=2`, `pico_clip_hook=1.2`, `pico_clip_h`（= `pico_boss_h + pico_h` = 4）

- [ ] **Step 1: 旧 uboard／tray 定数と旧アサートを撤去し、新定数ブロックへ置換（GREEN を目指す一括編集）**

`scad/params.scad` の以下を編集する。

(a) `ext_*` ブロック（現 129-132 行）を置換:

```openscad
// --- Interior extents from the axis at origin (mm) ---
// -X/-Y はドアクリアランスの硬い制約で不変。BB を収めるため +X/+Y に拡大する。
ext_left  = 27;    // -X toward frame; <= clear_left
ext_right = 84;    // +X; BB ポケット右(74) + 固定ポスト + 壁を収める
ext_down  = 26;    // -Y toward handle; <= clear_down
ext_up    = 120;   // +Y free; BB ポケット上端(118.25) + 壁マージンを収める
```

(b) 「Pico / tray placement」ブロック（現 121-126 行）を置換:

```openscad
// --- Pico placement in the +Y free space ---
// Pico は +Y 天井壁寄り（長軸 Y, USB は +Y 壁から）。USB プラグの届き量を master
// 同等（Pico の USB 端 → +Y 内壁 = pico_usb_gap）に保つよう pico_y を導出する。
// +Y 内壁の y は center_y + inner_w/2 = ext_up（下の派生値と一致する恒等式）。
pico_usb_gap = 11;                            // Pico USB 端 → +Y 天井内壁（プラグ届き）
pico_x = 0;
pico_y = ext_up - pico_usb_gap - pico_l/2;    // 83.5
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;  // 25.4
```

(c) 「Universal board」ブロック（現 84-101 行）を、ブレッドボード＋配置ブロックへ置換:

```openscad
// --- Breadboard (half-size, 実測 85.5 x 54.5mm) ---
// 浅い囲い壁ポケットへ落とし込む。厚み bb_t は形状に使わない（壁高で位置決め）。
bb_l = 85.5;              // long side (along Y)
bb_w = 54.5;              // short side (along X)
bb_t = 9.0;              // 公称厚（実測予定。形状はこの値に依存しない）
bb_clearance     = 0.5;   // BB 外形 → ポケット内壁のすき間
bb_pocket_wt     = 2.0;   // ポケット壁厚
bb_pocket_wall_h = 5.0;   // ポケット壁高（BB 下部を囲って位置決め）
pico_bb_gap      = 4;     // Pico 右端 → ポケット外壁左のすき間（ジャンパ差込）
bb_ped_gap       = 2.35;  // ポケット外壁下端 → ペデスタル外周のすき間

// BB 中心（ワールド座標）。ポケット外壁の左端が Pico 右端から pico_bb_gap、
// 下端がペデスタル外周から bb_ped_gap だけ離れるように置く。
bb_off_x = pico_x + pico_w/2 + pico_bb_gap + bb_pocket_wt + bb_clearance + bb_w/2;  // 44.25
bb_off_y = pedestal_outer + bb_ped_gap + bb_pocket_wt + bb_clearance + bb_l/2;      // 73

// ポケット外形の端（アサート・床範囲・固定ポスト配置の基準）
pocket_outer_left   = bb_off_x - bb_w/2 - bb_clearance - bb_pocket_wt;  // 14.5
pocket_outer_right  = bb_off_x + bb_w/2 + bb_clearance + bb_pocket_wt;  // 74
pocket_outer_bottom = bb_off_y - bb_l/2 - bb_clearance - bb_pocket_wt;  // 27.75
pocket_outer_top    = bb_off_y + bb_l/2 + bb_clearance + bb_pocket_wt;  // 118.25
```

(d) 「Electronics carrier tray」ブロック（現 103-119 行）を置換:

```openscad
// --- Electronics carrier tray ---
tray_t           = 2.4;    // tray floor thickness
tray_screw_pilot = 2.1;    // M2 self-tap 下穴（tray_pilot_gauge 実測の実績値）
tray_screw_grip  = 5;      // self-tap 効き深さ
tray_screw_clear = 2.4;    // M2 shank clearance（本体床の貫通）
tray_head_d      = 4.2;    // M2 pan-head counterbore 径（本体床裏）
tray_head_h      = 1.6;    // counterbore 深さ

// トレイ固定ポスト（専用。本体裏から M2 セルフタップで留める）。BB ポケットと
// Pico を避け、左ストリップ2本＋ポケット右2本に配置する。
tray_fix_d       = 6;      // 固定ポスト外径
tray_fix_h       = 6;      // 固定ポスト高（ネジ効き tray_screw_grip=5 + マージン）
tray_fix_gap     = 1;      // ポケット外壁 → 右ポストのすき間
tray_fix_x_left  = -20;    // 左ポスト列（Pico 左 -10.5 と壁 -27 の間）
tray_fix_x_right = pocket_outer_right + tray_fix_gap + tray_fix_d/2;  // 78
tray_fix_y_lo    = 40;
tray_fix_y_hi    = 100;
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];

// トレイ床矩形（Pico・ポケット・固定ポストを内包。1mm マージン）。
tray_x0 = tray_fix_x_left  - tray_fix_d/2 - 1;   // -24
tray_x1 = tray_fix_x_right + tray_fix_d/2 + 1;   // 82
tray_y0 = pocket_outer_bottom - 0.75;            // 27
tray_y1 = pocket_outer_top    + 0.25;            // 118.5

// Pico コーナー爪（Pico 長辺を上から押さえる。ピンだけでは浮くため）
pico_clip_w    = 4;      // 爪幅
pico_clip_t    = 2;      // 爪の柱厚
pico_clip_hook = 1.2;    // Pico 上端を掴む張り出し
pico_clip_h    = pico_boss_h + pico_h;   // 爪の柱高（= Pico 上面）
```

(e) `--- Sanity / clearance checks ---` 節の後半、旧「Servo mount checks」の中の pedestal 系はそのまま残し、末尾の `--- Electronics tray checks ---` 節（現 174-182 行）を丸ごと置換:

```openscad
// --- Electronics tray / breadboard layout checks ---
// Pico が +Y 天井壁寄りでペデスタルをクリア
assert(pico_y - pico_l/2 > pedestal_outer, "Pico -Y 端がペデスタルに干渉");
assert(pico_y + pico_l/2 <= ext_up, "Pico +Y 端が内寸を超える");
// USB プラグ届き量が正（Pico USB 端 → +Y 内壁 = pico_usb_gap）
assert(pico_usb_gap > 0 && ext_up - (pico_y + pico_l/2) >= pico_usb_gap - 0.01, "USB プラグ届き量が不足");
// BB ポケットが内寸に収まる（+X/+Y 壁・ペデスタルをクリア）
assert(pocket_outer_right <= ext_right, "BB ポケット右端が +X 壁を超える");
assert(pocket_outer_top   <= ext_up,    "BB ポケット上端が +Y 壁を超える");
assert(pocket_outer_bottom >= pedestal_outer, "BB ポケット下端がペデスタルに干渉");
assert(pocket_outer_left  >= pico_x + pico_w/2 + pico_bb_gap - 0.001, "Pico↔BB ポケットのすき間不足");
// 固定ポストが BB・Pico・壁と干渉しない
assert(tray_fix_x_right - tray_fix_d/2 >= pocket_outer_right, "右固定ポストが BB ポケットに食い込む");
assert(tray_fix_x_right + tray_fix_d/2 <= ext_right, "右固定ポストが +X 壁を超える");
assert(tray_fix_x_left  + tray_fix_d/2 <= pico_x - pico_w/2, "左固定ポストが Pico に食い込む");
assert(tray_fix_x_left  - tray_fix_d/2 >= -ext_left, "左固定ポストが -X 壁を超える");
// トレイ床が内寸に収まる（ドロップイン可能）
assert(tray_x1 <= ext_right && tray_x0 >= -ext_left, "トレイ床 X が内寸を超える");
assert(tray_y1 <= ext_up && tray_y0 >= -ext_down, "トレイ床 Y が内寸を超える");
assert(tray_y0 >= pedestal_outer - 1, "トレイ床下端がペデスタルに寄りすぎ");
```

- [ ] **Step 2: レンダリングでアサート緑を確認（GREEN）**

Run: `./test/render.sh scad/params.scad` を直接は使わず、依存する smartlock で確認:
`nix develop -c openscad -o /tmp/pp.echo -D 'part="body"' scad/smartlock.scad 2>&1 | grep -Ei 'ERROR:|WARNING:' || echo CLEAN`
Expected: `CLEAN`（アサート全緑。ただし body.scad はまだ旧 `uboard_*`/`tray_mount_cuts` を参照して未定義変数警告が出る可能性 → その場合は Task 3 で解消。ここでは params 単体のアサートが `Assertion .* failed` を出さないことを確認する）。

補助: `nix develop -c openscad -o /tmp/pp.echo scad/params.scad 2>&1 | grep -Ei 'Assertion .* failed' && echo "ASSERT FAIL" || echo "ASSERTS OK"`
Expected: `ASSERTS OK`（params 単体はトップレベル形状が無く 2D/3D エラーは出るが、アサート失敗が無ければ良い）。

- [ ] **Step 3: コミット**

```bash
git add scad/params.scad
git commit -m "feat(scad): 筐体を +X/+Y へ拡大しブレッドボード配置・固定ポスト定数へ差し替え"
```

---

### Task 2: `scad/tray.scad` 全面書き換え — Pico ボス＋BB ポケット＋固定ポスト＋コーナー爪

トレイをワールド座標で再構築する。Pico 短ボス（`pico_w_mounts` 流用, 長軸 Y, 中心 `(pico_x, pico_y)`）、BB 浅い囲い壁ポケット、固定ポスト4本、Pico コーナー爪、USB 向きマーカーを持つ。

**Files:**
- Modify: `scad/tray.scad`（全面書き換え）

**Interfaces:**
- Consumes: params の配置・BB・固定・床・爪の全定数、`hardware.scad` の `pico_w_mounts()`。
- Produces: `module tray()`（ワールド座標。Task 3/5 が `translate([0,0,wall]) tray()` で置く）。

- [ ] **Step 1: tray.scad を書き換え**

`scad/tray.scad` を次の内容で置換:

```openscad
include <params.scad>
use <hardware.scad>

// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。
// Pico を +Y 天井壁寄りに短ボスで載せ、その右へブレッドボードを浅い囲い壁ポケット
// で落とし込む。四隅付近の固定ポスト4本で本体床へ M2 セルフタップ留め。Pico は
// 位置決めピン（ボス）＋コーナー爪で押さえる。床は translate([0,0,wall]) で本体床上へ。
module tray() {
  difference() {
    union() {
      // 床プレート（角丸, Pico・ポケット・固定ポストを内包）
      translate([(tray_x0 + tray_x1)/2, (tray_y0 + tray_y1)/2, tray_t/2])
        cube([tray_x1 - tray_x0, tray_y1 - tray_y0, tray_t], center = true);

      // Pico 短ボス＋位置決めピン（長軸 Y ＝ 90 度回転）を Pico 中心へ
      translate([pico_x, pico_y, tray_t])
        rotate([0, 0, 90]) pico_w_mounts();

      // BB 浅い囲い壁ポケット（外形 - 内形 を壁高ぶん押し出し）
      translate([bb_off_x, bb_off_y, tray_t])
        linear_extrude(height = bb_pocket_wall_h)
          difference() {
            square([bb_w + 2*(bb_clearance + bb_pocket_wt),
                    bb_l + 2*(bb_clearance + bb_pocket_wt)], center = true);
            square([bb_w + 2*bb_clearance, bb_l + 2*bb_clearance], center = true);
          }

      // 固定ポスト4本（床上に立てる）
      for (p = tray_fix_pts)
        translate([p[0], p[1], tray_t])
          cylinder(d = tray_fix_d, h = tray_fix_h);

      // Pico コーナー爪（Pico の -X/+X 長辺中央を上から掴む L 字）
      pico_clip(pico_x - pico_w/2, pico_y,  1);   // -X 側（フックは +X 向き）
      pico_clip(pico_x + pico_w/2, pico_y, -1);   // +X 側（フックは -X 向き）
    }

    // 固定ポスト下穴（トレイ裏 z0 から grip 深さ。床を貫通してポストへ効く）
    for (p = tray_fix_pts)
      translate([p[0], p[1], -0.1])
        cylinder(d = tray_screw_pilot, h = tray_screw_grip + 0.1);

    // USB 向きマーカー（Pico の +Y 端側の床に凹み矢印）
    tray_usb_marker();
  }
}

// Pico を上から押さえるコーナー爪。edge_x = Pico の長辺 x、dir = フックが伸びる向き
// (+1 で +X, -1 で -X)。柱は Pico 上面まで、先端に pico_clip_hook の張り出し。
module pico_clip(edge_x, edge_y, dir) {
  // 柱：Pico の外側すぐに立てる（fit_clearance ぶん離す）
  post_x = edge_x + dir * (fit_clearance + pico_clip_t/2);
  translate([post_x, edge_y, tray_t]) {
    // 縦柱
    translate([0, 0, pico_clip_h/2])
      cube([pico_clip_t, pico_clip_w, pico_clip_h], center = true);
    // 先端フック（Pico 上面高さで内側へ張り出す）
    translate([-dir * (pico_clip_t/2 + pico_clip_hook/2), 0, pico_clip_h])
      cube([pico_clip_hook + pico_clip_t, pico_clip_w, 1.2], center = true);
  }
}

// Pico の +Y（USB）端側を指す凹み矢印。USB 端はこちら＝本体 +Y 壁の開口に合わせる。
module tray_usb_marker() {
  depth = 0.6;
  translate([pico_x, pico_y + pico_l/2 - 6, tray_t - depth])
    linear_extrude(height = depth + 0.1)
      polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
```

- [ ] **Step 2: レンダリングで成功を確認（GREEN）**

Run: `./test/render.sh scad/tray.scad`
Expected: PASS（`Status: NoError`, `OK: /tmp/tray.stl`）。警告・エラー無し。

- [ ] **Step 3: 目視確認（クーポン不要, 全体を確認）**

Run: `nix develop -c openscad -o /tmp/tray.png --imgsize=900,900 --camera=30,60,10,60,0,20,320 scad/tray.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`。生成 PNG で「床・Pico ボス・BB 囲い壁・固定ポスト4本・爪2個」が想定位置にあることを目視（Pico が -X 寄り、BB 囲いが +X、固定ポストが四隅付近）。

- [ ] **Step 4: コミット**

```bash
git add scad/tray.scad
git commit -m "feat(scad): トレイを Pico+ブレッドボード横並び（囲い壁ポケット＋固定ポスト＋爪）へ全面書き換え"
```

---

### Task 3: 本体統合 — `hardware.scad` の `tray_mount_cuts()` と `body.scad`

トレイがワールド座標になったので、本体側の固定カット（クリアランス穴＋皿ザグリ）を `tray_fix_pts` に合わせ、`translate([pico_x, pico_y, 0])` を撤去してワールド座標で当てる。USB は `pico_y` 追従で自動、`usb_z` は不変。ペデスタル・サーボ・ノブ開口は不変。

**Files:**
- Modify: `scad/hardware.scad`（`tray_mount_cuts()` を `tray_fix_pts` ループへ書き換え。旧 `uboard_*` 参照を除去）
- Modify: `scad/body.scad`（`tray_mount_cuts()` 呼び出しをワールド座標へ）

**Interfaces:**
- Consumes: params の `tray_fix_pts`, `tray_screw_clear`, `tray_head_d`, `tray_head_h`, `wall`。
- Produces: `module tray_mount_cuts()`（本体床の4カット, ワールド座標, z0 基準）。

- [ ] **Step 1: hardware.scad の `tray_mount_cuts()` を書き換え**

`scad/hardware.scad` の `module tray_mount_cuts()`（現 43-54 行, `uboard_mount_span_*`/`uboard_mount_off_*` を使う版）を置換:

```openscad
// トレイを本体裏から留めるための床カット：シャンク貫通穴＋裏面の皿ザグリ。
// 位置はトレイ固定ポスト tray_fix_pts に一致（ワールド座標, 床の z 原点=0）。
module tray_mount_cuts() {
  for (p = tray_fix_pts)
    translate([p[0], p[1], 0]) {
      // シャンクは床を貫通
      translate([0, 0, -0.1])
        cylinder(d = tray_screw_clear, h = wall + 0.2);
      // 皿頭のザグリ（裏面 z=0 側から）
      translate([0, 0, -0.1])
        cylinder(d = tray_head_d, h = tray_head_h + 0.1);
    }
}
```

- [ ] **Step 2: body.scad の呼び出しをワールド座標へ**

`scad/body.scad` の tray 固定カット（現 41-42 行）を置換:

```openscad
    // tray fastening: clearance holes + head counterbores through the floor
    // (tray は本体裏からネジ留め。位置はワールド座標の tray_fix_pts)
    tray_mount_cuts();
```

（`translate([pico_x, pico_y, 0])` を外す。USB カット・ペデスタル・サーボ・ノブ開口はそのまま。`usb_z` は `wall + tray_t + pico_boss_h + pico_h + usb_connector_h/2` で不変。）

- [ ] **Step 3: レンダリングで成功を確認（GREEN）**

Run: `nix develop -c openscad -D 'part="body"' -o /tmp/body.stl scad/smartlock.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`（未定義変数警告なし・アサート緑）。

Run: `./test/render.sh scad/smartlock.scad`
Expected: PASS（デフォルト assembly が警告なしでレンダリング）。

- [ ] **Step 4: コミット**

```bash
git add scad/hardware.scad scad/body.scad
git commit -m "feat(scad): 本体トレイ固定カットを tray_fix_pts のワールド座標へ差し替え"
```

---

### Task 4: `scad/layout_check.scad` — 可視化を Pico＋ブレッドボード横並びへ更新

旧 uboard 表示（スタック基板）を BB 表示へ差し替え、`pin_header_h`/`uboard_*` 依存を除去する。Pico 位置は params の `pico_y` 追従で自動更新される。

**Files:**
- Modify: `scad/layout_check.scad`

**Interfaces:**
- Consumes: params の `bb_off_x/bb_off_y/bb_w/bb_l/bb_pocket_wall_h`, `pico_x/pico_y`, `tray_t/pico_floor_z`。

- [ ] **Step 1: uboard 依存の派生値を BB へ差し替え**

`scad/layout_check.scad` の派生値（現 20 行）を置換:

```openscad
// BB は Pico と同じトレイ床上に載る（囲い壁ポケット底）
bb_z = pico_floor_z;
```

- [ ] **Step 2: `part_uboard()` を `part_breadboard()` へ差し替え**

`module part_uboard()`（現 84-87 行）を置換:

```openscad
module part_breadboard() {
  // ブレッドボード本体
  translate([bb_off_x, bb_off_y, bb_z + bb_t/2])
    cube([bb_w, bb_l, bb_t], center=true);
}
```

- [ ] **Step 3: 呼び出しとラベルを差し替え**

`front_view()` 内の `wf_front() part_uboard();`（現 216 行）を `wf_front() part_breadboard();` へ。
同 `leader(uboard_w/2, ...)` のラベル（現 232-233 行）を置換:

```openscad
  leader(bb_off_x + bb_w/2, bb_off_y, lx2, bb_off_y + 8,
         str("BB ", bb_l, "x", bb_w));
```

`side_view()` 内の `wf_side() part_uboard();`（現 273 行）を `wf_side() part_breadboard();` へ。
同 `leader(pico_y, uboard_z + uboard_t, ...)`（現 291-292 行）を置換:

```openscad
  leader(bb_off_y, bb_z + bb_t, lx_r, bb_z + bb_t + 8,
         str("BB ", bb_l, "x", bb_w));
```

- [ ] **Step 4: SVG レンダリングで成功を確認（GREEN）**

Run: `nix develop -c openscad -o /tmp/layout_check.svg scad/layout_check.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`（`Top level object is a 2D object` の情報行のみ。未定義変数 `uboard_*`/`pin_header_h`/`uboard_z` の警告が消える）。

`/tmp/layout_check.svg` を開き、正面図で Pico が -X 寄り・BB が +X・両者が横並びで +Y 側に載り、拡大した body 外形に収まっていることを目視。

- [ ] **Step 5: コミット**

```bash
git add scad/layout_check.scad
git commit -m "docs(scad): layout_check を Pico+ブレッドボード横並びへ更新"
```

---

### Task 5: ビルド接続 — `smartlock.scad`・`tray_pilot_gauge.scad`・`build.sh` 全体確認

トレイのワールド座標化に合わせて `smartlock.scad` の配置・クーポンを直し、`tray_pilot_gauge.scad` を固定ポスト定数へ向け、`build.sh` を通す。

**Files:**
- Modify: `scad/smartlock.scad`（`asm_tray`・フル assembly の `translate([pico_x,pico_y,...])` を撤去、`tray_coupon` を固定ポストクーポンへ）
- Modify: `scad/tray_pilot_gauge.scad`（`tray_post_d/tray_post_h` → `tray_fix_d/tray_fix_h`）
- Test: `./build.sh`

**Interfaces:**
- Consumes: `tray()`（Task 2）, params の `tray_fix_*`, `tray_t`, `exp`（smartlock 内）。

- [ ] **Step 1: smartlock.scad の tray 配置をワールド座標へ**

`scad/smartlock.scad` の `asm_tray` 分岐（現 63-65 行）を置換:

```openscad
else if (part == "asm_tray")
  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();
```

フル assembly の tray（現 79-80 行）を置換:

```openscad
  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();
```

`tray_coupon` 分岐（現 21-26 行）を、固定ポスト＋BB ポケット隅を切り出すクーポンへ置換:

```openscad
// トレイの +X/+Y 隅（右固定ポスト＋BB ポケット角）を切り出したクーポン
// （固定ポストのネジ効き・ポケット壁の勘合確認用）
else if (part == "tray_coupon")
  intersection() {
    tray();
    translate([pocket_outer_right - 8, pocket_outer_top - 40, -1])
      cube([tray_fix_x_right + tray_fix_d/2 + 3 - (pocket_outer_right - 8),
            40 + 3, tray_fix_h + tray_t + bb_pocket_wall_h + 3]);
  }
```

- [ ] **Step 2: tray_pilot_gauge.scad を固定ポスト定数へ**

`scad/tray_pilot_gauge.scad` の `cylinder(d = tray_post_d, h = base_t + tray_post_h);`（現 39 行）と直後の下穴（現 40-41 行）を置換:

```openscad
      cylinder(d = tray_fix_d, h = base_t + tray_fix_h);
      translate([0, 0, base_t + tray_fix_h - tray_screw_grip])
        cylinder(d = gauge_ds[i], h = tray_screw_grip + 0.1);
```

冒頭コメント（現 2-3 行の `tray_post_d 径・tray_post_h 高さ`）も `tray_fix_d 径・tray_fix_h 高さ` へ文言修正。

- [ ] **Step 3: 各部品とクーポンの成功を確認（GREEN）**

Run: `nix develop -c openscad -D 'part="tray_coupon"' -o /tmp/tc.stl scad/smartlock.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`。

Run: `./test/render.sh scad/tray_pilot_gauge.scad`
Expected: PASS。

- [ ] **Step 4: 全体ビルド（GREEN）**

Run: `./build.sh`
Expected: `All parts built to build/`（body/lid/socket/tray/asm_* と gauge 全部が警告・エラー無しでビルド）。

- [ ] **Step 5: コミット**

```bash
git add scad/smartlock.scad scad/tray_pilot_gauge.scad
git commit -m "feat(scad): smartlock/tray_pilot_gauge をワールド座標トレイと固定ポストへ整合"
```

---

## Self-Review

**Spec coverage（`docs/superpowers/specs/2026-07-12-breadboard-tray-enclosure-design.md` 対応）:**
- 筐体拡大（`ext_right`/`ext_up`）→ Task 1。−X/−Y 不変・クリアランスアサート → Task 1（実現 extent 29.4/28.4 ≤ 50/65）。
- `uboard_*`/`tray_post_*` 撤去、BB・配置・固定新設 → Task 1。
- Pico 据え置き（+Y 壁寄せ, USB +Y 壁, `usb_z` 不変）→ Task 1（`pico_y` 導出）＋ Task 3（USB）。※spec 本文の `pico_y≈63.4` は旧値。ユーザー決定で +Y 壁寄せ（`pico_y=83.5`, USB 隙間 11mm 保持）を採用。
- BB 浅い囲い壁ポケット → Task 2。Pico 位置決めピン継続＋コーナー爪 → Task 2。トレイ→本体 底面 M2 セルフタップ・固定専用ポスト再配置 → Task 1/2/3。
- `tray.scad` 全面書き換え → Task 2。`body.scad` の固定カット位置 → Task 3。`layout_check.scad` 更新 → Task 4。
- `lid.scad`/`mount_plate.scad` は body 派生で自動追従（LED/ボタン穴は `pico_y` 追従, mount_plate はペデスタル不変）→ 明示タスク不要だが下記「要レビュー」。
- 検証（render.sh 全 part 緑・assert 緑・build.sh で STL 生成）→ Task 5。

**Placeholder scan:** TBD/TODO 無し。各コードステップは実コードを記載。

**Type/naming consistency:** `tray()`, `pico_clip()`, `tray_usb_marker()`, `tray_mount_cuts()`, `pico_w_mounts()`, `part_breadboard()` と `bb_*`/`pocket_outer_*`/`tray_fix_*`/`tray_x0..y1`/`pico_clip_*`/`pico_usb_gap` は全タスクで一貫。トレイはワールド座標に統一し、body/smartlock の `translate([pico_x,pico_y,…])` を撤去。

**要レビュー（実装者・PR レビュー時）:**
- **LED/ボタン穴の位置**: 現状 lid の穴は `pico_y` 追従で Pico 上（x=0, y=`pico_y`±8）に開く。ブレッドボード実装では LED/ボタンは BB 上に挿す想定のため、物理位置と穴位置がずれる可能性。spec でも lid は「要レビュー」。本 PR では穴位置を Pico 追従のまま置き、LED/ボタンの BB 上配置と穴の整合は別課題（配置が place&route 依存で未確定のため）。PR 本文で明示する。
- **Pico コーナー爪**の食いつき量（`pico_clip_hook`/`fit_clearance`）は印刷後の勘合で要調整。`tray_coupon` や単体印刷で現物合わせ。
- **+X 方向の実寸**（body_l ≈ 115.8）: ドア現物で +X（ヒンジ側）に本当に余裕があるか最終確認（spec の未確定事項）。
- **`bb_t`** 実測とポケット壁高 `bb_pocket_wall_h` の現物合わせ。
- `lid.scad`/`mount_plate.scad` は拡大後にレンダリング＆干渉を目視（Task 5 の `./build.sh` で lid が警告なくビルドされることは確認済み）。

## Execution Handoff

実装完了後、新 issue（workstream B）を立て、本ブランチから master への PR を出す（A の #70 とは別 PR）。#70 は方針転換の傘 issue として扱う。issue/PR 作成は外部発信のため、実行時にユーザー確認の上で行う。
