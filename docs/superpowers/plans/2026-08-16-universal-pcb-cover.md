# ユニバーサル基板化＋全体カバー 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ブレッドボード前提の筐体を、ユニバーサル基板 P-03229 マウントのトレイと、全部品を覆う一体スロープ型カバーへ作り替える。

**Architecture:** 座標の正は `enclosure/models/params.scad` の 1 ファイル。ここに置いた値と assert が全部品の形状と整合性検証を駆動する。プレート（`body.scad`）・トレイ（`tray.scad`）・カバー（`cover.scad`）は params を読むだけで、寸法をハードコードしない。ペデスタルとソケットは無改造。

**Tech Stack:** OpenSCAD（Manifold バックエンド）、bun（ビルド／レンダリング／干渉チェックのスクリプト）、tscircuit（回路 ERC）。ツールは `nix develop -c` 経由で呼ぶ。

**Spec:** `docs/superpowers/specs/2026-08-16-universal-pcb-cover-design.md`

## Global Constraints

- OpenSCAD のコマンドは必ず `nix develop -c` を前置する。この開発機の非対話シェルには `openscad` / `bun` が PATH に無い。
- 座標系: 原点 = サムターン軸（ロゼット中心）、z=0 = ドア面。既存の全モデルがこの系。
- 単位はすべて mm。角度は度。
- ネジは **M2 のみ**。下穴 `tray_screw_pilot` = 2.1、貫通 `tray_screw_clear` = 2.4、頭ザグリ `tray_head_d` = 4.2。M3 を新規に持ち込まない。
- ボス／スリーブは `hardware.scad` の `m2_boss()` / `m2_sleeve_solid()` / `m2_sleeve_cuts()` を必ず流用する。自前で書き起こさない。
- `pedestal.scad` と `socket.scad` は変更しない。`pedestal_top_z` = 48.4 を動かさない。
- 派生物（`enclosure/build/`、`*.stl`）はコミットしない。
- 各タスクの完了条件に「`nix develop -c bun enclosure/scripts/render.ts <対象>` が WARNING / ERROR なしで通ること」を含む。`render.ts` は WARNING でも失敗扱いになる。
- テストの書き方は既存に合わせる。`*_test.scad` は「assert を並べてモジュールを1回インスタンス化し、最後に `echo("<name> ok")`」の形。

## Preflight rulings（実行前のスコープ照合で確定した修正）

計画作成後の照合で 2 件の欠陥を見つけ、以下のとおり確定した。台帳
`.superpowers/sdd/2026-08-16-universal-pcb-cover/progress.md` に根拠を記録してある。

- **Ruling 1**: トレイ固定スリーブがペデスタル固定スリーブ（45°/135°、中心 ±21.21, 21.21）と
  中心間 4.36mm まで接近して食い込む。ペデスタル無改造の制約があるので、基板とトレイ固定点を
  +Y へずらして避ける。プレートは Y 方向に 4.7mm 伸びる（123.8 → 128.5）。
- **Ruling 2**: プレートの横桟がカバー側壁の真下を貫く。横桟を全廃し、剛性はカバーに担わせる。

以下の本文はこの 2 件を反映済み。spec 側の数値（基板中心 (9, 53.5) 等）より **この計画の数値が優先** する。

## 確定値（spec からの写し）

| 名前 | 値 | 由来 |
| --- | --- | --- |
| 基板 P-03229 | 72(X) × 47(Y) × 1.6、穴 φ3.2 ピッチ 66×41 | docs/parts-selection.md |
| 基板中心（世界） | (9, 58.1) | −Y 端(34.6) が -Y 側トレイ固定スリーブの上端(33.9) を 0.7 かわす |
| 支柱 | 高さ 5、外径 5 | 基板裏のハンダ足逃げ |
| トレイ固定 4 点 | (−22, 30) (40, 30) (−22, 86.2) (40, 86.2) | 基板の ±Y 側。±X 側だとドア枠に寄る。-Y 側の y=30 は ped_fix_pts(±21.21, 21.21) から 8.8mm 離す下限（Ruling 1） |
| カバー内面 | X −28.7〜46.5、Y −28.7〜91.2 | 受けカーブ／トレイ + すきま 1.0 |
| カバー壁 | 2.0 | |
| カバー内面天井 / 外面天面 | 72.9 / 75.73 | サーボ上端 70.9 + 2.0、斜面の壁厚確保に ×√2 |
| 勾配開始 y | 28.7 | 受けカーブ 27.7 + すきま 1.0 |
| プレート外形 | X −33.0〜50.8、Y −33.0〜95.5（83.8 × 128.5） | カバー裾外面 + リブ幅 2 + 嵌合 0.3 |
| スイッチ PS21B-1 | ネジ部 φ11.5、取付穴 φ12.0、フランジ φ18.7、奥行き 26 | 実測とメーカー図面 |
| スイッチ取付点 | (−1, 60) | 奥行き 26 を逃がせる位置 |
| LED 窓 | (−15, 79.1)、φ6 | `[pcb_off_x - 24, pcb_off_y + 21]` |

---

### Task 1: params の刷新とトレイの基板マウント化

`params.scad` にレイアウトの正を書き、`tray.scad` をそれに合わせて作り替える。両者は BB 系パラメータで結合しているので同時に切り替える。`body.scad` は `body_l` / `body_w` / `center_x` / `center_y` / `tray_fix_pts` を読むだけなので、コード変更なしでプレートが縮み固定ボスが移動する。

**Files:**
- Modify: `enclosure/models/params.scad`
- Modify: `enclosure/models/tray.scad`
- Modify: `enclosure/models/hardware.scad`（`pcb_standoff()` を追加）
- Test: `enclosure/models/params_test.scad`, `enclosure/models/tray_test.scad`（新規）

**Interfaces:**
- Produces: `pcb_off_x` `pcb_off_y` `pcb_l` `pcb_w` `pcb_t` `pcb_hole_pts` `pcb_top_z` `pcb_stack_pico` `pcb_stack_usb` `pcb_stack_tall` `pcb_standoff_h` `pcb_standoff_d` `pcb_screw_grip` / `tray_x0` `tray_x1` `tray_y0` `tray_y1` `tray_ped_notch_r` `tray_fix_pts` / `plate_x0` `plate_x1` `plate_y0` `plate_y1` `body_l` `body_w` `center_x` `center_y` / `servo_top_z` / モジュール `pcb_standoff()`
- Consumes: 既存の `ped_curb_ro` `wall` `tray_t` `tray_sleeve_od` `tray_screw_pilot` `pedestal_top_z` `servo_body_h`

- [ ] **Step 1: 失敗するテストを書く**

`enclosure/models/tray_test.scad` を新規作成する。

```openscad
include <params.scad>
use <tray.scad>
// 基板が支柱・床・固定スリーブのいずれとも整合すること（値は params の assert が担保）
assert(len(pcb_hole_pts) == 4, "基板の支柱は四隅 4 本");
assert(len(tray_fix_pts) == 4, "トレイ固定点は 4 点");
tray();
echo("tray_test ok");
```

`enclosure/models/params_test.scad` を次の内容で置き換える。

```openscad
include <params.scad>
assert(body_l > 0 && body_w > 0, "positive plate dims");
assert(ext_left <= clear_left, "left extent within door clearance");
assert(ext_down <= clear_down, "down extent within handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
// 基板レイアウト
assert(pcb_off_y - pcb_w/2 >= ped_curb_ro + 1, "基板 -Y 端が受けカーブに近すぎる");
assert(abs(pcb_top_z - (wall + tray_t + pcb_standoff_h + pcb_t)) < 1e-6,
       "基板上面の Z が積み上げと一致");
echo("params_test ok");
sphere(0.01, $fn = 3);
```

- [ ] **Step 2: テストが落ちることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/params_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/tray_test.scad
```

期待: どちらも失敗。`params_test` は `pcb_off_y` などが未定義（`WARNING: Ignoring unknown variable`）、`tray_test` は `pcb_hole_pts` が未定義。

- [ ] **Step 3: params.scad を書き換える**

`params.scad` の以下を **削除** する。

- `pico_hole_dx` / `pico_hole_dy` / `pico_pin_drop` / `pico_boss_d` / `pico_boss_h` / `pico_screw_pilot` / `pico_screw_grip` は **残す**（`hardware.scad` の `pico_w_mounts()` がまだ参照している。Task 5 でまとめて消す）
- `pico_usb_gap` / `pico_x` / `pico_y`
- `ext_left` / `ext_right` / `ext_down` / `ext_up` の定義（後述の新定義で置き換え）
- `bb_l` `bb_w` `bb_t` `bb_clearance` `bb_pocket_wt` `bb_pocket_wall_h` `bb_rail_hook` `bb_rail_lip_h` `pico_bb_gap` `bb_ped_gap` `bb_off_x` `bb_off_y` `bb_ext_farx` `pocket_inner_left` `pocket_inner_right` `pocket_inner_bottom` `pocket_inner_top` `pocket_outer_left` `pocket_outer_right` `pocket_outer_bottom` `pocket_outer_top`
- `tray_fix_gap` / `tray_fix_x_left` / `tray_fix_x_right` / `tray_fix_y_lo` / `tray_fix_y_hi` / `tray_fix_pts` / `tray_x0` / `tray_x1` / `tray_y0` / `tray_y1` の定義（新定義で置き換え）
- assert のうち以下: `realized left extent...` `realized down extent...` `Pico -Y 端がペデスタルに干渉` `Pico +Y 端が内寸を超える` `スタンドオフ高が下ピン突出を逃がせない` `ネジ下穴 grip がスタンドオフ高を超える` `スタンドオフ肉厚が下穴に対して薄すぎる` `BB ポケット右端...` `BB ポケット上端...` `BB ポケット下端...` `BB レールリップ...` `Pico↔BB ポケットのすき間不足` `右スリーブが BB ポケットに食い込む` `右スリーブがプレート端(+X)を超える` `左スリーブが Pico に食い込む` `左スリーブがプレート端(-X)を超える` `トレイ床 X が内寸を超える` `トレイ床 Y が内寸を超える` `トレイ床下端がペデスタルに寄りすぎ` `受けカーブがトレイ床に近すぎる` `横桟がトレイ床に食い込む` `横桟がペデスタルスリーブに食い込む`
- **残す assert**: `ped_fix_r*sin(45) + tray_sleeve_od/2 <= tray_y0`（ペデスタルスリーブ ⇔ トレイ床。新 tray_y0 = 26.0 で 25.11 ≤ 26.0 と通る。この assert が Ruling 1 の欠陥を検出した）

`ped_curb_ro` の定義ブロックの直後（BB 系があった位置）に以下を **追加** する。

```openscad
// --- ユニバーサル基板 P-03229（秋月 C タイプ, 片面めっき） ---
// 横置き（長辺 72 を X 方向）。Pico はメスソケットで基板の上に重なるので、
// 電子部品エリアのフットプリントはこの 1 枚ぶんで足りる。
pcb_l = 72;      // X 方向（長辺）
pcb_w = 47;      // Y 方向（短辺）
pcb_t = 1.6;
pcb_hole_d  = 3.2;   // 既製マウント穴（M2 は頭で押さえる。ネジ山は効かない）
pcb_hole_dx = 66;    // 長辺方向の穴ピッチ
pcb_hole_dy = 41;    // 短辺方向の穴ピッチ
// 基板 -Y 端(34.6) は -Y 側トレイ固定スリーブの上端(30+3.9) を 0.7 かわす位置。
// その固定点自体がペデスタル固定スリーブ(45°/135°)から逃げた結果ここまで上がっている。
pcb_ped_gap = 6.9;   // 基板 -Y 端 ⇔ 受けカーブ外周
pcb_off_y   = ped_curb_ro + pcb_ped_gap + pcb_w/2;   // 58.1
// 基板 -X 端を受けカーブ外周とほぼ同じ x（-27）に揃え、プレート -X 端を最小にする
pcb_off_x   = -27 + pcb_l/2;                          // 9
pcb_hole_pts = [for (sx = [-1, 1], sy = [-1, 1])
                 [pcb_off_x + sx*pcb_hole_dx/2, pcb_off_y + sy*pcb_hole_dy/2]];

pcb_standoff_h = 5;    // 支柱高（基板裏のハンダ足逃げ）
pcb_standoff_d = 5;    // 支柱外径（tray_boss_d に倣う）
pcb_screw_grip = 4;    // セルフタップ効き深さ（支柱高より浅く）

// 基板上の Z（積み上げ）
pcb_z0    = wall + tray_t + pcb_standoff_h;   // 基板下面 9.8
pcb_top_z = pcb_z0 + pcb_t;                   // 基板上面 11.4
pcb_stack_pico = 9.5;    // 基板上面 → Pico 上面（メスソケット 8.5 + Pico 1.0）
pcb_stack_usb  = 12.0;   // 基板上面 → USB コネクタ上端
pcb_stack_tall = 16.0;   // 基板上面 → 最高部品（TO-220 立て）上端
pcb_stack_low  = 3.0;    // 基板上面 → 低背部品（抵抗・ダイオード）上端

// --- Electronics carrier tray ---
// （tray_t / tray_screw_* / tray_boss_* / tray_sleeve_* の既存定義はそのまま）
tray_fix_x_left  = -22;
tray_fix_x_right = 40;
// -Y 側は ped_fix_pts の 45°/135°（±21.21, 21.21）から中心間 8.8mm 離れる下限。
// 両方ともスリーブ外径 7.8 なので 8.3 が最小、余裕を見て y=30。
tray_fix_y_lo    = 30;     // 基板 -Y 端(34.6) の下
tray_fix_y_hi    = 86.2;   // 基板 +Y 端(81.6) の上
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];
tray_x0 = pcb_off_x - pcb_l/2 - 0.5;                  // -27.5
tray_x1 = pcb_off_x + pcb_l/2 + 0.5;                  // 45.5
tray_y0 = tray_fix_y_lo - tray_sleeve_od/2 - 0.1;     // 26.0
tray_y1 = tray_fix_y_hi + tray_sleeve_od/2 + 0.1;     // 90.2
tray_ped_notch_r = ped_curb_ro + 1.3;                 // 29。床が受けカーブをまたぐ逃げ

// --- サーボ上端（カバー天井の根拠） ---
servo_top_z = pedestal_top_z + servo_body_h;   // 70.9
```

続けて、プレート外形の定義を（旧 `body_l` / `body_w` / `center_x` / `center_y` の位置に）置き換える。カバー系は Task 3 で足すので、ここでは数値を直に書かずカバー内面から導けるよう **カバーの内面・壁だけ先に定義** する。

```openscad
// --- カバー内面（プレート外形の起点。カバー本体は Task 3 の cover.scad） ---
cover_wall  = 2.0;
cover_clear = 1.0;    // 内面 ⇔ 中身のすきま
cover_x0 = -(ped_curb_ro + cover_clear);   // -28.7（受けカーブが支配）
cover_x1 = tray_x1 + cover_clear;          // 46.5
cover_y0 = -(ped_curb_ro + cover_clear);   // -28.7
cover_y1 = tray_y1 + cover_clear;          // 91.2

// --- プレート外形 ---
// カバー裾の外面を外周リブの内面で受ける。プレート端 = 裾外面 + リブ幅 + 嵌合すきま。
cover_lip_fit = 0.3;
plate_margin  = plate_rib_w + cover_lip_fit;   // 2.3
plate_x0 = cover_x0 - cover_wall - plate_margin;   // -33.0
plate_x1 = cover_x1 + cover_wall + plate_margin;   //  50.8
plate_y0 = cover_y0 - cover_wall - plate_margin;   // -33.0
plate_y1 = cover_y1 + cover_wall + plate_margin;   //  95.5
body_l   = plate_x1 - plate_x0;        // 83.8
body_w   = plate_y1 - plate_y0;        // 128.5
center_x = (plate_x0 + plate_x1)/2;    // 8.9
center_y = (plate_y0 + plate_y1)/2;    // 31.25
// 旧 ext_* は「軸原点から内寸の端まで」の意味。既存 assert と互換のため導出で残す。
ext_left  = -plate_x0 - wall;
ext_right =  plate_x1 - wall;
ext_down  = -plate_y0 - wall;
ext_up    =  plate_y1 - wall;
```

`plate_rib_w` は現状ファイル後半で定義されているので、この位置より前へ移動させる（`plate_rib_h` / `plate_rib_ys` も一緒に移す）。

`plate_rib_ys` は **`[]` に変更して横桟を全廃する**（Ruling 2）。横桟はプレート全幅（`square([body_l, plate_rib_w])`）に走るのでカバーの −X / +X 側壁の真下を貫いてしまい、カバーが座らない。剛性は四隅で M2 留めされたカバーが肩代わりする。これに伴い `max(plate_rib_ys)` を参照する 2 本の assert（`横桟がトレイ床に食い込む` / `横桟がペデスタルスリーブに食い込む`）も削除する。空リストに `max()` を適用すると undef になり assert が壊れるため、残すことはできない。

最後に、削除した assert の代わりに以下を追加する。

```openscad
// --- 基板・トレイのレイアウトチェック ---
assert(pcb_off_y - pcb_w/2 >= ped_curb_ro + 1, "基板 -Y 端が受けカーブに近すぎる");
assert(pcb_off_x - pcb_l/2 >= cover_x0, "基板 -X 端がカバー内面を超える");
assert(pcb_off_x + pcb_l/2 <= cover_x1, "基板 +X 端がカバー内面を超える");
assert(pcb_screw_grip < pcb_standoff_h, "支柱の下穴 grip が支柱高を超える");
assert(pcb_standoff_d > tray_screw_pilot + 1.6, "支柱の肉厚が下穴に対して薄すぎる");
assert(tray_x0 <= pcb_off_x - pcb_l/2 && tray_x1 >= pcb_off_x + pcb_l/2,
       "トレイ床が基板を支えきれない");
assert(tray_fix_y_lo + tray_sleeve_od/2 <= pcb_off_y - pcb_w/2, "-Y 固定スリーブが基板に食い込む");
assert(tray_fix_y_hi - tray_sleeve_od/2 >= pcb_off_y + pcb_w/2, "+Y 固定スリーブが基板に食い込む");
assert(min([for (p = tray_fix_pts) norm(p)]) >= ped_curb_ro + tray_sleeve_od/2 + 0.5,
       "固定スリーブが受けカーブに食い込む");
// トレイ固定スリーブとペデスタル固定スリーブの共倒れガード。
// 旧レイアウトで実際に 4.36mm まで接近して食い込んでいたので必ず入れる。
assert(min([for (t = tray_fix_pts, q = ped_fix_pts) norm(t - q)]) >= tray_sleeve_od + 0.5,
       "トレイ固定スリーブがペデスタル固定スリーブに食い込む");
assert(tray_ped_notch_r >= ped_curb_ro + ped_curb_tray_gap, "トレイ床の逃げが受けカーブに近すぎる");
assert(tray_y0 <= tray_fix_y_lo - tray_sleeve_od/2, "トレイ床 -Y 端が固定スリーブを覆えない");
assert(tray_y1 >= tray_fix_y_hi + tray_sleeve_od/2, "トレイ床 +Y 端が固定スリーブを覆えない");
assert(tray_x1 <= cover_x1 && tray_x0 >= cover_x0, "トレイ床 X がカバー内面を超える");
assert(tray_y1 <= cover_y1 && tray_y0 >= cover_y0, "トレイ床 Y がカバー内面を超える");
// --- プレートのドアクリアランス ---
assert(-plate_x0 <= clear_left, "プレート -X 端がドアクリアランスを超える");
assert(-plate_y0 <= clear_down, "プレート -Y 端がドアクリアランスを超える");
```

- [ ] **Step 4: hardware.scad に基板支柱を追加する**

`hardware.scad` の `pico_w_mounts()` の直後に追加する。

```openscad
// ユニバーサル基板 P-03229 の支柱 1 本（原点基準・呼び出し側で translate）。
// 基板を pcb_standoff_h 浮かせて裏のハンダ足を床から逃がし、上から M2 セルフタップで
// 留める。基板穴 φ3.2 に対しネジ山は効かないので、頭（tray_head_d）が押さえる。
module pcb_standoff() {
  difference() {
    cylinder(d = pcb_standoff_d, h = pcb_standoff_h);
    translate([0, 0, pcb_standoff_h - pcb_screw_grip])
      cylinder(d = tray_screw_pilot, h = pcb_screw_grip + 0.1);
  }
}
```

- [ ] **Step 5: tray.scad を作り替える**

`tray.scad` の全体を次で置き換える。

```openscad
include <params.scad>
use <hardware.scad>

// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。ユニバーサル基板 P-03229 を
// 四隅の支柱に載せ、四隅付近の固定スリーブが本体床のボスに被さって天面（内側）から
// M2 セルフタップで留まる。床の原点まわりはペデスタル受けカーブを丸く欠いてまたぐ。
module tray() {
  difference() {
    union() {
      // 床プレート（受けカーブの逃げ付き）
      linear_extrude(height = tray_t)
        difference() {
          translate([(tray_x0 + tray_x1)/2, (tray_y0 + tray_y1)/2])
            square([tray_x1 - tray_x0, tray_y1 - tray_y0], center = true);
          circle(r = tray_ped_notch_r);
        }

      // 基板支柱 4 本
      for (p = pcb_hole_pts)
        translate([p[0], p[1], tray_t]) pcb_standoff();

      // 固定スリーブ solid（内側は下の difference で彫る）。床下面 z=0 から立てる。
      for (p = tray_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }

    // 固定スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ）
    for (p = tray_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();

    // USB 向きマーカー（基板の +X 端側の床に凹み矢印）
    tray_usb_marker();
  }
}

// Pico の USB が向く +X 側を指す凹み矢印。基板を載せる向きの目印。
module tray_usb_marker() {
  depth = 0.6;
  translate([pcb_off_x + pcb_l/2 - 6, pcb_off_y, tray_t - depth])
    rotate([0, 0, -90])
      linear_extrude(height = depth + 0.1)
        polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
```

- [ ] **Step 6: テストが通ることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/params_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/tray_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/body_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/pedestal_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/socket_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/hardware_test.scad
```

期待: 6 本すべて WARNING / ERROR なしで終了。`body_test` は `body.scad` を触っていないのに縮んだプレートが出る（params 追従の確認）。

- [ ] **Step 7: 干渉チェックを通す**

```bash
nix develop -c bun enclosure/scripts/clash.ts
```

期待: `OK: no interference (empty intersection)`。もし失敗したら、トレイ床の受けカーブ逃げ（`tray_ped_notch_r`）か固定スリーブの位置を疑う。

- [ ] **Step 8: コミット**

```bash
git add enclosure/models/params.scad enclosure/models/tray.scad \
        enclosure/models/hardware.scad enclosure/models/params_test.scad \
        enclosure/models/tray_test.scad
git commit -m "feat(enclosure): トレイをユニバーサル基板 P-03229 マウントへ作り替え

BB ポケットと Pico スタンドオフを廃止し、既製穴ピッチ 66x41 の支柱 4 本へ。
プレート外形はカバー内面から導出する形に変え、116x153 から 83.8x123.8 へ縮小。"
```

---

### Task 2: プレートへカバー固定ラグとボスを追加

**Files:**
- Modify: `enclosure/models/params.scad`（ラグ・耳の座標）
- Modify: `enclosure/models/hardware.scad`（`cover_mount_bosses()`）
- Modify: `enclosure/models/body.scad`（輪郭にラグ、リブに逃げ、ボスの union）
- Test: `enclosure/models/body_test.scad`

**Interfaces:**
- Consumes: Task 1 の `cover_x0/x1/y0/y1` `cover_wall` `plate_x0..y1` `plate_rib_w`
- Produces: `cover_ear_pts`（4 点、Task 3 のカバー耳が同じ座標を使う）、`plate_lug_d`、モジュール `cover_mount_bosses()`

- [ ] **Step 1: 失敗するテストを書く**

`body_test.scad` を次で置き換える。

```openscad
include <params.scad>
use <body.scad>
// カバー固定は 4 点。ラグはドアクリアランスの内側に収まる
assert(len(cover_ear_pts) == 4, "カバー固定点は 4 点");
lug_x = max([for (p = cover_ear_pts) -p[0]]) + plate_lug_d/2;
lug_y = max([for (p = cover_ear_pts) -p[1]]) + plate_lug_d/2;
assert(lug_x <= clear_left, "固定ラグが -X のドアクリアランスを超える");
assert(lug_y <= clear_down, "固定ラグが -Y のドアクリアランスを超える");
body();
echo("body_test ok");
```

- [ ] **Step 2: テストが落ちることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/body_test.scad
```

期待: `cover_ear_pts` が未定義で失敗。

- [ ] **Step 3: params.scad に耳とラグを足す**

プレート外形ブロックの直後に追加する。

```openscad
// カバー固定の耳／ラグ。裾の外角から対角方向へ各軸 cover_ear_off ずらし、
// 円（tray_sleeve_od）が裾の角にちょうど接するようにする。
cover_ear_off = 2.8;
cover_ear_pts = [
  [cover_x0 - cover_wall - cover_ear_off, cover_y0 - cover_wall - cover_ear_off],
  [cover_x1 + cover_wall + cover_ear_off, cover_y0 - cover_wall - cover_ear_off],
  [cover_x0 - cover_wall - cover_ear_off, cover_y1 + cover_wall + cover_ear_off],
  [cover_x1 + cover_wall + cover_ear_off, cover_y1 + cover_wall + cover_ear_off],
];
plate_lug_d = 9;   // プレート側ラグの円径（スリーブ od 7.8 を内包）
assert(plate_lug_d > tray_sleeve_od, "ラグ径がスリーブ外径以下");
assert(max([for (p = cover_ear_pts) max(-p[0], -p[1])]) + plate_lug_d/2
       <= min(clear_left, clear_down), "固定ラグがドアクリアランスを超える");
```

- [ ] **Step 4: hardware.scad にカバー用ボスを足す**

`ped_mount_bosses()` の直後に追加する。

```openscad
// カバーをプレート天面から留めるための本体側ボス。cover_ear_pts の各点に床上面から立てる。
module cover_mount_bosses() {
  for (p = cover_ear_pts)
    translate([p[0], p[1], wall]) m2_boss();
}
```

- [ ] **Step 5: body.scad を更新する**

`plate_outline_2d()` を置き換える。呼び出し側が `translate([center_x, center_y])` の中なので、ワールド座標のラグは `center` ぶん戻して描く。

```openscad
// プレート外形 2D（プレート中心基準・中心合わせは呼び出し側の translate で行う）。
// 矩形本体＋四隅のカバー固定ラグを角R2 で融合する。
module plate_outline_2d() {
  offset(r = 2) offset(r = -2)
    union() {
      square([body_l, body_w], center = true);
      for (p = cover_ear_pts)
        translate([p[0] - center_x, p[1] - center_y]) circle(d = plate_lug_d);
    }
}
```

`plate_ribs()` の difference にラグの逃げを足す。外周リブがラグ上のボスと重なるのを避ける。

```openscad
        // 受けカーブ・スリーブ・中央開口まわりの逃げ
        circle(r = ped_curb_ro + 1);
        // カバー固定ボスまわりの逃げ（リブとボスの干渉を避ける）
        for (p = cover_ear_pts)
          translate([p[0], p[1]]) circle(d = tray_sleeve_od + 1);
```

`body()` の union にボスを足す。

```openscad
      tray_mount_bosses();
      ped_mount_bosses();
      cover_mount_bosses();
```

- [ ] **Step 6: テストが通ることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/body_test.scad
nix develop -c bun enclosure/scripts/render.ts enclosure/models/smartlock.scad
nix develop -c bun enclosure/scripts/clash.ts
```

期待: すべて成功、clash は `OK: no interference`。

- [ ] **Step 7: コミット**

```bash
git add enclosure/models/params.scad enclosure/models/hardware.scad \
        enclosure/models/body.scad enclosure/models/body_test.scad
git commit -m "feat(enclosure): プレートにカバー固定ラグと M2 ボス 4 点を追加

四隅の対角方向へ φ9 のラグを張り出し、外周リブはボスまわりを逃がす。
ラグ最外 38.0 はドアクリアランス（-X 50 / -Y 65）の内側。"
```

---

### Task 3: カバー本体

**Files:**
- Create: `enclosure/models/cover.scad`
- Create: `enclosure/models/cover_test.scad`
- Modify: `enclosure/models/params.scad`（天面高さ・勾配・開口）

**Interfaces:**
- Consumes: Task 1 の `cover_x0/x1/y0/y1` `cover_wall` `servo_top_z` `pcb_*`、Task 2 の `cover_ear_pts`
- Produces: モジュール `cover()`（ワールド座標＝組立位置。z = `wall` が裾の下端、`cover_top_z` が天面）

- [ ] **Step 1: 失敗するテストを書く**

`enclosure/models/cover_test.scad` を新規作成する。

```openscad
include <params.scad>
use <cover.scad>
// 屋根内面が中身の最高点を上回ること
assert(cover_inner_top >= servo_top_z + 1.5, "カバー天井がサーボに当たる");
assert(roof_in_z(pcb_off_y) >= pcb_top_z + pcb_stack_usb + 2, "屋根が Pico/USB に当たる");
assert(roof_in_z(pcb_off_y - pcb_w/2) >= pcb_top_z + pcb_stack_tall + 2, "屋根が最高部品に当たる");
assert(roof_in_z(pcb_off_y + pcb_w/2) >= pcb_top_z + 3, "屋根が基板 +Y 端に当たる");
assert(roof_in_z(tray_fix_y_hi) >= wall + tray_boss_h + tray_cap_t + 1,
       "屋根が +Y 固定スリーブに当たる");
// スイッチ（PS21B-1）が斜面に収まり本体が基板に当たらないこと
assert(cover_wall / cos(45) < sw_thread_l, "斜面の実効パネル厚がネジ部長さを超える");
assert(sw_panel_d > sw_thread_d, "取付穴がネジ部より小さい");
assert(sw_tip_z >= pcb_top_z + pcb_stack_low, "スイッチ本体の先端が基板の部品に当たる");
assert(sw_pt[1] - sw_seat_d/2 >= cover_slope_y0, "スイッチ座面が勾配の始点をはみ出す");
assert(sw_pt[1] + sw_seat_d/2 <= cover_y1, "スイッチ座面が +Y 壁をはみ出す");
// LED 窓が基板の上にあること
assert(cover_led_pt[0] >= pcb_off_x - pcb_l/2 && cover_led_pt[0] <= pcb_off_x + pcb_l/2,
       "LED 窓が基板の X 範囲外");
assert(cover_led_pt[1] >= pcb_off_y - pcb_w/2 && cover_led_pt[1] <= pcb_off_y + pcb_w/2,
       "LED 窓が基板の Y 範囲外");
cover();
echo("cover_test ok");
```

- [ ] **Step 2: テストが落ちることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/cover_test.scad
```

期待: `cover.scad` が存在せず失敗。

- [ ] **Step 3: params.scad にカバーの高さ・勾配・開口を足す**

Task 1 で足した「カバー内面」ブロックの末尾に追加する。

```openscad
// カバーの高さと勾配。天面をベッドに伏せて刷るので屋根に水平な段を作らない
// （段は第 1 層より下に宙で現れて垂れる）。+Y への単一勾配 45°。
cover_head_clear = 2.0;                                    // サーボ上端 ⇔ 内面天井
cover_inner_top  = servo_top_z + cover_head_clear;         // 72.9
// 斜面で壁厚 cover_wall を「垂直」に確保するには、天面との垂直差が √2 倍要る。
// 平天面の厚みは cover_wall*sqrt(2) = 2.83 になる（ベッド面なので厚い方が都合が良い）。
cover_top_z      = cover_inner_top + cover_wall*sqrt(2);   // 75.73
cover_slope_y0   = ped_curb_ro + cover_clear;              // 28.7（勾配開始 y）
// 屋根内面の高さ（y の関数）。干渉チェックの assert が参照する。
function roof_in_z(y) = cover_inner_top - max(0, y - cover_slope_y0);

// 開口: USB 切欠き（+X 壁）
cover_usb_y = pcb_off_y;                    // 53.5
cover_usb_z = pcb_top_z + pcb_stack_pico + (pcb_stack_usb - pcb_stack_pico)/2;  // 22.15
cover_usb_w = 14;    // Y 方向
cover_usb_h = 10;    // Z 方向

// 開口: LED 窓（屋根の斜面。素通し穴）
cover_led_pt = [pcb_off_x - 24, pcb_off_y + 21];   // (-15, 74.5)
cover_led_d  = 6;

// --- パネル取付スイッチ PS21B-1（秋月 P-04583, モーメンタリ OFF-(ON)） ---
sw_thread_d = 11.5;   // ネジ部外径（実測 2026-08-16）
sw_panel_d  = 12.0;   // 取付穴（すきま 0.5。印刷公差込み）
sw_flange_d = 18.7;   // フランジ外径
sw_seat_d   = 19.0;   // 座面として平面が要る径
sw_thread_l = 8.3;    // ネジ部長さ（挟めるパネル厚の上限）
sw_depth    = 26;     // パネル面より内側の奥行き（端子先端まで）
sw_cap_d    = 14;     // キャップ外径
sw_cap_h    = 7.6;    // パネル面より外への突出
sw_pt       = [-1, 60];   // 屋根斜面上の取付中心（xy）
// 取付点の屋根外面 z と、法線方向へ sw_depth 伸ばした本体先端の z
sw_face_z = cover_top_z - (sw_pt[1] - cover_slope_y0);
sw_tip_z  = sw_face_z - sw_depth*cos(45);
```

- [ ] **Step 4: cover.scad を作る**

```openscad
include <params.scad>
use <hardware.scad>

// 一体カバー（ワールド座標＝組立位置で構築。z = wall が裾の下端）。
// サーボ側が背高で、+Y へ 45° の単一勾配で降りる殻。印刷は天面をベッドに伏せる向きで、
// smartlock.scad の part="cover" がひっくり返す。屋根に水平な段を作らないのは、段が
// 第 1 層より下に宙で現れて垂れるため。
module cover() {
  difference() {
    union() {
      cover_shell();
      // 固定耳（裾の外へ張り出す。プレートのラグ上のボスに被さる）
      for (p = cover_ear_pts)
        translate([p[0], p[1], wall]) m2_sleeve_solid();
    }
    for (p = cover_ear_pts)
      translate([p[0], p[1], wall]) m2_sleeve_cuts();
    cover_usb_cut();
    roof_normal_hole(cover_led_pt, cover_led_d);
    roof_normal_hole(sw_pt, sw_panel_d);
  }
}

// 殻（外形 − 内腔）
module cover_shell() {
  difference() {
    cover_body(0,          cover_top_z,   wall);
    cover_body(cover_wall, cover_inner_top, wall - 1);
  }
}

// カバーのソリッド。inset だけ内側へ絞り、top_z の天面を 45° で切り落とす。
module cover_body(inset, top_z, z0) {
  difference() {
    translate([0, 0, z0])
      linear_extrude(height = top_z - z0)
        cover_outline_2d(inset);
    cover_roof_cut(top_z);
  }
}

// 裾の外形 2D（inset で内腔用に絞る）
module cover_outline_2d(inset) {
  x0 = cover_x0 - cover_wall + inset;
  x1 = cover_x1 + cover_wall - inset;
  y0 = cover_y0 - cover_wall + inset;
  y1 = cover_y1 + cover_wall - inset;
  offset(r = 2) offset(r = -2)
    translate([(x0 + x1)/2, (y0 + y1)/2])
      square([x1 - x0, y1 - y0], center = true);
}

// y + z >= cover_slope_y0 + top_z の半空間。45° の屋根勾配を作る。
// z >= 0 の厚いスラブを -45° 回して法線を (0,1,1)/√2 に向け、勾配の始点へ寄せる。
module cover_roof_cut(top_z) {
  translate([0, cover_slope_y0, top_z])
    rotate([-45, 0, 0])
      translate([-400, -400, 0]) cube([800, 800, 400]);
}

// 屋根の斜面に法線方向の素通し穴をあける。pt = [x, y]（ワールド）。
// rotate([-45,0,0]) はシリンダ軸 (0,0,1) を斜面の外向き法線 (0,√2/2,√2/2) に一致させる。
module roof_normal_hole(pt, d) {
  z = cover_top_z - (pt[1] - cover_slope_y0);
  translate([pt[0], pt[1], z])
    rotate([-45, 0, 0])
      translate([0, 0, -20])
        cylinder(d = d, h = 40, $fn = 48);
}

// USB 切欠き（+X 壁を厚み方向に貫く角穴）
module cover_usb_cut() {
  translate([cover_x1 + cover_wall/2, cover_usb_y, cover_usb_z])
    cube([cover_wall*3, cover_usb_w, cover_usb_h], center = true);
}

// standalone render target (ignored by `use <cover.scad>`)
cover();
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/cover_test.scad
```

期待: WARNING / ERROR なしで終了し `ECHO: "cover_test ok"`。

- [ ] **Step 6: 目視で形を確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/cover.scad /tmp/cover.png
```

確認すること: 屋根が -Y 側で水平、+Y へ 45° で降りている。裾が開いている（下面が塞がっていない）。四隅に耳が 4 つ出ている。斜面に穴が 2 つ、+X 壁に角穴が 1 つ。

- [ ] **Step 7: コミット**

```bash
git add enclosure/models/params.scad enclosure/models/cover.scad \
        enclosure/models/cover_test.scad
git commit -m "feat(enclosure): 一体スロープ型カバーを新設

+Y へ 45° の単一勾配で降りる殻。天面をベッドに伏せて刷るのでサポート不要。
LED 窓・PS21B-1 の取付穴・USB 切欠きを開ける。"
```

---

### Task 4: パート登録・ビルド・干渉チェックへの組み込み

**Files:**
- Modify: `enclosure/models/smartlock.scad`
- Modify: `enclosure/models/clash_check.scad`
- Modify: `enclosure/scripts/build.ts`

**Interfaces:**
- Consumes: Task 3 の `cover()`
- Produces: `part="cover"`（印刷向き）、`part="asm_cover"`（組立向き）、`enclosure/build/cover.stl`

- [ ] **Step 1: smartlock.scad にパートを足す**

冒頭の `use` に追加する。

```openscad
use <cover.scad>
```

`part == "tray"` の分岐の直後に追加する。印刷は天面をベッドに伏せるので、天面 z が 0 に来るよう反転する。

```openscad
// カバーは天面をベッドに伏せて印刷する。組立向きから 180° 反転して天面を z=0 へ。
else if (part == "cover")
  translate([0, 0, cover_top_z]) rotate([180, 0, 0]) cover();
```

`part == "asm_tray"` の分岐の直後に追加する。

```openscad
else if (part == "asm_cover")
  color("LightSteelBlue") translate([0, 0, exp * 30]) cover();
```

最後の full assembly の末尾（`tray()` の後）に追加する。

```openscad
  color("LightSteelBlue")
    translate([0, 0, exp * 30]) cover();
```

- [ ] **Step 2: clash_check.scad にカバーのペアを足す**

冒頭の `use` に `use <cover.scad>` を追加し、末尾に追加する。カバーは組立位置で構築済みなので、意図的な面接触（耳の下面 ⇔ プレート上面、ボス上面 ⇔ ファンネル始端、裾 ⇔ リブ）の偽陽性を避けるため `clash_eps` だけ浮かせる。

```openscad
// cover × body（カバーを浮かせる）
intersection() {
  body();
  translate([0, 0, clash_eps]) cover();
}

// cover × tray（どちらも組立位置。トレイは z=wall へ）
intersection() {
  translate([0, 0, wall]) tray();
  translate([0, 0, clash_eps]) cover();
}

// cover × pedestal
intersection() {
  translate([0, 0, wall]) pedestal();
  translate([0, 0, clash_eps]) cover();
}
```

- [ ] **Step 3: build.ts に cover を足す**

```typescript
const parts = [
  "body", "pedestal", "socket", "tray", "cover",
  "asm_body", "asm_pedestal", "asm_socket", "asm_tray", "asm_cover",
];
```

- [ ] **Step 4: 全部通ることを確認する**

```bash
nix develop -c bun enclosure/scripts/render.ts enclosure/models/smartlock.scad
nix develop -c bun enclosure/scripts/clash.ts
nix develop -c bun enclosure/scripts/build.ts
```

期待: レンダリング成功、`OK: no interference (empty intersection)`、`All parts built to enclosure/build/`。

干渉が出た場合の切り分け: `clash_check.scad` のペアを 1 組ずつコメントアウトして、どのペアが原因か特定する。カバー × プレートで出るなら外周リブとカバー裾の嵌合すきま（`cover_lip_fit`）か、ラグまわりのリブ逃げを疑う。

- [ ] **Step 5: 印刷向きの STL を目視確認する**

`render.ts` は 3 番目以降の引数を openscad へそのまま渡すので、`-D` で part を指定する。

```bash
nix develop -c bun enclosure/scripts/render.ts \
  enclosure/models/smartlock.scad /tmp/cover_print.png -D 'part="cover"'
```

確認すること: 反転後の天面（元の屋根）が z=0 のベッド面に来ており、そこから壁が立ち上がっている。

- [ ] **Step 6: コミット**

```bash
git add enclosure/models/smartlock.scad enclosure/models/clash_check.scad \
        enclosure/scripts/build.ts
git commit -m "feat(enclosure): cover をパート・ビルド・干渉チェックへ登録

印刷向き（天面をベッドへ反転）の part=cover と組立向きの asm_cover を追加。"
```

---

### Task 5: 不要になったブレッドボード／Pico 実装系の削除

Task 1 で参照が切れたまま残しておいたものを消す。ここまで各タスクが緑を保てるように後回しにしていた掃除。

**Files:**
- Modify: `enclosure/models/params.scad`
- Modify: `enclosure/models/hardware.scad`
- Modify: `enclosure/models/hardware_test.scad`
- Modify: `enclosure/models/smartlock.scad`

- [ ] **Step 1: 参照が本当に無いことを確認する**

```bash
grep -rn "pico_w_mounts\|pico_hole_d\|pico_pin_drop\|pico_boss\|pico_screw\|tray_coupon\|bb_\|pocket_" enclosure/ circuit/ scripts/
```

期待: `hardware.scad` の `pico_w_mounts()` 定義、`hardware_test.scad` の呼び出し、`smartlock.scad` の `tray_coupon` 分岐、`params.scad` の定義だけがヒットする。他所から参照されていたら消さずに残す。

- [ ] **Step 2: hardware.scad から `pico_w_mounts()` を削除する**

モジュール定義とその上のコメントブロックを丸ごと消す。

- [ ] **Step 3: hardware_test.scad を更新する**

```openscad
include <params.scad>
use <hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
}
pcb_standoff();
tray_mount_bosses();
ped_mount_bosses();
cover_mount_bosses();
echo("hardware_test ok");
```

- [ ] **Step 4: params.scad から Pico 実装系を削除する**

`pico_hole_d` / `pico_hole_dx` / `pico_hole_dy` / `pico_pin_drop` / `pico_boss_d` / `pico_boss_h` / `pico_screw_pilot` / `pico_screw_grip` と、その上の「GPIO ヘッダは両長辺…」のコメントブロックを消す。`pico_l` / `pico_w` / `pico_h` は基板上の配置検証に使うので残し、コメントを「基板上にメスソケットで載せる Pico の外形」へ書き換える。

- [ ] **Step 5: smartlock.scad から `tray_coupon` を削除する**

`else if (part == "tray_coupon") ...` の分岐を丸ごと消す（BB ポケット角の切り出しクーポンなので用途が消滅した）。

- [ ] **Step 6: 全部通ることを確認する**

```bash
for f in enclosure/models/smartlock.scad enclosure/models/smoke.scad enclosure/models/*_test.scad; do
  echo "== $f"; nix develop -c bun enclosure/scripts/render.ts "$f" || break
done
nix develop -c bun enclosure/scripts/clash.ts
nix develop -c bun test enclosure/scripts/
```

期待: すべて成功。

- [ ] **Step 7: コミット**

```bash
git add enclosure/models/
git commit -m "chore(enclosure): ブレッドボード／Pico 実装系の残骸を削除

pico_w_mounts と Pico マウント用 params、tray_coupon パートを削除。"
```

---

### Task 6: 回路とパーツ表をパネル取付スイッチへ差し替え

**Files:**
- Modify: `circuit/parts.ts`
- Modify: `circuit/schematic-layout.ts`（フットプリント指定がある場合）
- Modify: `docs/parts-selection.md`

**Interfaces:**
- ネットリスト（`NETS`）は変更しない。SW1 の 2 端子が GND と BTN に繋がる関係はそのまま。

- [ ] **Step 1: 現状の SW1 の扱いを確認する**

```bash
grep -n "SW1" circuit/*.ts circuit/*.tsx circuit/breadboard/*
```

`schematic-layout.ts` の `SW1` エントリのフットプリント名を確認する。

- [ ] **Step 2: ERC が通ることを先に確認する（変更前のベースライン）**

```bash
cd circuit && nix develop -c bun install --frozen-lockfile && nix develop -c bun test
```

期待: 全テスト PASS。ここで落ちるなら先に別途原因を潰す。

- [ ] **Step 3: parts.ts のコメントを更新する**

`{ ref: "SW1", kind: "pushbutton" }` の行に、基板外の部品であることを明記する。

```typescript
  // SW1 はカバーにパネル取付する PS21B-1（秋月 P-04583）。基板上には 2pin コネクタだけが載り、
  // ここから 2 本の線でスイッチへ繋ぐ。ネットとしては従来のタクトスイッチと等価。
  { ref: "SW1", kind: "pushbutton" },
```

- [ ] **Step 4: ERC が通ることを確認する**

```bash
cd circuit && nix develop -c bun test
```

期待: 変更前と同じく全テスト PASS（ネットリストを変えていないので結果は不変）。

- [ ] **Step 5: docs/parts-selection.md を更新する**

メイン表の SW1 行を差し替える。

```markdown
| SW1 押しボタン | パネル用押しボタンスイッチ モーメンタリー 丸型 白 PS21B-1 | 秋月 | [P-04583](https://akizukidenshi.com/catalog/g/g104583/) | ¥160 | 1 | 1 | ¥160 |
```

「購入先まとめ」の対応表の該当行も同じ商品名・通販コードへ差し替える。「概算サマリ」の①②を再計算する（SW1 が ¥15 → ¥160 なので ① ¥3,454 → ¥3,599、② ¥4,605 → ¥4,750）。

備考に追記する。

```markdown
- SW1 は基板実装のタクトスイッチ（P-03647）からパネル取付の PS21B-1 へ変更した（2026-08-16）。カバー越しに押せるようにするため。実測値: ネジ部外径 φ11.5、フランジ φ18.7、パネル面より内側の奥行き 26mm。取付穴は φ12.0 で設計している。
```

`- ユニバーサル基板（P-03229）の既製の四隅マウント穴は φ3.2、中心間ピッチ 長辺66mm×短辺41mm。現行トレイはブレッドボード搭載で、この四隅穴は使っていない。` の後半を「トレイはこの四隅穴に合わせた支柱 4 本で基板を受ける（M2 セルフタップ。φ3.2 に対しネジ山は効かず頭で押さえる）。」へ書き換える。

- [ ] **Step 6: コミット**

```bash
git add circuit/parts.ts docs/parts-selection.md
git commit -m "feat(circuit): SW1 をパネル取付の PS21B-1 へ差し替え

ネットリストは不変。基板上には 2pin コネクタだけが載り、スイッチ本体はカバー側。
BOM を P-03647 から P-04583 へ差し替えて概算を再計算。"
```

---

### Task 7: ドキュメントとバックログの更新

**Files:**
- Modify: `README.md`
- Modify: `backlog/tasks/task-4 - rebuild-circuit-on-universal-board.md`

- [ ] **Step 1: README を更新する**

README にはパート一覧の表は無く、サブシステム表と本文に説明がある。3 箇所を直す。

サブシステム表の「筐体」行（`| 筐体 | \`enclosure/\` | ... |`）の役割欄を書き換える。

```markdown
| 筐体 | `enclosure/` | ドアに貼るベースプレートと、ボルトオンのサーボ台座、電子部品トレイ、サムターン受け、全体を覆うカバー |
```

システム全体像の本文「室内側のタクトスイッチでも手動でトグルでき、」を書き換える。

```markdown
室内側の押しボタン（カバーにパネル取付）でも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。
```

「回路はブレッドボード実機で、サーボと LED とスイッチを全部載せた同時動作まで検証済み。」の後ろに追記する。

```markdown
回路はブレッドボード実機で、サーボと LED とスイッチを全部載せた同時動作まで検証済み。筐体側はユニバーサル基板 P-03229 マウントへ移行済みで、はんだ実装は TASK-4 で行う。
```

- [ ] **Step 2: TASK-4 の作業項目を更新する**

`## 作業項目` の scad の行を、この改修で消化済みであることが分かる形に書き換える。

```markdown
- 基板レイアウトを決めてはんだ実装（部品は docs/parts-selection.md の BOM どおり。基板上の配置は docs/superpowers/specs/2026-08-16-universal-pcb-cover-design.md で確定済み）。
- ~~scad: トレイを P-03229 マウントに作り替え~~ → 2026-08-16 の筐体改修で完了（トレイ・プレート・カバーを一括で作り替え）。
- 実装後にブレッドボードと同条件の実機確認（TCP 経由の施錠/解錠、LED、スイッチ）。
```

`## 決定済みの前提` に追記する。

```markdown
- SW1 は基板実装のタクトスイッチではなく、カバーにパネル取付する PS21B-1（秋月 P-04583）。基板上には 2pin コネクタだけを置き、2 本の線でスイッチへ繋ぐ。
```

- [ ] **Step 3: 最終確認**

```bash
for f in enclosure/models/smartlock.scad enclosure/models/smoke.scad enclosure/models/*_test.scad; do
  echo "== $f"; nix develop -c bun enclosure/scripts/render.ts "$f" || break
done
nix develop -c bun enclosure/scripts/clash.ts
nix develop -c bun test enclosure/scripts/
nix develop -c bun enclosure/scripts/build.ts
cd circuit && nix develop -c bun test
```

期待: すべて成功。`git status` に `enclosure/build/` の中身が現れないこと（.gitignore 済み）。

- [ ] **Step 4: コミット**

```bash
git add README.md "backlog/tasks/task-4 - rebuild-circuit-on-universal-board.md"
git commit -m "docs: 筐体改修に合わせて README のパート表と TASK-4 を更新"
```

---

## 実機に持ち越すこと（この計画の範囲外）

- 基板へのはんだ実装と、ブレッドボード同条件での通し確認（TASK-4 の受け入れ条件 #1 と #3）。
- カバーの試し刷りと、外周リブ ⇔ 裾の嵌合すきま `cover_lip_fit = 0.3` の実測確定。ペデスタルの `pedestal_fit` やトレイの `boss_fit` と同じく、クーポンではなく本番の試し刷りで見る。
- 面ファスナーの配置見直し（TASK-6）。プレートが縮んで接着面積も減るため、カバー約 70g の追加と合わせて実機で挙動を見る。この改修では解決しない。
